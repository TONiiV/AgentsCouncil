"""
AgentsCouncil Backend - AI Provider Abstraction Layer
"""

from abc import ABC, abstractmethod
from collections.abc import AsyncIterator

from app.models import ROLE_PROMPTS, AgentConfig, RoleType


class BaseProvider(ABC):
    """Abstract base class for AI providers."""

    def __init__(self, api_key: str):
        self.api_key = api_key

    @property
    @abstractmethod
    def name(self) -> str:
        """Provider name identifier."""
        pass

    @property
    @abstractmethod
    def default_model(self) -> str:
        """Default model to use."""
        pass

    @abstractmethod
    async def generate(
        self,
        system_prompt: str,
        user_message: str,
        model: str | None = None,
        max_tokens: int = 1024,
    ) -> str:
        """Generate a response from the AI model."""
        pass

    @abstractmethod
    async def generate_stream(
        self,
        system_prompt: str,
        user_message: str,
        model: str | None = None,
        max_tokens: int = 1024,
    ) -> AsyncIterator[str]:
        """Stream a response from the AI model."""
        pass

    @abstractmethod
    async def list_models(self) -> list[str]:
        """List available models for this provider."""
        pass

    def get_system_prompt(self, agent: AgentConfig) -> str:
        """Get the system prompt for an agent based on their role."""
        if agent.role == RoleType.CUSTOM and agent.custom_prompt:
            return agent.custom_prompt
        return ROLE_PROMPTS.get(agent.role, "You are a helpful AI assistant.")
