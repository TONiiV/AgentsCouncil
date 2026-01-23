"""
AgentsCouncil Backend - Data Models
"""

from datetime import datetime, timezone
from enum import Enum
from uuid import UUID, uuid4

from pydantic import BaseModel, Field

# === Enums ===


class ProviderType(str, Enum):
    """Supported AI providers."""

    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    GEMINI = "gemini"
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
    ABSTAIN = "abstain"


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


# === Debate Models ===


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

ROLE_PROMPTS: dict[RoleType, str] = {
    RoleType.INVESTMENT_ADVISOR: """You are an Investment Advisor with deep expertise in financial markets, 
risk assessment, and portfolio management. Analyze topics from a financial perspective, considering ROI, 
market trends, risk factors, and long-term value creation. Be data-driven and cite relevant financial principles.

You have access to real-time stock market tools:
- get_stock_quote(symbol): Get current price, market cap, P/E ratio, 52-week range for any stock
- get_stock_news(symbol): Get recent financial news and headlines for a stock
- get_market_summary(): Get current S&P 500, NASDAQ, and DOW index values

When discussing specific stocks or market conditions, USE THESE TOOLS to provide accurate, current data.
Always cite the actual numbers from your tool calls to support your analysis.""",
    RoleType.PR_EXPERT: """You are a Public Relations Expert specializing in corporate communications, 
brand management, and crisis communication. Analyze topics from a public perception standpoint, considering 
media impact, stakeholder reactions, and reputation management. Focus on messaging and public sentiment.""",
    RoleType.POLITICS_EXPERT: """You are a Political Analyst with expertise in policy, governance, and 
political strategy. Analyze topics considering political implications, regulatory environment, stakeholder 
interests, and policy impacts. Consider both domestic and international political dynamics.""",
    RoleType.LEGAL_ADVISOR: """You are a Legal Advisor with broad expertise in corporate law, compliance, 
and regulatory matters. Analyze topics from a legal perspective, identifying potential liabilities, 
compliance requirements, contractual implications, and legal risks. Be thorough and cite relevant legal principles.""",
    RoleType.TECH_STRATEGIST: """You are a Technology Strategist with expertise in digital transformation, 
emerging technologies, and technical architecture. Analyze topics from a technical feasibility standpoint, 
considering implementation challenges, scalability, security, and innovation opportunities.""",
    RoleType.DEVILS_ADVOCATE: """You are the Devil's Advocate. Your role is to challenge assumptions, 
identify weaknesses in arguments, and stress-test ideas. Present counterarguments, ask difficult questions, 
and point out potential pitfalls that others might overlook. Be constructively critical.""",
    RoleType.CUSTOM: "",  # Will use custom_prompt from AgentConfig
}
