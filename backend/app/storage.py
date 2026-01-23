import logging
from pathlib import Path
from uuid import UUID

import aiosqlite

from app import db
from app.models import (
    AgentConfig,
    AgentResponse,
    CouncilConfig,
    Debate,
    DebateRound,
    DebateStatus,
    VoteType,
)

logger = logging.getLogger(__name__)

DATA_DIR = Path(__file__).parent.parent / "data"
DEFAULT_DB_PATH = DATA_DIR / "agentscouncil.db"


class Storage:
    """SQLite storage for councils and debates."""

    _db_path: Path | None = None
    _initialized: bool = False

    @classmethod
    def configure(cls, db_path: Path) -> None:
        cls._db_path = db_path
        cls._initialized = False

    @classmethod
    async def initialize(cls) -> None:
        await cls._ensure_initialized()
        await cls._mark_stuck_debates_error()

    @classmethod
    async def _ensure_initialized(cls) -> None:
        if cls._initialized:
            return
        if cls._db_path is None:
            cls._db_path = DEFAULT_DB_PATH
        await db.init_db(cls._db_path)
        cls._initialized = True

    @classmethod
    async def _mark_stuck_debates_error(cls) -> None:
        await cls._ensure_initialized()
        async with aiosqlite.connect(cls._db_path) as connection:
            await connection.execute(
                """
                UPDATE debates
                SET status = ?, error_message = ?
                WHERE status = ?
                """,
                (
                    DebateStatus.ERROR.value,
                    "Interrupted by server restart",
                    DebateStatus.IN_PROGRESS.value,
                ),
            )
            await connection.commit()

    @classmethod
    async def save_council(cls, council: CouncilConfig) -> CouncilConfig:
        await cls._ensure_initialized()
        async with aiosqlite.connect(cls._db_path) as connection:
            await connection.execute(
                """
                INSERT INTO councils (id, name, max_rounds, consensus_threshold, created_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    max_rounds = excluded.max_rounds,
                    consensus_threshold = excluded.consensus_threshold,
                    created_at = excluded.created_at
                """,
                (
                    str(council.id),
                    council.name,
                    council.max_rounds,
                    council.consensus_threshold,
                    council.created_at.isoformat(),
                ),
            )

            await connection.execute(
                "DELETE FROM council_agents WHERE council_id = ?",
                (str(council.id),),
            )

            for index, agent in enumerate(council.agents):
                await connection.execute(
                    """
                    INSERT INTO council_agents (
                        id,
                        council_id,
                        name,
                        provider,
                        role,
                        custom_prompt,
                        model,
                        sort_order
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        str(agent.id),
                        str(council.id),
                        agent.name,
                        agent.provider.value,
                        agent.role.value,
                        agent.custom_prompt,
                        agent.model,
                        index,
                    ),
                )

            await connection.commit()
        return council

    @classmethod
    async def get_council(cls, council_id: UUID) -> CouncilConfig | None:
        await cls._ensure_initialized()
        async with aiosqlite.connect(cls._db_path) as connection:
            connection.row_factory = aiosqlite.Row
            cursor = await connection.execute(
                "SELECT * FROM councils WHERE id = ?",
                (str(council_id),),
            )
            council_row = await cursor.fetchone()
            if council_row is None:
                return None

            agents_cursor = await connection.execute(
                """
                SELECT * FROM council_agents
                WHERE council_id = ?
                ORDER BY sort_order ASC
                """,
                (str(council_id),),
            )
            agents_rows = await agents_cursor.fetchall()
            agents = [
                AgentConfig(
                    id=row["id"],
                    name=row["name"],
                    provider=row["provider"],
                    role=row["role"],
                    custom_prompt=row["custom_prompt"],
                    model=row["model"],
                )
                for row in agents_rows
            ]

            return CouncilConfig(
                id=council_row["id"],
                name=council_row["name"],
                agents=agents,
                max_rounds=council_row["max_rounds"],
                consensus_threshold=council_row["consensus_threshold"],
                created_at=council_row["created_at"],
            )

    @classmethod
    async def list_councils(cls) -> list[CouncilConfig]:
        await cls._ensure_initialized()
        async with aiosqlite.connect(cls._db_path) as connection:
            connection.row_factory = aiosqlite.Row
            cursor = await connection.execute("SELECT * FROM councils ORDER BY created_at ASC")
            council_rows = await cursor.fetchall()

            councils: list[CouncilConfig] = []
            for council_row in council_rows:
                agents_cursor = await connection.execute(
                    """
                    SELECT * FROM council_agents
                    WHERE council_id = ?
                    ORDER BY sort_order ASC
                    """,
                    (council_row["id"],),
                )
                agent_rows = await agents_cursor.fetchall()
                agents = [
                    AgentConfig(
                        id=row["id"],
                        name=row["name"],
                        provider=row["provider"],
                        role=row["role"],
                        custom_prompt=row["custom_prompt"],
                        model=row["model"],
                    )
                    for row in agent_rows
                ]

                councils.append(
                    CouncilConfig(
                        id=council_row["id"],
                        name=council_row["name"],
                        agents=agents,
                        max_rounds=council_row["max_rounds"],
                        consensus_threshold=council_row["consensus_threshold"],
                        created_at=council_row["created_at"],
                    )
                )

            return councils

    @classmethod
    async def delete_council(cls, council_id: UUID) -> bool:
        await cls._ensure_initialized()
        async with aiosqlite.connect(cls._db_path) as connection:
            cursor = await connection.execute(
                "DELETE FROM councils WHERE id = ?",
                (str(council_id),),
            )
            await connection.commit()
            return cursor.rowcount > 0

    @classmethod
    async def save_debate(cls, debate: Debate) -> Debate:
        await cls._ensure_initialized()
        async with aiosqlite.connect(cls._db_path) as connection:
            await connection.execute(
                """
                INSERT INTO debates (
                    id,
                    council_id,
                    topic,
                    status,
                    current_round,
                    summary,
                    error_message,
                    created_at,
                    completed_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    council_id = excluded.council_id,
                    topic = excluded.topic,
                    status = excluded.status,
                    current_round = excluded.current_round,
                    summary = excluded.summary,
                    error_message = excluded.error_message,
                    created_at = excluded.created_at,
                    completed_at = excluded.completed_at
                """,
                (
                    str(debate.id),
                    str(debate.council_id),
                    debate.topic,
                    debate.status.value,
                    debate.current_round,
                    debate.summary,
                    debate.error_message,
                    debate.created_at.isoformat(),
                    debate.completed_at.isoformat() if debate.completed_at else None,
                ),
            )

            await connection.execute(
                "DELETE FROM debate_rounds WHERE debate_id = ?",
                (str(debate.id),),
            )
            await connection.execute(
                "DELETE FROM debate_responses WHERE debate_id = ?",
                (str(debate.id),),
            )
            await connection.execute(
                "DELETE FROM debate_votes WHERE debate_id = ?",
                (str(debate.id),),
            )
            await connection.execute(
                "DELETE FROM debate_points WHERE debate_id = ?",
                (str(debate.id),),
            )

            for round_item in debate.rounds:
                vote_summary = round_item.vote_summary or {}
                await connection.execute(
                    """
                    INSERT INTO debate_rounds (
                        debate_id,
                        round_number,
                        consensus_reached,
                        vote_summary_agree,
                        vote_summary_disagree,
                        vote_summary_abstain,
                        timestamp
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        str(debate.id),
                        round_item.round_number,
                        1 if round_item.consensus_reached else 0,
                        vote_summary.get(VoteType.AGREE.value),
                        vote_summary.get(VoteType.DISAGREE.value),
                        vote_summary.get(VoteType.ABSTAIN.value),
                        round_item.timestamp.isoformat(),
                    ),
                )

                for response in round_item.responses:
                    await connection.execute(
                        """
                        INSERT INTO debate_responses (
                            debate_id,
                            round_number,
                            agent_id,
                            agent_name,
                            role,
                            provider,
                            content,
                            vote,
                            reasoning,
                            timestamp
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            str(debate.id),
                            round_item.round_number,
                            str(response.agent_id),
                            response.agent_name,
                            response.role.value,
                            response.provider.value,
                            response.content,
                            response.vote.value if response.vote else None,
                            response.reasoning,
                            response.timestamp.isoformat(),
                        ),
                    )

                for agent_id, vote in round_item.votes.items():
                    await connection.execute(
                        """
                        INSERT INTO debate_votes (
                            debate_id,
                            round_number,
                            agent_id,
                            vote
                        )
                        VALUES (?, ?, ?, ?)
                        """,
                        (
                            str(debate.id),
                            round_item.round_number,
                            str(agent_id),
                            vote.value if isinstance(vote, VoteType) else str(vote),
                        ),
                    )

            for index, point in enumerate(debate.pro_points):
                await connection.execute(
                    """
                    INSERT INTO debate_points (debate_id, point_type, point, sort_order)
                    VALUES (?, ?, ?, ?)
                    """,
                    (str(debate.id), "pro", point, index),
                )

            for index, point in enumerate(debate.against_points):
                await connection.execute(
                    """
                    INSERT INTO debate_points (debate_id, point_type, point, sort_order)
                    VALUES (?, ?, ?, ?)
                    """,
                    (str(debate.id), "against", point, index),
                )

            await connection.commit()
        return debate

    @classmethod
    async def get_debate(cls, debate_id: UUID) -> Debate | None:
        await cls._ensure_initialized()
        async with aiosqlite.connect(cls._db_path) as connection:
            connection.row_factory = aiosqlite.Row
            cursor = await connection.execute(
                "SELECT * FROM debates WHERE id = ?",
                (str(debate_id),),
            )
            debate_row = await cursor.fetchone()
            if debate_row is None:
                return None

            rounds_cursor = await connection.execute(
                """
                SELECT * FROM debate_rounds
                WHERE debate_id = ?
                ORDER BY round_number ASC
                """,
                (str(debate_id),),
            )
            round_rows = await rounds_cursor.fetchall()

            rounds: list[DebateRound] = []
            for round_row in round_rows:
                responses_cursor = await connection.execute(
                    """
                    SELECT * FROM debate_responses
                    WHERE debate_id = ? AND round_number = ?
                    ORDER BY id ASC
                    """,
                    (str(debate_id), round_row["round_number"]),
                )
                response_rows = await responses_cursor.fetchall()
                responses = [
                    AgentResponse(
                        agent_id=row["agent_id"],
                        agent_name=row["agent_name"],
                        role=row["role"],
                        provider=row["provider"],
                        content=row["content"],
                        vote=row["vote"],
                        reasoning=row["reasoning"],
                        timestamp=row["timestamp"],
                    )
                    for row in response_rows
                ]

                votes_cursor = await connection.execute(
                    """
                    SELECT * FROM debate_votes
                    WHERE debate_id = ? AND round_number = ?
                    ORDER BY id ASC
                    """,
                    (str(debate_id), round_row["round_number"]),
                )
                vote_rows = await votes_cursor.fetchall()
                votes = {row["agent_id"]: row["vote"] for row in vote_rows}

                vote_summary = None
                if (
                    round_row["vote_summary_agree"] is not None
                    or round_row["vote_summary_disagree"] is not None
                    or round_row["vote_summary_abstain"] is not None
                ):
                    vote_summary = {
                        VoteType.AGREE.value: round_row["vote_summary_agree"] or 0,
                        VoteType.DISAGREE.value: round_row["vote_summary_disagree"] or 0,
                        VoteType.ABSTAIN.value: round_row["vote_summary_abstain"] or 0,
                    }

                rounds.append(
                    DebateRound(
                        round_number=round_row["round_number"],
                        responses=responses,
                        votes=votes,
                        vote_summary=vote_summary,
                        consensus_reached=bool(round_row["consensus_reached"]),
                        timestamp=round_row["timestamp"],
                    )
                )

            points_cursor = await connection.execute(
                """
                SELECT * FROM debate_points
                WHERE debate_id = ?
                ORDER BY sort_order ASC
                """,
                (str(debate_id),),
            )
            point_rows = await points_cursor.fetchall()
            pro_points: list[str] = []
            against_points: list[str] = []
            for row in point_rows:
                if row["point_type"] == "pro":
                    pro_points.append(row["point"])
                else:
                    against_points.append(row["point"])

            return Debate(
                id=debate_row["id"],
                council_id=debate_row["council_id"],
                topic=debate_row["topic"],
                status=debate_row["status"],
                rounds=rounds,
                current_round=debate_row["current_round"],
                summary=debate_row["summary"],
                pro_points=pro_points,
                against_points=against_points,
                error_message=debate_row["error_message"],
                created_at=debate_row["created_at"],
                completed_at=debate_row["completed_at"],
            )

    @classmethod
    async def delete_debate(cls, debate_id: UUID) -> bool:
        await cls._ensure_initialized()
        async with aiosqlite.connect(cls._db_path) as connection:
            cursor = await connection.execute(
                "DELETE FROM debates WHERE id = ?",
                (str(debate_id),),
            )
            await connection.commit()
            return cursor.rowcount > 0

    @classmethod
    async def list_debates(cls, council_id: UUID | None = None) -> list[Debate]:
        await cls._ensure_initialized()
        async with aiosqlite.connect(cls._db_path) as connection:
            connection.row_factory = aiosqlite.Row
            if council_id:
                cursor = await connection.execute(
                    "SELECT * FROM debates WHERE council_id = ? ORDER BY created_at ASC",
                    (str(council_id),),
                )
            else:
                cursor = await connection.execute("SELECT * FROM debates ORDER BY created_at ASC")
            debate_rows = await cursor.fetchall()

            debates: list[Debate] = []
            for debate_row in debate_rows:
                debate = await cls.get_debate(UUID(debate_row["id"]))
                if debate:
                    debates.append(debate)
            return debates

    @classmethod
    async def clear(cls) -> None:
        await cls._ensure_initialized()
        async with aiosqlite.connect(cls._db_path) as connection:
            await connection.execute("DELETE FROM debate_points")
            await connection.execute("DELETE FROM debate_votes")
            await connection.execute("DELETE FROM debate_responses")
            await connection.execute("DELETE FROM debate_rounds")
            await connection.execute("DELETE FROM debates")
            await connection.execute("DELETE FROM council_agents")
            await connection.execute("DELETE FROM councils")
            await connection.commit()
