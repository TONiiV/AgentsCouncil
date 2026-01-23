"""
AgentsCouncil Backend - Moderator Service

Responsible for generating final summaries and extracting key points.
"""

from app.models import CouncilConfig, Debate, ProviderType
from app.providers import ProviderRegistry


class ModeratorService:
    """Service for moderating debates and generating summaries."""

    def __init__(self, preferred_provider: ProviderType | None = None, model: str | None = None):
        """Initialize with preferred provider and model for moderation tasks."""
        self.provider = None
        self.model = model

        # Try to get preferred provider, fallback to any available
        if preferred_provider:
            self.provider = ProviderRegistry.get(preferred_provider)

        if not self.provider:
            available = ProviderRegistry.get_available()
            if available:
                self.provider = ProviderRegistry.get(available[0])

    async def generate_summary(self, debate: Debate, council: CouncilConfig) -> str:
        """Generate a comprehensive Markdown summary of the debate."""
        if not self.provider:
            return self._fallback_summary(debate)

        # Build context from all rounds
        rounds_text = self._build_rounds_text(debate)

        system_prompt = """You are a skilled moderator and summarizer. Your task is to create 
a clear, structured Markdown summary of a council debate. Be objective and highlight key insights."""

        user_message = f"""Please create a comprehensive summary of this council debate.

**Topic:** {debate.topic}

**Council Members:**
{self._format_council_members(council)}

**Debate Rounds:**
{rounds_text}

**Final Status:** {debate.status.value}

Please create a Markdown summary with the following sections:
1. **Executive Summary** - Brief overview of the topic and conclusion
2. **Key Discussion Points** - Main arguments and insights from each perspective
3. **Areas of Agreement** - Points where council members converged
4. **Areas of Disagreement** - Points of contention that remained
5. **Conclusion** - Final outcome and recommendations

Use bullet points and clear formatting. Be concise but comprehensive.
"""

        summary = await self.provider.generate(
            system_prompt=system_prompt,
            user_message=user_message,
            model=self.model,
            max_tokens=2048,
        )

        return summary

    async def extract_pro_points(self, debate: Debate) -> list[str]:
        """Extract key PRO arguments from the debate."""
        if not self.provider:
            return []

        rounds_text = self._build_rounds_text(debate)

        response = await self.provider.generate(
            system_prompt="You extract key arguments from debates. Be concise.",
            user_message=f"""From this debate on "{debate.topic}", extract the top 3-5 PRO arguments 
(arguments in favor of the topic or proposal). 

Debate content:
{rounds_text}

Return ONLY a numbered list, one argument per line. Be concise (max 2 sentences each).
""",
            model=self.model,
            max_tokens=512,
        )

        return self._parse_list(response)

    async def extract_against_points(self, debate: Debate) -> list[str]:
        """Extract key AGAINST arguments from the debate."""
        if not self.provider:
            return []

        rounds_text = self._build_rounds_text(debate)

        response = await self.provider.generate(
            system_prompt="You extract key arguments from debates. Be concise.",
            user_message=f"""From this debate on "{debate.topic}", extract the top 3-5 AGAINST arguments 
(arguments opposing the topic or proposal, or concerns raised).

Debate content:
{rounds_text}

Return ONLY a numbered list, one argument per line. Be concise (max 2 sentences each).
""",
            model=self.model,
            max_tokens=512,
        )

        return self._parse_list(response)

    def _build_rounds_text(self, debate: Debate) -> str:
        """Build text representation of all rounds."""
        parts = []
        for round_data in debate.rounds:
            parts.append(f"\n### Round {round_data.round_number}")
            for resp in round_data.responses:
                parts.append(f"\n**{resp.agent_name}** ({resp.role.value}):\n{resp.content}")
                if resp.vote:
                    parts.append(f"*Vote: {resp.vote.value}*")
            if round_data.vote_summary:
                parts.append(f"\n**Round Votes:** {round_data.vote_summary}")
        return "\n".join(parts)

    def _format_council_members(self, council: CouncilConfig) -> str:
        """Format council members for display."""
        return "\n".join(
            [
                f"- {agent.name}: {agent.role.value} ({agent.provider.value})"
                for agent in council.agents
            ]
        )

    def _parse_list(self, text: str) -> list[str]:
        """Parse a numbered or bulleted list from text."""
        lines = text.strip().split("\n")
        points = []
        for line in lines:
            # Remove numbering, bullets, etc.
            cleaned = line.strip()
            if cleaned:
                # Remove common prefixes
                for prefix in ["1.", "2.", "3.", "4.", "5.", "-", "*", "•"]:
                    if cleaned.startswith(prefix):
                        cleaned = cleaned[len(prefix) :].strip()
                        break
                if cleaned:
                    points.append(cleaned)
        return points[:5]  # Max 5 points

    def _fallback_summary(self, debate: Debate) -> str:
        """Generate basic summary without AI when no provider available."""
        rounds_summary = []
        for r in debate.rounds:
            votes = r.vote_summary or {}
            rounds_summary.append(
                f"- Round {r.round_number}: Agree({votes.get('agree', 0)}), "
                f"Disagree({votes.get('disagree', 0)}), Abstain({votes.get('abstain', 0)})"
            )

        return f"""# Debate Summary

## Topic
{debate.topic}

## Status
{debate.status.value}

## Rounds
{chr(10).join(rounds_summary)}

## Note
Detailed AI summary not available (no AI provider configured for moderation).
"""
