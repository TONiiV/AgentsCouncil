"""
Pytest Configuration and Shared Fixtures
"""

from collections.abc import Generator
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models import (
    AgentConfig,
    CouncilConfig,
    Debate,
    DebateRound,
    DebateStatus,
    ProviderType,
    RoleType,
    VoteType,
)
from app.storage import Storage


@pytest.fixture(autouse=True)
def clear_storage():
    """Clear storage before and after each test."""
    Storage.clear()
    yield
    Storage.clear()


@pytest.fixture
def sample_agent_openai() -> AgentConfig:
    """Create a sample OpenAI agent."""
    return AgentConfig(
        id=uuid4(),
        name="Financial Advisor",
        provider=ProviderType.OPENAI,
        role=RoleType.INVESTMENT_ADVISOR,
    )


@pytest.fixture
def sample_agent_gemini() -> AgentConfig:
    """Create a sample Gemini agent."""
    return AgentConfig(
        id=uuid4(),
        name="Tech Expert",
        provider=ProviderType.GEMINI,
        role=RoleType.TECH_STRATEGIST,
    )


@pytest.fixture
def sample_agent_anthropic() -> AgentConfig:
    """Create a sample Anthropic agent."""
    return AgentConfig(
        id=uuid4(),
        name="Legal Expert",
        provider=ProviderType.ANTHROPIC,
        role=RoleType.LEGAL_ADVISOR,
    )


@pytest.fixture
def sample_agent_devils_advocate() -> AgentConfig:
    """Create a Devil's Advocate agent."""
    return AgentConfig(
        id=uuid4(),
        name="The Skeptic",
        provider=ProviderType.GEMINI,
        role=RoleType.DEVILS_ADVOCATE,
    )


@pytest.fixture
def sample_council(sample_agent_gemini, sample_agent_devils_advocate) -> CouncilConfig:
    """Create a sample council with two agents."""
    return CouncilConfig(
        id=uuid4(),
        name="Test Council",
        agents=[sample_agent_gemini, sample_agent_devils_advocate],
        max_rounds=3,
        consensus_threshold=0.8,
    )


@pytest.fixture
def sample_debate(sample_council) -> Debate:
    """Create a sample debate."""
    return Debate(
        id=uuid4(),
        council_id=sample_council.id,
        topic="Should we invest in AI stocks?",
        status=DebateStatus.IN_PROGRESS,
    )


@pytest.fixture
def completed_debate(sample_council) -> Debate:
    """Create a completed debate with rounds."""
    debate = Debate(
        id=uuid4(),
        council_id=sample_council.id,
        topic="Is renewable energy a good investment?",
        status=DebateStatus.CONSENSUS_REACHED,
        current_round=2,
    )
    # Add a sample round
    round1 = DebateRound(
        round_number=1,
        votes={"agent1": VoteType.AGREE, "agent2": VoteType.AGREE},
        vote_summary={"agree": 2, "disagree": 0, "abstain": 0},
        consensus_reached=True,
    )
    debate.rounds.append(round1)
    return debate


@pytest.fixture
def mock_provider():
    """Create a mock AI provider."""
    provider = MagicMock()
    provider.name = "mock"
    provider.default_model = "mock-model"
    provider.generate = AsyncMock(return_value="This is a mock response from the AI.")
    provider.get_system_prompt = MagicMock(return_value="You are a test assistant.")
    return provider


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    """Create a FastAPI test client."""
    with TestClient(app) as client:
        yield client
