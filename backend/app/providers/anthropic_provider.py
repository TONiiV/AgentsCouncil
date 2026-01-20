"""
AgentsCouncil Backend - Anthropic Provider
"""
from typing import AsyncIterator, Optional

import anthropic

from app.providers.base import BaseProvider


class AnthropicProvider(BaseProvider):
    """Anthropic Claude API provider implementation."""

    def __init__(self, api_key: str):
        super().__init__(api_key)
        self.client = anthropic.AsyncAnthropic(api_key=api_key)

    @property
    def name(self) -> str:
        return "anthropic"

    @property
    def default_model(self) -> str:
        return "claude-3-5-sonnet-20241022"

    async def generate(
        self,
        system_prompt: str,
        user_message: str,
        model: Optional[str] = None,
        max_tokens: int = 1024,
    ) -> str:
        """Generate a response using Anthropic API."""
        message = await self.client.messages.create(
            model=model or self.default_model,
            max_tokens=max_tokens,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        )
        return message.content[0].text if message.content else ""

    async def generate_stream(
        self,
        system_prompt: str,
        user_message: str,
        model: Optional[str] = None,
        max_tokens: int = 1024,
    ) -> AsyncIterator[str]:
        """Stream a response using Anthropic API."""
        async with self.client.messages.stream(
            model=model or self.default_model,
            max_tokens=max_tokens,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        ) as stream:
            async for text in stream.text_stream:
                yield text
