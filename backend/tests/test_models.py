"""
Tests for Pydantic Models
"""
from datetime import datetime
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.models import (
    ROLE_PROMPTS,
    AgentConfig,
    CouncilConfig,
    Debate,
    DebateCreate,
    DebateRound,
    DebateStatus,
    DebateUpdate,
    ProviderType,
    RoleType,
    VoteType,
)


class TestEnums:
    """Tests for enum definitions."""

    def test_provider_type_values(self):
        """Test ProviderType enum values."""
        assert ProviderType.OPENAI.value == "openai"
        assert ProviderType.ANTHROPIC.value == "anthropic"
        assert ProviderType.GEMINI.value == "gemini"

    def test_role_type_values(self):
        """Test RoleType enum values."""
        assert RoleType.INVESTMENT_ADVISOR.value == "investment_advisor"
        assert RoleType.PR_EXPERT.value == "pr_expert"
        assert RoleType.DEVILS_ADVOCATE.value == "devils_advocate"
        assert RoleType.CUSTOM.value == "custom"

    def test_vote_type_values(self):
        """Test VoteType enum values."""
        assert VoteType.AGREE.value == "agree"
        assert VoteType.DISAGREE.value == "disagree"
        assert VoteType.ABSTAIN.value == "abstain"

    def test_debate_status_values(self):
        """Test DebateStatus enum values."""
        assert DebateStatus.PENDING.value == "pending"
        assert DebateStatus.IN_PROGRESS.value == "in_progress"
        assert DebateStatus.CONSENSUS_REACHED.value == "consensus_reached"
        assert DebateStatus.ERROR.value == "error"


class TestAgentConfig:
    """Tests for AgentConfig model."""

    def test_create_agent_config(self):
        """Test creating a valid AgentConfig."""
        agent = AgentConfig(
            name="Test Agent",
            provider=ProviderType.OPENAI,
            role=RoleType.INVESTMENT_ADVISOR,
        )
        assert agent.name == "Test Agent"
        assert agent.provider == ProviderType.OPENAI
        assert agent.role == RoleType.INVESTMENT_ADVISOR
        assert agent.id is not None  # UUID is auto-generated
        assert agent.custom_prompt is None
        assert agent.model is None

    def test_create_custom_role_agent(self):
        """Test creating an agent with a custom role."""
        agent = AgentConfig(
            name="Custom Agent",
            provider=ProviderType.GEMINI,
            role=RoleType.CUSTOM,
            custom_prompt="You are a specialized agent.",
        )
        assert agent.role == RoleType.CUSTOM
        assert agent.custom_prompt == "You are a specialized agent."

    def test_create_agent_with_model_override(self):
        """Test creating an agent with model override."""
        agent = AgentConfig(
            name="GPT-4 Agent",
            provider=ProviderType.OPENAI,
            role=RoleType.TECH_STRATEGIST,
            model="gpt-4-turbo",
        )
        assert agent.model == "gpt-4-turbo"

    def test_agent_config_missing_required_fields(self):
        """Test that missing required fields raise validation error."""
        with pytest.raises(ValidationError):
            AgentConfig(provider=ProviderType.OPENAI, role=RoleType.PR_EXPERT)


class TestCouncilConfig:
    """Tests for CouncilConfig model."""

    def test_create_council_config(self, sample_agent_gemini, sample_agent_anthropic):
        """Test creating a valid CouncilConfig."""
        council = CouncilConfig(
            name="Test Council",
            agents=[sample_agent_gemini, sample_agent_anthropic],
        )
        assert council.name == "Test Council"
        assert len(council.agents) == 2
        assert council.max_rounds == 5  # Default
        assert council.consensus_threshold == 0.8  # Default

    def test_council_custom_settings(self, sample_agent_gemini):
        """Test creating council with custom settings."""
        council = CouncilConfig(
            name="Custom Council",
            agents=[sample_agent_gemini],
            max_rounds=10,
            consensus_threshold=0.9,
        )
        assert council.max_rounds == 10
        assert council.consensus_threshold == 0.9

    def test_council_created_at_auto(self, sample_agent_gemini):
        """Test that created_at is auto-generated."""
        council = CouncilConfig(
            name="Auto Time Council",
            agents=[sample_agent_gemini],
        )
        assert council.created_at is not None
        assert isinstance(council.created_at, datetime)


class TestDebate:
    """Tests for Debate model."""

    def test_create_debate(self):
        """Test creating a valid Debate."""
        council_id = uuid4()
        debate = Debate(
            council_id=council_id,
            topic="Test debate topic",
        )
        assert debate.council_id == council_id
        assert debate.topic == "Test debate topic"
        assert debate.status == DebateStatus.PENDING  # Default
        assert debate.rounds == []
        assert debate.current_round == 0
        assert debate.error_message is None

    def test_debate_with_error(self):
        """Test debate with error message."""
        debate = Debate(
            council_id=uuid4(),
            topic="Failed debate",
            status=DebateStatus.ERROR,
            error_message="API call failed: rate limit exceeded",
        )
        assert debate.status == DebateStatus.ERROR
        assert debate.error_message == "API call failed: rate limit exceeded"

    def test_debate_serialization(self):
        """Test that debate can be serialized to dict/json."""
        debate = Debate(
            council_id=uuid4(),
            topic="Serialization test",
        )
        data = debate.model_dump(mode="json")
        assert "id" in data
        assert "council_id" in data
        assert "topic" in data
        assert data["topic"] == "Serialization test"


class TestDebateRound:
    """Tests for DebateRound model."""

    def test_create_debate_round(self):
        """Test creating a debate round."""
        round_data = DebateRound(round_number=1)
        assert round_data.round_number == 1
        assert round_data.responses == []
        assert round_data.votes == {}
        assert round_data.consensus_reached is False

    def test_round_with_votes(self):
        """Test round with vote summary."""
        round_data = DebateRound(
            round_number=2,
            votes={"agent1": VoteType.AGREE, "agent2": VoteType.DISAGREE},
            vote_summary={"agree": 1, "disagree": 1, "abstain": 0},
        )
        assert round_data.vote_summary["agree"] == 1
        assert round_data.vote_summary["disagree"] == 1


class TestRolePrompts:
    """Tests for role prompts mapping."""

    def test_all_roles_have_prompts(self):
        """Test that all roles have prompts defined."""
        for role in RoleType:
            assert role in ROLE_PROMPTS

    def test_custom_role_empty_prompt(self):
        """Test that CUSTOM role has empty prompt."""
        assert ROLE_PROMPTS[RoleType.CUSTOM] == ""

    def test_role_prompts_not_empty(self):
        """Test that standard roles have non-empty prompts."""
        for role in RoleType:
            if role != RoleType.CUSTOM:
                assert len(ROLE_PROMPTS[role]) > 0


class TestDebateCreate:
    """Tests for DebateCreate request model."""

    def test_create_debate_request(self):
        """Test creating a DebateCreate request."""
        council_id = uuid4()
        request = DebateCreate(
            council_id=council_id,
            topic="Should we invest in AI?",
        )
        assert request.council_id == council_id
        assert request.topic == "Should we invest in AI?"


class TestDebateUpdate:
    """Tests for DebateUpdate WebSocket model."""

    def test_create_debate_update(self):
        """Test creating a DebateUpdate."""
        debate_id = uuid4()
        update = DebateUpdate(
            debate_id=debate_id,
            event_type="round_start",
            data={"round": 1},
        )
        assert update.debate_id == debate_id
        assert update.event_type == "round_start"
        assert update.data["round"] == 1
