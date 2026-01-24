"""
AgentsCouncil Backend - Data Models
"""

from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from uuid import UUID, uuid4

from pydantic import BaseModel, Field

# === Enums ===


class ProviderType(str, Enum):
    """Supported AI providers."""

    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    GEMINI = "gemini"
    GOOGLE_OAUTH = "google_oauth"
    OLLAMA = "ollama"


class RoleType(str, Enum):
    """Built-in agent roles/personas."""

    INVESTMENT_ADVISOR = "investment_advisor"
    PR_EXPERT = "pr_expert"
    POLITICS_EXPERT = "politics_expert"
    LEGAL_ADVISOR = "legal_advisor"
    TECH_STRATEGIST = "tech_strategist"
    DEVILS_ADVOCATE = "devils_advocate"
    CUSTOM = "custom"


class VoteType(str, Enum):
    """Vote options for each round."""

    AGREE = "agree"
    DISAGREE = "disagree"


class DebateStatus(str, Enum):
    """Debate lifecycle states."""

    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    CONSENSUS_REACHED = "consensus_reached"
    ROUND_LIMIT_REACHED = "round_limit_reached"
    CANCELLED = "cancelled"
    ERROR = "error"


# === Agent Models ===


class AgentConfig(BaseModel):
    """Configuration for a single AI agent in the council."""

    id: UUID = Field(default_factory=uuid4)
    name: str
    provider: ProviderType
    role: RoleType
    custom_prompt: str | None = None  # Used when role is CUSTOM
    model: str | None = None  # Provider-specific model override


class AgentResponse(BaseModel):
    """A single response from an agent during debate."""

    agent_id: UUID
    agent_name: str
    role: RoleType
    provider: ProviderType
    content: str
    vote: VoteType | None = None
    reasoning: str | None = None  # Why they voted this way
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


# === Council Models ===


class CouncilConfig(BaseModel):
    """Configuration for a debate council."""

    id: UUID = Field(default_factory=uuid4)
    name: str
    agents: list[AgentConfig]
    max_rounds: int = 5
    consensus_threshold: float = 0.8  # Percentage of agreement needed
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class CouncilCreate(BaseModel):
    """Request model for creating a council."""

    name: str
    agents: list[AgentConfig]
    max_rounds: int = 5
    consensus_threshold: float = 0.8


# === Debate Models =


class DebateRound(BaseModel):
    """A single round of debate."""

    round_number: int
    responses: list[AgentResponse] = []
    votes: dict[str, VoteType] = {}  # agent_id -> vote
    vote_summary: dict[str, int] | None = None  # {"agree": 2, "disagree": 1, ...}
    consensus_reached: bool = False
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class Debate(BaseModel):
    """A complete debate session."""

    id: UUID = Field(default_factory=uuid4)
    council_id: UUID
    topic: str
    status: DebateStatus = DebateStatus.PENDING
    rounds: list[DebateRound] = []
    current_round: int = 0
    summary: str | None = None  # Moderator's final summary (Markdown)
    pro_points: list[str] = []
    against_points: list[str] = []
    error_message: str | None = None  # Error details if debate failed
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    completed_at: datetime | None = None


class DebateCreate(BaseModel):
    """Request model for starting a debate."""

    council_id: UUID
    topic: str


class DebateUpdate(BaseModel):
    """WebSocket message for debate updates."""

    debate_id: UUID
    event_type: str  # "round_start", "agent_thinking", "agent_response", "agent_response_chunk", "tool_call", "vote", "consensus", "summary"
    data: dict


# === Role System Prompts ===

# Prompt loading utilities
_PROMPTS_DIR = Path(__file__).parent / "prompts"
_prompt_cache: dict[str, str] = {}


def _load_prompt(filename: str) -> str:
    """Load a prompt from a text file, with caching."""
    if filename not in _prompt_cache:
        prompt_path = _PROMPTS_DIR / filename
        try:
            _prompt_cache[filename] = prompt_path.read_text(encoding="utf-8").strip()
        except FileNotFoundError:
            raise FileNotFoundError(f"Prompt file not found: {prompt_path}")
    return _prompt_cache[filename]


# Load stance directive (common to all roles except CUSTOM)
STANCE_DIRECTIVE = "\n\n" + _load_prompt("stance_directive.txt")

# Role-specific prompts loaded from individual files
ROLE_PROMPTS: dict[RoleType, str] = {
    RoleType.INVESTMENT_ADVISOR: _load_prompt("investment_advisor.txt") + STANCE_DIRECTIVE,
    RoleType.PR_EXPERT: _load_prompt("pr_expert.txt") + STANCE_DIRECTIVE,
    RoleType.POLITICS_EXPERT: _load_prompt("politics_expert.txt") + STANCE_DIRECTIVE,
    RoleType.LEGAL_ADVISOR: _load_prompt("legal_advisor.txt") + STANCE_DIRECTIVE,
    RoleType.TECH_STRATEGIST: _load_prompt("tech_strategist.txt") + STANCE_DIRECTIVE,
    RoleType.DEVILS_ADVOCATE: _load_prompt("devils_advocate.txt") + STANCE_DIRECTIVE,
    RoleType.CUSTOM: "",  # Will use custom_prompt from AgentConfig
}
