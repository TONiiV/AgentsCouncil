from __future__ import annotations

from pathlib import Path

import aiosqlite

SCHEMA = [
    """
    CREATE TABLE IF NOT EXISTS councils (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        max_rounds INTEGER NOT NULL,
        consensus_threshold REAL NOT NULL,
        created_at TEXT NOT NULL,
        owner_id TEXT,
        guest_id TEXT
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS council_agents (
        id TEXT PRIMARY KEY,
        council_id TEXT NOT NULL,
        name TEXT NOT NULL,
        provider TEXT NOT NULL,
        role TEXT NOT NULL,
        custom_prompt TEXT,
        model TEXT,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (council_id) REFERENCES councils(id) ON DELETE CASCADE
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS debates (
        id TEXT PRIMARY KEY,
        council_id TEXT NOT NULL,
        topic TEXT NOT NULL,
        status TEXT NOT NULL,
        current_round INTEGER NOT NULL,
        summary TEXT,
        error_message TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        owner_id TEXT,
        guest_id TEXT,
        FOREIGN KEY (council_id) REFERENCES councils(id) ON DELETE CASCADE
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS debate_rounds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debate_id TEXT NOT NULL,
        round_number INTEGER NOT NULL,
        consensus_reached INTEGER NOT NULL,
        vote_summary_agree INTEGER,
        vote_summary_disagree INTEGER,
        vote_summary_abstain INTEGER,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (debate_id) REFERENCES debates(id) ON DELETE CASCADE
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS debate_responses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debate_id TEXT NOT NULL,
        round_number INTEGER NOT NULL,
        agent_id TEXT NOT NULL,
        agent_name TEXT NOT NULL,
        role TEXT NOT NULL,
        provider TEXT NOT NULL,
        content TEXT NOT NULL,
        vote TEXT,
        reasoning TEXT,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (debate_id) REFERENCES debates(id) ON DELETE CASCADE
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS debate_votes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debate_id TEXT NOT NULL,
        round_number INTEGER NOT NULL,
        agent_id TEXT NOT NULL,
        vote TEXT NOT NULL,
        FOREIGN KEY (debate_id) REFERENCES debates(id) ON DELETE CASCADE
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS debate_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debate_id TEXT NOT NULL,
        point_type TEXT NOT NULL,
        point TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (debate_id) REFERENCES debates(id) ON DELETE CASCADE
    );
    """,
]


async def init_db(db_path: Path) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    async with aiosqlite.connect(db_path) as connection:
        await connection.execute("PRAGMA journal_mode=WAL;")
        await connection.execute("PRAGMA foreign_keys=ON;")
        for statement in SCHEMA:
            await connection.execute(statement)
        await connection.commit()
