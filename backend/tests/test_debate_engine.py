"""
Tests for Debate Engine
"""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

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
from app.core.debate_engine import DebateEngine


class TestDebateEngineInit:
    """Tests for DebateEngine initialization."""

    def test_create_engine(self, sample_council):
        """Test creating a debate engine."""
        engine = DebateEngine(sample_council, "Test topic")
        
        assert engine.council == sample_council
        assert engine.topic == "Test topic"
        assert engine.debate is not None
        assert engine.debate.status == DebateStatus.IN_PROGRESS
        assert engine.debate.topic == "Test topic"
        assert engine.debate.council_id == sample_council.id

    def test_engine_creates_debate_id(self, sample_council):
        """Test that engine creates a unique debate ID."""
        engine = DebateEngine(sample_council, "Test topic")
        assert engine.debate.id is not None


class TestDebateEngineEvents:
    """Tests for debate engine event system."""

    def test_register_event_callback(self, sample_council):
        """Test registering an event callback."""
        engine = DebateEngine(sample_council, "Test topic")
        callback = MagicMock()
        
        engine.on_event(callback)
        
        assert callback in engine._event_callbacks

    @pytest.mark.asyncio
    async def test_emit_event_calls_callbacks(self, sample_council):
        """Test that emitting events calls all registered callbacks."""
        engine = DebateEngine(sample_council, "Test topic")
        callback1 = MagicMock()
        callback2 = MagicMock()
        
        engine.on_event(callback1)
        engine.on_event(callback2)
        
        await engine._emit_event("test_event", {"key": "value"})
        
        assert callback1.call_count == 1
        assert callback2.call_count == 1

    @pytest.mark.asyncio
    async def test_emit_event_with_async_callback(self, sample_council):
        """Test emitting events with async callbacks."""
        engine = DebateEngine(sample_council, "Test topic")
        async_callback = AsyncMock()
        
        engine.on_event(async_callback)
        
        await engine._emit_event("test_event", {"key": "value"})
        
        async_callback.assert_called_once()


class TestDebateEngineVoting:
    """Tests for voting logic."""

    def test_calculate_vote_summary(self, sample_council):
        """Test calculating vote summary."""
        engine = DebateEngine(sample_council, "Test topic")
        
        votes = {
            "agent1": VoteType.AGREE,
            "agent2": VoteType.AGREE,
            "agent3": VoteType.DISAGREE,
        }
        
        summary = engine._calculate_vote_summary(votes)
        
        assert summary["agree"] == 2
        assert summary["disagree"] == 1
        assert summary["abstain"] == 0

    def test_calculate_vote_summary_with_abstain(self, sample_council):
        """Test calculating vote summary with abstain votes."""
        engine = DebateEngine(sample_council, "Test topic")
        
        votes = {
            "agent1": VoteType.AGREE,
            "agent2": VoteType.ABSTAIN,
            "agent3": VoteType.ABSTAIN,
        }
        
        summary = engine._calculate_vote_summary(votes)
        
        assert summary["agree"] == 1
        assert summary["disagree"] == 0
        assert summary["abstain"] == 2

    def test_check_consensus_reached(self, sample_council):
        """Test consensus is reached when threshold is met."""
        engine = DebateEngine(sample_council, "Test topic")
        
        # 80% threshold (from sample_council)
        vote_summary = {"agree": 4, "disagree": 1, "abstain": 0}
        
        assert engine._check_consensus(vote_summary) is True

    def test_check_consensus_not_reached(self, sample_council):
        """Test consensus is not reached below threshold."""
        engine = DebateEngine(sample_council, "Test topic")
        
        vote_summary = {"agree": 1, "disagree": 1, "abstain": 0}
        
        assert engine._check_consensus(vote_summary) is False

    def test_check_consensus_empty_votes(self, sample_council):
        """Test consensus calculation with no votes."""
        engine = DebateEngine(sample_council, "Test topic")
        
        vote_summary = {"agree": 0, "disagree": 0, "abstain": 0}
        
        assert engine._check_consensus(vote_summary) is False


class TestDebateEngineContext:
    """Tests for building debate context."""

    def test_build_round_context_first_round(self, sample_council):
        """Test context building for first round."""
        engine = DebateEngine(sample_council, "Test topic")
        
        context = engine._build_round_context(1)
        
        assert "first round" in context.lower()
        assert "Test topic" in context

    def test_build_round_context_with_previous_rounds(self, sample_council):
        """Test context building includes previous rounds."""
        engine = DebateEngine(sample_council, "Test topic")
        
        # Add a previous round
        round1 = DebateRound(
            round_number=1,
            responses=[
                AgentResponse(
                    agent_id=uuid4(),
                    agent_name="Agent 1",
                    role=RoleType.TECH_STRATEGIST,
                    provider=ProviderType.GEMINI,
                    content="This is agent 1's response.",
                )
            ],
            vote_summary={"agree": 1, "disagree": 0, "abstain": 0},
        )
        engine.debate.rounds.append(round1)
        
        context = engine._build_round_context(2)
        
        assert "Round 1" in context
        assert "Agent 1" in context
        assert "This is agent 1's response" in context


class TestDebateEngineRun:
    """Tests for running debates with mocked providers."""

    @pytest.mark.asyncio
    async def test_run_debate_with_mocked_provider(self, sample_council, mock_provider):
        """Test running a complete debate with mocked provider."""
        with patch('app.core.debate_engine.ProviderRegistry') as mock_registry:
            mock_registry.get.return_value = mock_provider
            
            engine = DebateEngine(sample_council, "Test topic")
            
            # Mock provider generate to return vote-like response
            mock_provider.generate = AsyncMock(
                side_effect=[
                    # Agent 1 response
                    "This is my perspective on the topic.",
                    # Agent 2 response  
                    "I have a different view on this.",
                    # Agent 1 vote
                    "VOTE: AGREE\nREASONING: I agree with the consensus.",
                    # Agent 2 vote
                    "VOTE: AGREE\nREASONING: I also agree.",
                ]
            )
            
            with patch.object(engine, '_generate_summary', new_callable=AsyncMock) as mock_summary:
                mock_summary.return_value = "# Summary\nTest summary"
                
                result = await engine.run()
                
                assert result.status in [
                    DebateStatus.CONSENSUS_REACHED,
                    DebateStatus.ROUND_LIMIT_REACHED,
                ]
                assert len(result.rounds) > 0

    @pytest.mark.asyncio
    async def test_run_round_collects_responses(self, sample_council, mock_provider):
        """Test that running a round collects all agent responses."""
        with patch('app.core.debate_engine.ProviderRegistry') as mock_registry:
            mock_registry.get.return_value = mock_provider
            
            engine = DebateEngine(sample_council, "Test topic")
            
            mock_provider.generate = AsyncMock(
                side_effect=[
                    "Response 1",
                    "Response 2",
                    "VOTE: AGREE\nREASONING: Reason 1",
                    "VOTE: AGREE\nREASONING: Reason 2",
                ]
            )
            
            round_result = await engine._run_round(1)
            
            # Should have responses from both agents
            assert len(round_result.responses) == 2

    @pytest.mark.asyncio
    async def test_get_agent_response_error_handling(self, sample_council):
        """Test error handling when provider is unavailable."""
        with patch('app.core.debate_engine.ProviderRegistry') as mock_registry:
            mock_registry.get.return_value = None
            
            engine = DebateEngine(sample_council, "Test topic")
            agent = sample_council.agents[0]
            
            with pytest.raises(ValueError, match="not available"):
                await engine._get_agent_response(agent, "context", 1)


class TestVoteParsingLogic:
    """Tests for vote parsing from AI responses."""

    @pytest.mark.asyncio
    async def test_parse_agree_vote(self, sample_council, mock_provider):
        """Test parsing AGREE vote from response."""
        with patch('app.core.debate_engine.ProviderRegistry') as mock_registry:
            mock_registry.get.return_value = mock_provider
            mock_provider.generate = AsyncMock(
                return_value="VOTE: AGREE\nREASONING: I fully support this proposal."
            )
            
            engine = DebateEngine(sample_council, "Test topic")
            agent = sample_council.agents[0]
            responses = [
                AgentResponse(
                    agent_id=uuid4(),
                    agent_name="Test",
                    role=RoleType.TECH_STRATEGIST,
                    provider=ProviderType.GEMINI,
                    content="Test content",
                )
            ]
            
            result = await engine._get_agent_vote(agent, responses)
            
            assert result.vote == VoteType.AGREE
            assert "fully support" in result.reasoning

    @pytest.mark.asyncio
    async def test_parse_disagree_vote(self, sample_council):
        """Test parsing DISAGREE vote from response."""
        # Create a fresh mock to avoid any state issues
        fresh_mock_provider = MagicMock()
        fresh_mock_provider.generate = AsyncMock(
            return_value="VOTE: DISAGREE\nREASONING: I have concerns."
        )
        fresh_mock_provider.get_system_prompt = MagicMock(return_value="You are a test assistant.")
        
        with patch('app.core.debate_engine.ProviderRegistry') as mock_registry:
            mock_registry.get.return_value = fresh_mock_provider
            
            engine = DebateEngine(sample_council, "Test topic")
            agent = sample_council.agents[0]
            responses = []
            
            result = await engine._get_agent_vote(agent, responses)
            
            assert result.vote == VoteType.DISAGREE

    @pytest.mark.asyncio
    async def test_parse_abstain_default(self, sample_council, mock_provider):
        """Test that unparseable votes default to ABSTAIN."""
        with patch('app.core.debate_engine.ProviderRegistry') as mock_registry:
            mock_registry.get.return_value = mock_provider
            mock_provider.generate = AsyncMock(
                return_value="I'm not sure how to vote on this."
            )
            
            engine = DebateEngine(sample_council, "Test topic")
            agent = sample_council.agents[0]
            responses = []
            
            result = await engine._get_agent_vote(agent, responses)
            
            assert result.vote == VoteType.ABSTAIN
