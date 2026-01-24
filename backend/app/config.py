"""
AgentsCouncil Backend - Configuration
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False

    # AI Provider API Keys
    openai_api_key: str | None = None
    anthropic_api_key: str | None = None
    gemini_api_key: str | None = None
    ollama_base_url: str = "http://127.0.0.1:11434/api"
    ollama_api_key: str | None = None

    # Database
    database_url: str = "sqlite+aiosqlite:///./agentscouncil.db"
    database_path: str = "data/agentscouncil.db"

    # Supabase
    supabase_url: str | None = None
    supabase_service_role_key: str | None = None
    supabase_jwt_audience: str = "authenticated"
    supabase_database_url: str | None = None  # Direct PostgreSQL connection URL

    # Debate defaults
    default_max_rounds: int = 5
    default_consensus_threshold: float = 0.8  # 80% agreement
    default_response_timeout: int = 60  # seconds

    @property
    def available_providers(self) -> list[str]:
        """Return list of configured AI providers."""
        providers = []
        if self.openai_api_key:
            providers.append("openai")
        if self.anthropic_api_key:
            providers.append("anthropic")
        if self.gemini_api_key:
            providers.append("gemini")
        if self.ollama_base_url:
            providers.append("ollama")
        return providers


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
