"""
AgentsCouncil Backend - Google Gemini Provider
"""
import asyncio
import logging
from typing import AsyncIterator, Optional

from google import genai
from google.genai import types

from app.providers.base import BaseProvider


logger = logging.getLogger(__name__)


class GeminiProvider(BaseProvider):
    """Google Gemini API provider implementation."""

    # Retry settings for rate limiting (Gemini free tier has strict limits)
    MAX_RETRIES = 5
    BASE_DELAY = 10.0  # seconds - start with 10s for quota limits
    MAX_DELAY = 60.0  # seconds - up to 60s as API suggests

    def __init__(self, api_key: str):
        super().__init__(api_key)
        self.client = genai.Client(api_key=api_key)

    @property
    def name(self) -> str:
        return "gemini"

    @property
    def default_model(self) -> str:
        # Use 1.5-flash as default for stability
        return "gemini-1.5-flash"

    async def _retry_with_backoff(self, operation, *args, **kwargs):
        """Execute operation with exponential backoff retry on rate limits."""
        last_exception = None
        
        for attempt in range(self.MAX_RETRIES):
            try:
                return await operation(*args, **kwargs)
            except Exception as e:
                # Check for rate limit errors in the exception message
                # since specific exception types might vary in the new SDK
                error_str = str(e).lower()
                if "429" in error_str or "resource" in error_str and "exhausted" in error_str:
                    last_exception = e
                    delay = min(self.BASE_DELAY * (2 ** attempt), self.MAX_DELAY)
                    logger.warning(
                        f"Rate limited (429). Attempt {attempt + 1}/{self.MAX_RETRIES}. "
                        f"Retrying in {delay:.1f}s..."
                    )
                    await asyncio.sleep(delay)
                else:
                    # Other errors - don't retry
                    logger.error(f"Gemini API error: {type(e).__name__}: {e}")
                    raise
        
        # All retries exhausted
        logger.error(f"All {self.MAX_RETRIES} retries exhausted due to rate limiting")
        raise last_exception

    async def generate(
        self,
        system_prompt: str,
        user_message: str,
        model: Optional[str] = None,
        max_tokens: int = 1024,
    ) -> str:
        """Generate a response using Gemini API with retry logic."""
        
        async def _do_generate():
            response = await self.client.aio.models.generate_content(
                model=model or self.default_model,
                contents=user_message,
                config=types.GenerateContentConfig(
                    system_instruction=system_prompt,
                    max_output_tokens=max_tokens,
                ),
            )
            return response.text if response.text else ""
        
        return await self._retry_with_backoff(_do_generate)

    async def generate_stream(
        self,
        system_prompt: str,
        user_message: str,
        model: Optional[str] = None,
        max_tokens: int = 1024,
    ) -> AsyncIterator[str]:
        """Stream a response using Gemini API."""
        
        # For streaming, we don't retry - just attempt once
        response_stream = await self.client.aio.models.generate_content_stream(
            model=model or self.default_model,
            contents=user_message,
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                max_output_tokens=max_tokens,
            ),
        )

        async for chunk in response_stream:
            if chunk.text:
                yield chunk.text
