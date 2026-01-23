"""
AgentsCouncil Backend - Provider Registry
"""

from typing import Optional

from app.config import get_settings
from app.models import ProviderType
from app.providers.anthropic_provider import AnthropicProvider
from app.providers.base import BaseProvider
from app.providers.gemini_provider import GeminiProvider
from app.providers.ollama_provider import OllamaProvider
from app.providers.openai_provider import OpenAIProvider


class ProviderRegistry:
    """Registry for managing AI provider instances."""

    _providers: dict[ProviderType, BaseProvider] = {}

    @classmethod
    def initialize(cls) -> None:
        """Initialize providers based on available API keys."""
        settings = get_settings()

        if settings.openai_api_key:
            cls._providers[ProviderType.OPENAI] = OpenAIProvider(settings.openai_api_key)

        if settings.anthropic_api_key:
            cls._providers[ProviderType.ANTHROPIC] = AnthropicProvider(settings.anthropic_api_key)

        if settings.gemini_api_key:
            cls._providers[ProviderType.GEMINI] = GeminiProvider(settings.gemini_api_key)

        if settings.ollama_base_url:
            cls._providers[ProviderType.OLLAMA] = OllamaProvider(
                base_url=settings.ollama_base_url,
                api_key=settings.ollama_api_key,
            )

    @classmethod
    def get(cls, provider_type: ProviderType) -> BaseProvider | None:
        """Get a provider instance by type."""
        return cls._providers.get(provider_type)

    @classmethod
    def get_available(cls) -> list[ProviderType]:
        """Get list of available (configured) providers."""
        return list(cls._providers.keys())

    @classmethod
    def is_available(cls, provider_type: ProviderType) -> bool:
        """Check if a provider is available."""
        return provider_type in cls._providers
