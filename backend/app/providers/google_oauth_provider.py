"""
AgentsCouncil Backend - Google OAuth Provider
"""

import json
from collections.abc import AsyncIterator, Awaitable, Callable

import httpx

from app.providers.base import BaseProvider


class GoogleOAuthProvider(BaseProvider):
    """Google OAuth provider implementation."""

    def __init__(
        self,
        token_getter: Callable[[], Awaitable[str]],
        base_url: str | None = None,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        super().__init__(api_key="")
        self.token_getter = token_getter
        self.base_url = (base_url or "https://generativelanguage.googleapis.com/v1beta").rstrip(
            "/"
        )
        self.client = client or httpx.AsyncClient(base_url=self.base_url, timeout=120.0)

    @property
    def name(self) -> str:
        return "google_oauth"

    @property
    def default_model(self) -> str:
        return "gemini-2.5-flash"

    async def generate(
        self,
        system_prompt: str,
        user_message: str,
        model: str | None = None,
        max_tokens: int = 1024,
    ) -> str:
        token = await self.token_getter()
        payload = self._build_payload(system_prompt, user_message, max_tokens)
        response = await self._post(
            f"/models/{model or self.default_model}:generateContent",
            token,
            payload,
        )
        return response.get("content", "")

    async def generate_stream(
        self,
        system_prompt: str,
        user_message: str,
        model: str | None = None,
        max_tokens: int = 1024,
    ) -> AsyncIterator[str]:
        token = await self.token_getter()
        payload = self._build_payload(system_prompt, user_message, max_tokens)
        async for chunk in self._stream(
            f"/models/{model or self.default_model}:streamGenerateContent",
            token,
            payload,
        ):
            yield chunk

    async def list_models(self) -> list[str]:
        return [
            "gemini-2.5-flash",
            "gemini-2.0-flash",
            "gemini-1.5-pro",
            "gemini-1.5-flash",
        ]

    def _build_payload(
        self,
        system_prompt: str,
        user_message: str,
        max_tokens: int,
    ) -> dict:
        return {
            "systemInstruction": {"parts": [{"text": system_prompt}]},
            "contents": [{"role": "user", "parts": [{"text": user_message}]}],
            "generationConfig": {"maxOutputTokens": max_tokens},
        }

    async def _post(self, path: str, token: str, payload: dict) -> dict:
        response = await self.client.post(
            path,
            json=payload,
            headers={"Authorization": f"Bearer {token}"},
        )
        response.raise_for_status()
        data = response.json()
        return {"content": self._extract_text(data)}

    async def _stream(self, path: str, token: str, payload: dict) -> AsyncIterator[str]:
        async with self.client.stream(
            "POST",
            path,
            json=payload,
            headers={"Authorization": f"Bearer {token}"},
        ) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if not line:
                    continue
                if line.startswith("data:"):
                    line = line.removeprefix("data:").strip()
                if line == "[DONE]":
                    break
                try:
                    chunk = json.loads(line)
                except json.JSONDecodeError:
                    continue
                text = self._extract_text(chunk)
                if text:
                    yield text

    def _extract_text(self, payload: dict) -> str:
        candidates = payload.get("candidates", [])
        if not candidates:
            return ""
        content = candidates[0].get("content", {})
        parts = content.get("parts", [])
        if not parts:
            return ""
        return parts[0].get("text", "")
