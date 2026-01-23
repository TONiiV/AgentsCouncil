"""
Tests for Moderator Service
"""

from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest

from app.core.moderator import ModeratorService
from app.models import (
    AgentConfig,
    AgentResponse,
    CouncilConfig,
    Debate,
    DebateRound,
    DebateStatus,
    ProviderType,
    RoleType,
    VoteType,
)


class TestModeratorService:
    """Tests for ModeratorService."""

    @pytest.fixture
    def sample_debate(self) -> Debate:
        """Create a sample debate with responses."""
        debate = Debate(
            id=uuid4(),
            council_id=uuid4(),
            topic="Should we invest in renewable energy?",
            status=DebateStatus.CONSENSUS_REACHED,
            current_round=2,
        )
        round1 = DebateRound(
            round_number=1,
            responses=[
                AgentResponse(
                    agent_id=uuid4(),
                    agent_name="Investment Advisor",
                    role=RoleType.INVESTMENT_ADVISOR,
                    provider=ProviderType.OPENAI,
                    content="Renewable energy offers strong long-term returns with growing demand.",
                    vote=VoteType.AGREE,
                    reasoning="Strong market fundamentals and government incentives.",
                ),
                AgentResponse(
                    agent_id=uuid4(),
                    agent_name="Legal Expert",
                    role=RoleType.LEGAL_ADVISOR,
                    provider=ProviderType.ANTHROPIC,
                    content="Regulatory frameworks are favorable with tax credits available.",
                    vote=VoteType.AGREE,
                    reasoning="Compliance requirements are manageable.",
                ),
            ],
            votes={
                "agent1": VoteType.AGREE,
                "agent2": VoteType.AGREE,
            },
            vote_summary={"agree": 2, "disagree": 0, "abstain": 0},
            consensus_reached=True,
        )
        debate.rounds.append(round1)
        return debate

    @pytest.fixture
    def sample_council(self) -> CouncilConfig:
        """Create a sample council."""
        return CouncilConfig(
            id=uuid4(),
            name="Investment Council",
            agents=[
                AgentConfig(
                    id=uuid4(),
                    name="Investment Advisor",
                    provider=ProviderType.OPENAI,
                    role=RoleType.INVESTMENT_ADVISOR,
                ),
                AgentConfig(
                    id=uuid4(),
                    name="Legal Expert",
                    provider=ProviderType.ANTHROPIC,
                    role=RoleType.LEGAL_ADVISOR,
                ),
            ],
            max_rounds=5,
            consensus_threshold=0.8,
        )

    def test_initialization_no_provider(self):
        """Test initialization when no providers are available."""
        with patch("app.core.moderator.ProviderRegistry") as mock_registry:
            mock_registry.get_available.return_value = []

            moderator = ModeratorService()

            assert moderator.provider is None
            assert moderator.model is None

    def test_initialization_with_preferred_provider(self):
        """Test initialization with a preferred provider."""
        mock_provider = MagicMock()

        with patch("app.core.moderator.ProviderRegistry") as mock_registry:
            mock_registry.get.return_value = mock_provider

            moderator = ModeratorService(preferred_provider=ProviderType.OPENAI)

            mock_registry.get.assert_called_with(ProviderType.OPENAI)
            assert moderator.provider == mock_provider

    def test_initialization_fallback_to_available(self):
        """Test fallback to first available provider."""
        mock_provider = MagicMock()

        with patch("app.core.moderator.ProviderRegistry") as mock_registry:
            mock_registry.get.return_value = None
            mock_registry.get_available.return_value = [ProviderType.GEMINI]
            mock_registry.get.side_effect = (
                lambda p: mock_provider if p == ProviderType.GEMINI else None
            )

            moderator = ModeratorService()

            assert moderator.provider == mock_provider

    @pytest.mark.asyncio
    async def test_fallback_summary(self, sample_debate):
        """Test fallback summary generation when no provider available."""
        moderator = ModeratorService()

        summary = moderator._fallback_summary(sample_debate)

        assert "# Debate Summary" in summary
        assert sample_debate.topic in summary
        assert "Round 1: Agree(2)" in summary

    @pytest.mark.asyncio
    async def test_generate_summary_with_provider(self, sample_debate, sample_council):
        """Test summary generation with a mock provider."""
        mock_provider = MagicMock()
        mock_provider.generate = AsyncMock(
            return_value="# Debate Summary\n\n## Executive Summary\nThe council reached consensus."
        )

        with patch("app.core.moderator.ProviderRegistry") as mock_registry:
            mock_registry.get.return_value = mock_provider

            moderator = ModeratorService()
            moderator.provider = mock_provider

            summary = await moderator.generate_summary(sample_debate, sample_council)

            assert "# Debate Summary" in summary
            mock_provider.generate.assert_called_once()

    @pytest.mark.asyncio
    async def test_generate_summary_prompts_correctly(self, sample_debate, sample_council):
        """Test that summary prompt includes all required information."""
        mock_provider = MagicMock()
        mock_provider.generate = AsyncMock(return_value="Summary")

        with patch("app.core.moderator.ProviderRegistry") as mock_registry:
            mock_registry.get.return_value = mock_provider

            moderator = ModeratorService()
            moderator.provider = mock_provider

            await moderator.generate_summary(sample_debate, sample_council)

            # Check the user message contains required info
            call_args = mock_provider.generate.call_args
            user_message = call_args.kwargs.get(
                "user_message", call_args[1].get("user_message", "")
            )

            assert sample_debate.topic in user_message
            assert "Investment Advisor" in user_message
            assert "Legal Expert" in user_message
            assert "Executive Summary" in user_message
            assert "Key Discussion Points" in user_message

    @pytest.mark.asyncio
    async def test_extract_pro_points(self, sample_debate):
        """Test extracting pro arguments from debate."""
        mock_provider = MagicMock()
        mock_provider.generate = AsyncMock(
            return_value="1. Strong market fundamentals\n2. Government incentives"
        )

        with patch("app.core.moderator.ProviderRegistry") as mock_registry:
            mock_registry.get.return_value = mock_provider

            moderator = ModeratorService()
            moderator.provider = mock_provider

            pro_points = await moderator.extract_pro_points(sample_debate)

            assert len(pro_points) == 2
            assert "Strong market fundamentals" in pro_points[0]
            assert "Government incentives" in pro_points[1]

    @pytest.mark.asyncio
    async def test_extract_against_points(self, sample_debate):
        """Test extracting against arguments from debate."""
        mock_provider = MagicMock()
        mock_provider.generate = AsyncMock(
            return_value="1. High initial investment\n2. Intermittency issues"
        )

        with patch("app.core.moderator.ProviderRegistry") as mock_registry:
            mock_registry.get.return_value = mock_provider

            moderator = ModeratorService()
            moderator.provider = mock_provider

            against_points = await moderator.extract_against_points(sample_debate)

            assert len(against_points) == 2
            assert "High initial investment" in against_points[0]

    @pytest.mark.asyncio
    async def test_extract_pro_points_no_provider(self, sample_debate):
        """Test extracting pro points returns empty when no provider."""
        moderator = ModeratorService()
        # Explicitly ensure no provider
        moderator.provider = None

        pro_points = await moderator.extract_pro_points(sample_debate)

        assert pro_points == []

    @pytest.mark.asyncio
    async def test_extract_against_points_no_provider(self, sample_debate):
        """Test extracting against points returns empty when no provider."""
        moderator = ModeratorService()
        # Explicitly ensure no provider
        moderator.provider = None

        against_points = await moderator.extract_against_points(sample_debate)

        assert against_points == []

    def test_build_rounds_text(self, sample_debate):
        """Test building text representation of rounds."""
        moderator = ModeratorService()

        rounds_text = moderator._build_rounds_text(sample_debate)

        assert "Round 1" in rounds_text
        assert "Investment Advisor" in rounds_text
        assert "Legal Expert" in rounds_text
        assert "*Vote: agree*" in rounds_text
        assert "agree" in rounds_text  # Lowercase because VoteType.value
        assert "2" in rounds_text  # Vote count

    def test_format_council_members(self, sample_council):
        """Test formatting council members."""
        moderator = ModeratorService()

        formatted = moderator._format_council_members(sample_council)

        assert "- Investment Advisor: investment_advisor (openai)" in formatted
        assert "- Legal Expert: legal_advisor (anthropic)" in formatted

    def test_parse_list_numbered(self):
        """Test parsing numbered list."""
        moderator = ModeratorService()

        result = moderator._parse_list("1. First point\n2. Second point\n3. Third point")

        assert len(result) == 3
        assert result[0] == "First point"
        assert result[1] == "Second point"

    def test_parse_list_bulleted(self):
        """Test parsing bulleted list."""
        moderator = ModeratorService()

        result = moderator._parse_list("- First point\n- Second point\n* Third point")

        assert len(result) == 3
        assert result[0] == "First point"

    def test_parse_list_max_5(self):
        """Test parsing list limited to 5 items."""
        moderator = ModeratorService()

        result = moderator._parse_list(
            "1. Point 1\n2. Point 2\n3. Point 3\n4. Point 4\n5. Point 5\n6. Point 6"
        )

        assert len(result) == 5

    def test_parse_list_empty_lines(self):
        """Test parsing list with empty lines."""
        moderator = ModeratorService()

        result = moderator._parse_list("1. Point 1\n\n2. Point 2\n\n")

        assert len(result) == 2

    def test_parse_list_mixed_prefixes(self):
        """Test parsing list with mixed prefixes."""
        moderator = ModeratorService()

        result = moderator._parse_list("1. Numbered\n- Bulleted\n* Asterisk\n• Bullet")

        assert len(result) == 4
        assert result[0] == "Numbered"
        assert result[1] == "Bulleted"

    @pytest.mark.asyncio
    async def test_generate_summary_with_model_override(self, sample_debate, sample_council):
        """Test summary generation with custom model."""
        mock_provider = MagicMock()
        mock_provider.generate = AsyncMock(return_value="Summary")

        with patch("app.core.moderator.ProviderRegistry") as mock_registry:
            mock_registry.get.return_value = mock_provider

            moderator = ModeratorService(model="gemini-1.5-pro")
            moderator.provider = mock_provider

            await moderator.generate_summary(sample_debate, sample_council)

            call_args = mock_provider.generate.call_args
            assert call_args.kwargs.get("model") == "gemini-1.5-pro"


class TestModeratorServiceEdgeCases:
    """Tests for edge cases in ModeratorService."""

    @pytest.fixture
    def empty_debate(self) -> Debate:
        """Create a debate with no rounds."""
        return Debate(
            id=uuid4(),
            council_id=uuid4(),
            topic="Empty debate",
            status=DebateStatus.PENDING,
            current_round=0,
            rounds=[],
        )

    @pytest.fixture
    def empty_council(self) -> CouncilConfig:
        """Create a council with no agents."""
        return CouncilConfig(
            id=uuid4(),
            name="Empty Council",
            agents=[],
            max_rounds=5,
            consensus_threshold=0.8,
        )

    def test_fallback_summary_empty_debate(self, empty_debate):
        """Test fallback summary with no rounds."""
        moderator = ModeratorService()

        summary = moderator._fallback_summary(empty_debate)

        assert "# Debate Summary" in summary
        assert "Empty debate" in summary
        assert "Rounds" in summary
        # With no rounds, should not show any round information

    def test_build_rounds_text_empty(self, empty_debate):
        """Test building rounds text with no rounds."""
        moderator = ModeratorService()

        rounds_text = moderator._build_rounds_text(empty_debate)

        assert rounds_text == ""

    def test_format_council_members_empty(self, empty_council):
        """Test formatting council members with no agents."""
        moderator = ModeratorService()

        formatted = moderator._format_council_members(empty_council)

        assert formatted == ""

    @pytest.mark.asyncio
    async def test_extract_points_empty_debate(self, empty_debate):
        """Test extracting points from empty debate."""
        mock_provider = MagicMock()
        mock_provider.generate = AsyncMock(return_value="")

        with patch("app.core.moderator.ProviderRegistry") as mock_registry:
            mock_registry.get.return_value = mock_provider

            moderator = ModeratorService()
            moderator.provider = mock_provider

            pro_points = await moderator.extract_pro_points(empty_debate)
            against_points = await moderator.extract_against_points(empty_debate)

            assert pro_points == []
            assert against_points == []

    def test_parse_list_empty(self):
        """Test parsing empty list."""
        moderator = ModeratorService()

        result = moderator._parse_list("")

        assert result == []

    def test_parse_list_only_whitespace(self):
        """Test parsing list with only whitespace."""
        moderator = ModeratorService()

        result = moderator._parse_list("   \n   \n   ")

        assert result == []
