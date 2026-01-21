"""
AgentsCouncil Backend - Debate Engine

Core logic for managing multi-agent debates, rounds, and voting.
"""
import asyncio
import logging
from collections.abc import Callable
from datetime import datetime

from app.models import (
    AgentConfig,
    AgentResponse,
    CouncilConfig,
    Debate,
    DebateRound,
    DebateStatus,
    DebateUpdate,
    VoteType,
)
from app.providers import ProviderRegistry

logger = logging.getLogger(__name__)


class DebateEngine:
    """Engine for orchestrating multi-agent debates."""

    def __init__(self, council: CouncilConfig, topic: str):
        self.council = council
        self.topic = topic
        self.debate = Debate(
            council_id=council.id,
            topic=topic,
            status=DebateStatus.IN_PROGRESS,
        )
        self._event_callbacks: list[Callable[[DebateUpdate], None]] = []

    def on_event(self, callback: Callable[[DebateUpdate], None]) -> None:
        """Register callback for debate events."""
        self._event_callbacks.append(callback)

    async def _emit_event(self, event_type: str, data: dict) -> None:
        """Emit event to all registered callbacks."""
        update = DebateUpdate(
            debate_id=self.debate.id,
            event_type=event_type,
            data=data,
        )
        for callback in self._event_callbacks:
            if asyncio.iscoroutinefunction(callback):
                await callback(update)
            else:
                callback(update)

    async def run(self) -> Debate:
        """Run the complete debate until consensus or round limit."""
        try:
            await self._emit_event("debate_start", {"topic": self.topic})

            while self.debate.current_round < self.council.max_rounds:
                self.debate.current_round += 1
                round_result = await self._run_round(self.debate.current_round)
                self.debate.rounds.append(round_result)

                if round_result.consensus_reached:
                    self.debate.status = DebateStatus.CONSENSUS_REACHED
                    break

            if self.debate.status == DebateStatus.IN_PROGRESS:
                self.debate.status = DebateStatus.ROUND_LIMIT_REACHED

            # Generate final summary
            self.debate.summary = await self._generate_summary()
            self.debate.completed_at = datetime.utcnow()

            await self._emit_event("debate_complete", {
                "status": self.debate.status.value,
                "summary": self.debate.summary,
                "pro_points": self.debate.pro_points,
                "against_points": self.debate.against_points,
            })

            return self.debate

        except Exception as e:
            logger.error(f"Debate execution failed: {e}")
            self.debate.status = DebateStatus.ERROR
            self.debate.error_message = str(e)
            raise  # Re-raise to let caller handle logging/storage updates

    async def _run_round(self, round_number: int) -> DebateRound:
        """Run a single debate round with all agents in parallel."""
        await self._emit_event("round_start", {"round": round_number})

        round_result = DebateRound(round_number=round_number)

        # Build context from previous rounds
        context = self._build_round_context(round_number)

        # Emit thinking events for all agents
        for agent in self.council.agents:
            await self._emit_event("agent_thinking", {
                "round": round_number,
                "agent_id": str(agent.id),
                "agent_name": agent.name,
            })

        # Run ALL agents in parallel - streams will interleave naturally
        response_tasks = [
            self._stream_and_collect_response(agent, context, round_number)
            for agent in self.council.agents
        ]
        responses = await asyncio.gather(*response_tasks, return_exceptions=True)

        # Process results and emit completion events
        for response in responses:
            if isinstance(response, Exception):
                logger.error(f"Agent response failed: {response}")
                continue
            round_result.responses.append(response)
            await self._emit_event("agent_response", {
                "round": round_number,
                "agent_id": str(response.agent_id),
                "agent_name": response.agent_name,
                "role": response.role.value,
                "provider": response.provider.value,
                "content": response.content,
            })

        # Collect votes in parallel
        vote_tasks = [
            self._get_agent_vote(agent, round_result.responses)
            for agent in self.council.agents
        ]
        vote_results = await asyncio.gather(*vote_tasks, return_exceptions=True)

        # Process vote results
        for agent, vote_response in zip(self.council.agents, vote_results):
            if isinstance(vote_response, Exception):
                logger.error(f"Vote from {agent.name} failed: {vote_response}")
                continue
            
            round_result.votes[str(agent.id)] = vote_response.vote

            # Update response with vote info
            for resp in round_result.responses:
                if resp.agent_id == agent.id:
                    resp.vote = vote_response.vote
                    resp.reasoning = vote_response.reasoning

            await self._emit_event("vote", {
                "round": round_number,
                "agent_id": str(agent.id),
                "agent_name": agent.name,
                "vote": vote_response.vote.value if vote_response.vote else None,
            })

        # Calculate vote summary
        round_result.vote_summary = self._calculate_vote_summary(round_result.votes)
        round_result.consensus_reached = self._check_consensus(round_result.vote_summary)

        await self._emit_event("round_complete", {
            "round": round_number,
            "vote_summary": round_result.vote_summary,
            "consensus": round_result.consensus_reached,
        })

        return round_result


    def _build_round_context(self, current_round: int) -> str:
        """Build context string from previous rounds for agent reference."""
        if current_round == 1:
            return f"This is the first round of debate on the topic: {self.topic}"

        context_parts = [f"Topic: {self.topic}\n\nPrevious rounds:"]
        for round_data in self.debate.rounds:
            context_parts.append(f"\n--- Round {round_data.round_number} ---")
            for resp in round_data.responses:
                context_parts.append(
                    f"\n{resp.agent_name} ({resp.role.value}):\n{resp.content}"
                )
            if round_data.vote_summary:
                context_parts.append(f"\nVotes: {round_data.vote_summary}")

        return "\n".join(context_parts)

    async def _stream_and_collect_response(
        self, agent: AgentConfig, context: str, round_number: int
    ) -> AgentResponse:
        """Stream response from agent and collect full content."""
        logger.info(f"Streaming response from {agent.name} ({agent.provider.value}) for round {round_number}")
        provider = ProviderRegistry.get(agent.provider)
        if not provider:
            logger.error(f"Provider {agent.provider} not available for agent {agent.name}")
            raise ValueError(f"Provider {agent.provider} not available")

        system_prompt = provider.get_system_prompt(agent)
        user_message = f"""You are participating in a council debate on the following topic:

{context}

This is round {round_number}. Please provide your perspective, considering other viewpoints shared.
Be concise but thorough. Focus on your area of expertise ({agent.role.value}).
"""
        full_content = ""
        
        try:
            # We use a timeout for the entire stream to prevent hanging
            # But we also need to handle the stream iterator
            async def consume_stream():
                nonlocal full_content
                async for chunk in provider.generate_stream(
                    system_prompt=system_prompt,
                    user_message=user_message,
                    model=agent.model,
                ):
                    full_content += chunk
                    await self._emit_event("agent_response_chunk", {
                        "round": round_number,
                        "agent_id": str(agent.id),
                        "agent_name": agent.name,
                        "role": agent.role.value,
                        "provider": agent.provider.value,
                        "chunk": chunk,
                        "full_content_so_far": full_content,
                    })

            await asyncio.wait_for(consume_stream(), timeout=90.0)
            
        except TimeoutError:
            logger.error(f"Timeout waiting for agent {agent.name}")
            raise TimeoutError(f"Agent {agent.name} failed to respond in time")
        except Exception as e:
            logger.error(f"Error generating response from {agent.name}: {e}")
            raise

        return AgentResponse(
            agent_id=agent.id,
            agent_name=agent.name,
            role=agent.role,
            provider=agent.provider,
            content=full_content,
        )

    async def _get_agent_vote(
        self, agent: AgentConfig, responses: list[AgentResponse]
    ) -> AgentResponse:
        """Get a vote from an agent after seeing all responses."""
        logger.info(f"Getting vote from {agent.name} ({agent.provider.value})")
        provider = ProviderRegistry.get(agent.provider)
        if not provider:
            logger.error(f"Provider {agent.provider} not available for agent {agent.name}")
            raise ValueError(f"Provider {agent.provider} not available")

        # Build summary of all responses for voting
        responses_text = "\n\n".join([
            f"{r.agent_name} ({r.role.value}):\n{r.content}"
            for r in responses
        ])

        system_prompt = f"""You are {agent.name}, a {agent.role.value}. 
You must vote on whether consensus has been reached based on the discussion."""

        user_message = f"""Based on the following responses from all council members:

{responses_text}

Please vote and explain your reasoning.
Respond in this exact format:
VOTE: [AGREE/DISAGREE/ABSTAIN]
REASONING: [Your brief explanation]

Vote AGREE if you believe the council is converging on a reasonable conclusion.
Vote DISAGREE if you have significant concerns that need further discussion.
Vote ABSTAIN if you're uncertain or need more information.
"""

        try:
            # Add timeout for voting as well
            response_text = await asyncio.wait_for(
                provider.generate(
                    system_prompt=system_prompt,
                    user_message=user_message,
                    model=agent.model,
                    max_tokens=256,
                ),
                timeout=30.0  # 30 second timeout for voting
            )
        except TimeoutError:
            logger.error(f"Timeout waiting for vote from {agent.name}")
            raise TimeoutError(f"Agent {agent.name} failed to vote in time")

        # Parse vote from response
        vote = VoteType.ABSTAIN
        reasoning = response_text

        if "VOTE:" in response_text:
            vote_line = response_text.split("VOTE:")[1].split("\n")[0].strip().upper()
            # Check DISAGREE first since it contains "AGREE" as a substring
            if "DISAGREE" in vote_line:
                vote = VoteType.DISAGREE
            elif "AGREE" in vote_line:
                vote = VoteType.AGREE

        if "REASONING:" in response_text:
            reasoning = response_text.split("REASONING:")[1].strip()

        return AgentResponse(
            agent_id=agent.id,
            agent_name=agent.name,
            role=agent.role,
            provider=agent.provider,
            content="",
            vote=vote,
            reasoning=reasoning,
        )

    def _calculate_vote_summary(self, votes: dict[str, VoteType]) -> dict[str, int]:
        """Calculate vote counts."""
        summary = {"agree": 0, "disagree": 0, "abstain": 0}
        for vote in votes.values():
            summary[vote.value] += 1
        return summary

    def _check_consensus(self, vote_summary: dict[str, int]) -> bool:
        """Check if consensus threshold has been reached."""
        total = sum(vote_summary.values())
        if total == 0:
            return False
        agree_ratio = vote_summary["agree"] / total
        return agree_ratio >= self.council.consensus_threshold

    async def _generate_summary(self) -> str:
        """Generate final moderator summary."""
        from app.core.moderator import ModeratorService

        # Prefer the provider and model of the first agent
        preferred_provider = None
        preferred_model = None
        if self.council.agents:
            preferred_provider = self.council.agents[0].provider
            preferred_model = self.council.agents[0].model

        moderator = ModeratorService(preferred_provider=preferred_provider, model=preferred_model)
        summary = await moderator.generate_summary(self.debate, self.council)

        # Extract pro/against points
        self.debate.pro_points = await moderator.extract_pro_points(self.debate)
        self.debate.against_points = await moderator.extract_against_points(self.debate)

        return summary

