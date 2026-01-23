"""
AgentsCouncil Backend - Provider Registry
"""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, Optional

from app.config import get_settings
from app.models import ProviderType
from app.oauth_accounts import OAuthAccountStore
from app.providers.anthropic_provider import AnthropicProvider
from app.providers.base import BaseProvider
from app.providers.gemini_provider import GeminiProvider
from app.providers.google_oauth_provider import GoogleOAuthProvider
from app.providers.ollama_provider import OllamaProvider
from app.providers.openai_provider import OpenAIProvider

if TYPE_CHECKING:
    from app.oauth_server import OAuthServer

# Global reference to OAuth server instance for token refresh
_oauth_server_instance: OAuthServer | None = None


def get_oauth_server_instance() -> OAuthServer | None:
    """Get the global OAuth server instance."""
    return _oauth_server_instance


def set_oauth_server_instance(server: OAuthServer) -> None:
    """Set the global OAuth server instance."""
    global _oauth_server_instance
    _oauth_server_instance = server


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

        # Enable Google OAuth provider if stored accounts exist
        oauth_store = OAuthAccountStore(Path.home() / ".agentscouncil" / "oauth_accounts.json")
        if oauth_store.has_accounts():

            async def _token_getter() -> str:
                """Get a valid OAuth access token for Google API calls."""
                server = get_oauth_server_instance()
                if server is None:
                    raise RuntimeError("OAuth server not initialized")
                return await server.get_valid_access_token()

            cls._providers[ProviderType.GOOGLE_OAUTH] = GoogleOAuthProvider(
                token_getter=_token_getter
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
