"""
AgentsCouncil Backend - Ollama Provider
"""

import json
import logging
from collections.abc import AsyncIterator

import httpx

from app.providers.base import BaseProvider

logger = logging.getLogger(__name__)


class OllamaProvider(BaseProvider):
    """Provider for Ollama running locally or remotely."""

    def __init__(self, base_url: str, api_key: str | None = None):
        super().__init__(api_key=api_key or "")
        self.base_url = base_url.rstrip("/")
        self.client = httpx.AsyncClient(
            base_url=self.base_url,
            timeout=120.0,
            headers={"Authorization": f"Bearer {api_key}"} if api_key else {},
        )

    @property
    def name(self) -> str:
        return "ollama"

    @property
    def default_model(self) -> str:
        return "qwen3:8b"

    async def generate(
        self,
        system_prompt: str,
        user_message: str,
        model: str | None = None,
        max_tokens: int = 1024,
    ) -> str:
        """Generate a response from the Ollama model."""
        model = model or self.default_model

        # Check if the model is available first?
        # For now, just try to generate.

        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message},
            ],
            "stream": False,
            "options": {
                "num_predict": max_tokens,
            },
        }

        try:
            response = await self.client.post("/chat", json=payload)
            if response.status_code != 200:
                error_text = response.text
                logger.error(f"Ollama API error: {response.status_code} - {error_text}")
                response.raise_for_status()
            data = response.json()
            return data.get("message", {}).get("content", "")
        except httpx.HTTPError as e:
            logger.error(f"Ollama generation error: {e}")
            raise

    async def generate_stream(
        self,
        system_prompt: str,
        user_message: str,
        model: str | None = None,
        max_tokens: int = 1024,
    ) -> AsyncIterator[str]:
        """Stream a response from the Ollama model."""
        model = model or self.default_model

        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message},
            ],
            "stream": True,
            "options": {
                "num_predict": max_tokens,
            },
        }

        try:
            async with self.client.stream("POST", "/chat", json=payload) as response:
                if response.status_code != 200:
                    error_text = await response.aread()
                    logger.error(
                        f"Ollama API stream error: {response.status_code} - {error_text.decode('utf-8', errors='replace')}"
                    )
                    response.raise_for_status()

                async for line in response.aiter_lines():
                    if not line:
                        continue
                    try:
                        chunk = json.loads(line)
                        if "message" in chunk and "content" in chunk["message"]:
                            yield chunk["message"]["content"]
                        if chunk.get("done", False):
                            break
                    except json.JSONDecodeError:
                        continue
        except httpx.HTTPError as e:
            logger.error(f"Ollama streaming error: {e}")
            raise

    async def list_models(self) -> list[str]:
        """List available models from Ollama, including cloud models."""
        # Popular cloud models (always available via Ollama cloud)
        cloud_models = [
            "minimax-m2:cloud",
            "deepseek-v3.1:671b-cloud",
            "qwen3:8b",
            "qwen3-coder:480b-cloud",
            "qwen3-vl:235b-cloud",
            "gpt-oss:120b-cloud",
            "gpt-oss:20b-cloud",
            "glm-4.6:cloud",
        ]

        try:
            response = await self.client.get("/tags")
            response.raise_for_status()
            data = response.json()
            local_models = [model["name"] for model in data.get("models", [])]
            # Combine local and cloud models, removing duplicates
            all_models = list(dict.fromkeys(local_models + cloud_models))
            return all_models
        except httpx.HTTPError as e:
            logger.error(f"Failed to list Ollama models: {e}")
            return cloud_models  # Return cloud models as fallback
