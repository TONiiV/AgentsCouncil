"""
Tests for AI Provider Implementations
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models import ROLE_PROMPTS, AgentConfig, ProviderType, RoleType
from app.providers import ProviderRegistry
from app.providers.anthropic_provider import AnthropicProvider
from app.providers.gemini_provider import GeminiProvider
from app.providers.openai_provider import OpenAIProvider


def test_provider_type_includes_google_oauth():
    assert ProviderType.GOOGLE_OAUTH.value == "google_oauth"


class TestBaseProvider:
    """Tests for BaseProvider abstract class."""

    def test_get_system_prompt_standard_role(self, sample_agent_gemini):
        """Test getting system prompt for a standard role."""
        # Create a concrete instance for testing
        with patch.object(GeminiProvider, "__init__", lambda self, api_key: None):
            provider = GeminiProvider.__new__(GeminiProvider)
            provider.api_key = "test-key"

            prompt = provider.get_system_prompt(sample_agent_gemini)
            assert prompt == ROLE_PROMPTS[RoleType.TECH_STRATEGIST]

    def test_get_system_prompt_custom_role(self):
        """Test getting system prompt for a custom role."""
        custom_agent = AgentConfig(
            name="Custom Agent",
            provider=ProviderType.GEMINI,
            role=RoleType.CUSTOM,
            custom_prompt="You are a specialized custom agent.",
        )

        with patch.object(GeminiProvider, "__init__", lambda self, api_key: None):
            provider = GeminiProvider.__new__(GeminiProvider)
            provider.api_key = "test-key"

            prompt = provider.get_system_prompt(custom_agent)
            assert prompt == "You are a specialized custom agent."

    def test_get_system_prompt_devils_advocate(self, sample_agent_devils_advocate):
        """Test getting system prompt for Devil's Advocate role."""
        with patch.object(GeminiProvider, "__init__", lambda self, api_key: None):
            provider = GeminiProvider.__new__(GeminiProvider)
            provider.api_key = "test-key"

            prompt = provider.get_system_prompt(sample_agent_devils_advocate)
            assert "challenge assumptions" in prompt.lower()


class TestProviderRegistry:
    """Tests for ProviderRegistry."""

    def test_registry_empty_initially(self):
        """Test that registry is empty before initialization."""
        # Clear any existing providers
        ProviderRegistry._providers.clear()
        assert ProviderRegistry.get_available() == []

    def test_is_available_when_not_configured(self):
        """Test is_available returns False for unconfigured providers."""
        ProviderRegistry._providers.clear()
        assert ProviderRegistry.is_available(ProviderType.OPENAI) is False
        assert ProviderRegistry.is_available(ProviderType.ANTHROPIC) is False

    def test_get_returns_none_for_unavailable(self):
        """Test get returns None for unavailable provider."""
        ProviderRegistry._providers.clear()
        assert ProviderRegistry.get(ProviderType.OPENAI) is None

    @patch("app.providers.get_settings")
    def test_initialize_with_openai_key(self, mock_settings):
        """Test initialization with OpenAI API key."""
        mock_settings.return_value = MagicMock(
            openai_api_key="test-openai-key",
            anthropic_api_key=None,
            gemini_api_key=None,
            ollama_base_url="http://localhost:11434",
        )

        ProviderRegistry._providers.clear()
        ProviderRegistry.initialize()

        assert ProviderRegistry.is_available(ProviderType.OPENAI)
        assert not ProviderRegistry.is_available(ProviderType.ANTHROPIC)
        assert not ProviderRegistry.is_available(ProviderType.GEMINI)

    @patch("app.providers.get_settings")
    def test_initialize_with_all_keys(self, mock_settings):
        """Test initialization with all API keys."""
        mock_settings.return_value = MagicMock(
            openai_api_key="test-openai-key",
            anthropic_api_key="test-anthropic-key",
            gemini_api_key="test-gemini-key",
            ollama_base_url="http://localhost:11434",
        )

        ProviderRegistry._providers.clear()
        ProviderRegistry.initialize()

        available = ProviderRegistry.get_available()
        assert ProviderType.OPENAI in available
        assert ProviderType.ANTHROPIC in available
        assert ProviderType.GEMINI in available

    @patch("app.providers.OAuthAccountStore")
    @patch("app.providers.get_settings")
    def test_initialize_with_google_oauth_account(self, mock_settings, mock_store):
        """Test initialization registers Google OAuth provider when accounts exist."""
        mock_settings.return_value = MagicMock(
            openai_api_key=None,
            anthropic_api_key=None,
            gemini_api_key=None,
            ollama_base_url=None,
        )
        mock_store.return_value.has_accounts.return_value = True

        ProviderRegistry._providers.clear()
        ProviderRegistry.initialize()

        assert ProviderRegistry.is_available(ProviderType.GOOGLE_OAUTH)

    @patch("app.providers.OAuthAccountStore")
    @patch("app.providers.get_settings")
    def test_initialize_without_google_oauth_account(self, mock_settings, mock_store):
        """Test initialization does NOT register Google OAuth provider when no accounts exist."""
        mock_settings.return_value = MagicMock(
            openai_api_key=None,
            anthropic_api_key=None,
            gemini_api_key=None,
            ollama_base_url=None,
        )
        mock_store.return_value.has_accounts.return_value = False

        ProviderRegistry._providers.clear()
        ProviderRegistry.initialize()

        assert not ProviderRegistry.is_available(ProviderType.GOOGLE_OAUTH)


class TestOpenAIProvider:
    """Tests for OpenAI provider implementation."""

    def test_provider_properties(self):
        """Test OpenAI provider properties."""
        with patch("app.providers.openai_provider.AsyncOpenAI"):
            provider = OpenAIProvider("test-key")
            assert provider.name == "openai"
            assert provider.default_model == "gpt-4o"

    @pytest.mark.asyncio
    async def test_generate_method(self):
        """Test OpenAI generate method with mocked client."""
        with patch("app.providers.openai_provider.AsyncOpenAI") as mock_client_class:
            mock_client = MagicMock()
            mock_client_class.return_value = mock_client

            # Mock the response
            mock_response = MagicMock()
            mock_response.choices = [MagicMock(message=MagicMock(content="Test response"))]
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

            provider = OpenAIProvider("test-key")
            result = await provider.generate(
                system_prompt="You are a test assistant.",
                user_message="Hello!",
            )

            assert result == "Test response"
            mock_client.chat.completions.create.assert_called_once()


class TestAnthropicProvider:
    """Tests for Anthropic provider implementation."""

    def test_provider_properties(self):
        """Test Anthropic provider properties."""
        with patch("app.providers.anthropic_provider.anthropic.AsyncAnthropic"):
            provider = AnthropicProvider("test-key")
            assert provider.name == "anthropic"
            assert "claude" in provider.default_model.lower()

    @pytest.mark.asyncio
    async def test_generate_method(self):
        """Test Anthropic generate method with mocked client."""
        with patch(
            "app.providers.anthropic_provider.anthropic.AsyncAnthropic"
        ) as mock_client_class:
            mock_client = MagicMock()
            mock_client_class.return_value = mock_client

            # Mock the response
            mock_response = MagicMock()
            mock_response.content = [MagicMock(text="Test response from Claude")]
            mock_client.messages.create = AsyncMock(return_value=mock_response)

            provider = AnthropicProvider("test-key")
            result = await provider.generate(
                system_prompt="You are a test assistant.",
                user_message="Hello!",
            )

            assert result == "Test response from Claude"


class TestGeminiProvider:
    """Tests for Gemini provider implementation."""

    def test_provider_properties(self):
        """Test Gemini provider properties."""
        with patch("app.providers.gemini_provider.genai.Client"):
            provider = GeminiProvider("test-key")
            assert provider.name == "gemini"
            assert "gemini" in provider.default_model.lower()

    @pytest.mark.asyncio
    async def test_generate_method(self):
        """Test Gemini generate method with mocked client."""
        with patch("app.providers.gemini_provider.genai.Client") as mock_client_class:
            mock_client = MagicMock()
            mock_client_class.return_value = mock_client

            mock_model = MagicMock()
            mock_response = MagicMock()
            mock_response.text = "Test response from Gemini"
            mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

            with patch.object(GeminiProvider, "__init__", lambda self, api_key: None):
                provider = GeminiProvider.__new__(GeminiProvider)
                provider.client = mock_client
                provider.api_key = "test-key"

                result = await provider.generate(
                    system_prompt="You are a test assistant.",
                    user_message="Hello!",
                )

                assert result == "Test response from Gemini"
