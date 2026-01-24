"""
Supabase Storage Backend

This module provides a Supabase-backed storage implementation using asyncpg.
It mirrors the interface of the SQLite storage but uses Supabase's PostgreSQL database.
"""

import logging
from uuid import UUID

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


class SupabaseStorage:
    """Supabase/PostgreSQL storage for councils and debates.

    This class provides the same interface as the SQLite Storage class
    but uses Supabase's PostgreSQL database via asyncpg.
    """

    _pool = None
    _initialized: bool = False

    @classmethod
    async def configure(cls, database_url: str) -> None:
        """Configure the Supabase connection.

        Args:
            database_url: PostgreSQL connection URL from Supabase
        """
        # Import asyncpg only when needed
        try:
            import asyncpg
        except ImportError:
            raise ImportError(
                "asyncpg is required for Supabase storage. Install it with: pip install asyncpg"
            )

        cls._pool = await asyncpg.create_pool(database_url)
        cls._initialized = False

    @classmethod
    async def initialize(cls) -> None:
        """Initialize database schema if needed."""
        if cls._pool is None:
            raise RuntimeError("SupabaseStorage not configured. Call configure() first.")

        if cls._initialized:
            return

        # Schema should be managed via Supabase migrations
        # This is a no-op since we expect tables to exist
        cls._initialized = True

    @classmethod
    async def _ensure_initialized(cls) -> None:
        """Ensure the storage is initialized."""
        if not cls._initialized:
            await cls.initialize()

    @classmethod
    async def save_council(
        cls,
        council: CouncilConfig,
        owner_id: str | None = None,
        guest_id: str | None = None,
    ) -> CouncilConfig:
        """Save a council to the database."""
        await cls._ensure_initialized()

        async with cls._pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO councils (id, name, max_rounds, consensus_threshold, created_at, owner_id, guest_id)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                ON CONFLICT(id) DO UPDATE SET
                    name = EXCLUDED.name,
                    max_rounds = EXCLUDED.max_rounds,
                    consensus_threshold = EXCLUDED.consensus_threshold,
                    created_at = EXCLUDED.created_at,
                    owner_id = EXCLUDED.owner_id,
                    guest_id = EXCLUDED.guest_id
                """,
                str(council.id),
                council.name,
                council.max_rounds,
                council.consensus_threshold,
                council.created_at.isoformat(),
                owner_id,
                guest_id,
            )

            await conn.execute(
                "DELETE FROM council_agents WHERE council_id = $1",
                str(council.id),
            )

            for index, agent in enumerate(council.agents):
                await conn.execute(
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
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                    """,
                    str(agent.id),
                    str(council.id),
                    agent.name,
                    agent.provider.value,
                    agent.role.value,
                    agent.custom_prompt,
                    agent.model,
                    index,
                )

        return council

    @classmethod
    async def get_council(cls, council_id: UUID) -> CouncilConfig | None:
        """Get a council by ID."""
        await cls._ensure_initialized()

        async with cls._pool.acquire() as conn:
            council_row = await conn.fetchrow(
                "SELECT * FROM councils WHERE id = $1",
                str(council_id),
            )
            if council_row is None:
                return None

            agent_rows = await conn.fetch(
                """
                SELECT * FROM council_agents
                WHERE council_id = $1
                ORDER BY sort_order ASC
                """,
                str(council_id),
            )
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

            return CouncilConfig(
                id=council_row["id"],
                name=council_row["name"],
                agents=agents,
                max_rounds=council_row["max_rounds"],
                consensus_threshold=council_row["consensus_threshold"],
                created_at=council_row["created_at"],
            )

    @classmethod
    async def list_councils(
        cls,
        owner_id: str | None = None,
        guest_id: str | None = None,
    ) -> list[CouncilConfig]:
        """List councils with optional owner/guest filtering."""
        await cls._ensure_initialized()

        async with cls._pool.acquire() as conn:
            if owner_id is not None:
                council_rows = await conn.fetch(
                    "SELECT * FROM councils WHERE owner_id = $1 ORDER BY created_at ASC",
                    owner_id,
                )
            elif guest_id is not None:
                council_rows = await conn.fetch(
                    "SELECT * FROM councils WHERE guest_id = $1 ORDER BY created_at ASC",
                    guest_id,
                )
            else:
                council_rows = await conn.fetch("SELECT * FROM councils ORDER BY created_at ASC")

            councils: list[CouncilConfig] = []
            for council_row in council_rows:
                agent_rows = await conn.fetch(
                    """
                    SELECT * FROM council_agents
                    WHERE council_id = $1
                    ORDER BY sort_order ASC
                    """,
                    council_row["id"],
                )
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
        """Delete a council by ID."""
        await cls._ensure_initialized()

        async with cls._pool.acquire() as conn:
            result = await conn.execute(
                "DELETE FROM councils WHERE id = $1",
                str(council_id),
            )
            return result != "DELETE 0"

    @classmethod
    async def save_debate(
        cls,
        debate: Debate,
        owner_id: str | None = None,
        guest_id: str | None = None,
    ) -> Debate:
        """Save a debate to the database."""
        await cls._ensure_initialized()

        async with cls._pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO debates (
                    id, council_id, topic, status, current_round, summary,
                    error_message, created_at, completed_at, owner_id, guest_id
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                ON CONFLICT(id) DO UPDATE SET
                    council_id = EXCLUDED.council_id,
                    topic = EXCLUDED.topic,
                    status = EXCLUDED.status,
                    current_round = EXCLUDED.current_round,
                    summary = EXCLUDED.summary,
                    error_message = EXCLUDED.error_message,
                    created_at = EXCLUDED.created_at,
                    completed_at = EXCLUDED.completed_at,
                    owner_id = EXCLUDED.owner_id,
                    guest_id = EXCLUDED.guest_id
                """,
                str(debate.id),
                str(debate.council_id),
                debate.topic,
                debate.status.value,
                debate.current_round,
                debate.summary,
                debate.error_message,
                debate.created_at.isoformat(),
                debate.completed_at.isoformat() if debate.completed_at else None,
                owner_id,
                guest_id,
            )

            # Delete existing related data
            await conn.execute(
                "DELETE FROM debate_rounds WHERE debate_id = $1",
                str(debate.id),
            )
            await conn.execute(
                "DELETE FROM debate_responses WHERE debate_id = $1",
                str(debate.id),
            )
            await conn.execute(
                "DELETE FROM debate_votes WHERE debate_id = $1",
                str(debate.id),
            )
            await conn.execute(
                "DELETE FROM debate_points WHERE debate_id = $1",
                str(debate.id),
            )

            # Insert rounds, responses, votes, and points
            for round_item in debate.rounds:
                vote_summary = round_item.vote_summary or {}
                await conn.execute(
                    """
                    INSERT INTO debate_rounds (
                        debate_id, round_number, consensus_reached,
                        vote_summary_agree, vote_summary_disagree, vote_summary_abstain, timestamp
                    )
                    VALUES ($1, $2, $3, $4, $5, $6, $7)
                    """,
                    str(debate.id),
                    round_item.round_number,
                    round_item.consensus_reached,
                    vote_summary.get(VoteType.AGREE.value),
                    vote_summary.get(VoteType.DISAGREE.value),
                    vote_summary.get(VoteType.ABSTAIN.value),
                    round_item.timestamp.isoformat(),
                )

                for response in round_item.responses:
                    await conn.execute(
                        """
                        INSERT INTO debate_responses (
                            debate_id, round_number, agent_id, agent_name,
                            role, provider, content, vote, reasoning, timestamp
                        )
                        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                        """,
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
                    )

                for agent_id, vote in round_item.votes.items():
                    await conn.execute(
                        """
                        INSERT INTO debate_votes (debate_id, round_number, agent_id, vote)
                        VALUES ($1, $2, $3, $4)
                        """,
                        str(debate.id),
                        round_item.round_number,
                        str(agent_id),
                        vote.value if isinstance(vote, VoteType) else str(vote),
                    )

            for index, point in enumerate(debate.pro_points):
                await conn.execute(
                    """
                    INSERT INTO debate_points (debate_id, point_type, point, sort_order)
                    VALUES ($1, $2, $3, $4)
                    """,
                    str(debate.id),
                    "pro",
                    point,
                    index,
                )

            for index, point in enumerate(debate.against_points):
                await conn.execute(
                    """
                    INSERT INTO debate_points (debate_id, point_type, point, sort_order)
                    VALUES ($1, $2, $3, $4)
                    """,
                    str(debate.id),
                    "against",
                    point,
                    index,
                )

        return debate

    @classmethod
    async def get_debate(cls, debate_id: UUID) -> Debate | None:
        """Get a debate by ID."""
        await cls._ensure_initialized()

        async with cls._pool.acquire() as conn:
            debate_row = await conn.fetchrow(
                "SELECT * FROM debates WHERE id = $1",
                str(debate_id),
            )
            if debate_row is None:
                return None

            round_rows = await conn.fetch(
                """
                SELECT * FROM debate_rounds
                WHERE debate_id = $1
                ORDER BY round_number ASC
                """,
                str(debate_id),
            )

            rounds: list[DebateRound] = []
            for round_row in round_rows:
                response_rows = await conn.fetch(
                    """
                    SELECT * FROM debate_responses
                    WHERE debate_id = $1 AND round_number = $2
                    ORDER BY id ASC
                    """,
                    str(debate_id),
                    round_row["round_number"],
                )
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

                vote_rows = await conn.fetch(
                    """
                    SELECT * FROM debate_votes
                    WHERE debate_id = $1 AND round_number = $2
                    ORDER BY id ASC
                    """,
                    str(debate_id),
                    round_row["round_number"],
                )
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

            point_rows = await conn.fetch(
                """
                SELECT * FROM debate_points
                WHERE debate_id = $1
                ORDER BY sort_order ASC
                """,
                str(debate_id),
            )
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
        """Delete a debate by ID."""
        await cls._ensure_initialized()

        async with cls._pool.acquire() as conn:
            result = await conn.execute(
                "DELETE FROM debates WHERE id = $1",
                str(debate_id),
            )
            return result != "DELETE 0"

    @classmethod
    async def list_debates(
        cls,
        council_id: UUID | None = None,
        owner_id: str | None = None,
        guest_id: str | None = None,
    ) -> list[Debate]:
        """List debates with optional filtering."""
        await cls._ensure_initialized()

        async with cls._pool.acquire() as conn:
            conditions = []
            params: list = []
            param_idx = 1

            if council_id:
                conditions.append(f"council_id = ${param_idx}")
                params.append(str(council_id))
                param_idx += 1

            if owner_id is not None:
                conditions.append(f"owner_id = ${param_idx}")
                params.append(owner_id)
                param_idx += 1
            elif guest_id is not None:
                conditions.append(f"guest_id = ${param_idx}")
                params.append(guest_id)
                param_idx += 1

            if conditions:
                query = f"SELECT * FROM debates WHERE {' AND '.join(conditions)} ORDER BY created_at ASC"
                debate_rows = await conn.fetch(query, *params)
            else:
                debate_rows = await conn.fetch("SELECT * FROM debates ORDER BY created_at ASC")

            debates: list[Debate] = []
            for debate_row in debate_rows:
                debate = await cls.get_debate(UUID(debate_row["id"]))
                if debate:
                    debates.append(debate)
            return debates

    @classmethod
    async def clear(cls) -> None:
        """Clear all data from the database."""
        await cls._ensure_initialized()

        async with cls._pool.acquire() as conn:
            await conn.execute("DELETE FROM debate_points")
            await conn.execute("DELETE FROM debate_votes")
            await conn.execute("DELETE FROM debate_responses")
            await conn.execute("DELETE FROM debate_rounds")
            await conn.execute("DELETE FROM debates")
            await conn.execute("DELETE FROM council_agents")
            await conn.execute("DELETE FROM councils")

    @classmethod
    async def close(cls) -> None:
        """Close the connection pool."""
        if cls._pool:
            await cls._pool.close()
            cls._pool = None
            cls._initialized = False
