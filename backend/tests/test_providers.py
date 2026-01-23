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
            mock_client.aio = MagicMock()

            mock_response = MagicMock()
            mock_response.text = "Test response from Gemini"
            mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

            provider = GeminiProvider("test-key")
            result = await provider.generate(
                system_prompt="You are a test assistant.",
                user_message="Hello!",
            )

            assert result == "Test response from Gemini"

    @pytest.mark.asyncio
    async def test_generate_with_tools(self):
        """Test Gemini generate_with_tools method."""
        with patch("app.providers.gemini_provider.genai.Client") as mock_client_class:
            mock_client = MagicMock()
            mock_client_class.return_value = mock_client
            mock_client.aio = MagicMock()

            mock_fc = MagicMock()
            mock_fc.name = "get_stock_quote"
            mock_fc.args = {"symbol": "AAPL"}

            mock_part = MagicMock()
            mock_part.function_call = mock_fc

            mock_candidate = MagicMock()
            mock_candidate.content.parts = [mock_part]

            mock_response_1 = MagicMock()
            mock_response_1.candidates = [mock_candidate]
            mock_response_1.text = None

            # 2. Second call returns final text
            mock_candidate_2 = MagicMock()
            mock_candidate_2.content.parts = []
            mock_response_2 = MagicMock()
            mock_response_2.candidates = [mock_candidate_2]
            mock_response_2.text = "Apple is doing well."

            mock_client.aio.models.generate_content = AsyncMock(
                side_effect=[mock_response_1, mock_response_2]
            )

            with patch(
                "app.tools.registry.ToolRegistry.execute_tool", new_callable=AsyncMock
            ) as mock_execute:
                mock_execute.return_value = {"price": 150}

                provider = GeminiProvider("test-key")
                text, calls = await provider.generate_with_tools(
                    system_prompt="Test", user_message="How is AAPL?", tools=[MagicMock()]
                )

                assert text == "Apple is doing well."
                assert len(calls) == 1
                assert calls[0]["name"] == "get_stock_quote"
                assert calls[0]["result"] == {"price": 150}

    @pytest.mark.asyncio
    async def test_generate_with_tools_no_function_calls(self):
        """Test generate_with_tools when model doesn't call any functions."""
        with patch("app.providers.gemini_provider.genai.Client") as mock_client_class:
            mock_client = MagicMock()
            mock_client_class.return_value = mock_client
            mock_client.aio = MagicMock()

            # Mock response with no function calls
            mock_candidate = MagicMock()
            mock_candidate.content.parts = []

            mock_response = MagicMock()
            mock_response.candidates = [mock_candidate]
            mock_response.text = "Direct answer without tools."

            mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

            provider = GeminiProvider("test-key")
            text, calls = await provider.generate_with_tools(
                system_prompt="Test", user_message="Hello!", tools=[MagicMock()]
            )

            assert text == "Direct answer without tools."
            assert len(calls) == 0

    @pytest.mark.asyncio
    async def test_generate_with_tools_multiple_calls(self):
        """Test generate_with_tools with multiple sequential tool calls."""
        with patch("app.providers.gemini_provider.genai.Client") as mock_client_class:
            mock_client = MagicMock()
            mock_client_class.return_value = mock_client
            mock_client.aio = MagicMock()

            # First response: function call for stock quote
            mock_fc_1 = MagicMock()
            mock_fc_1.name = "get_stock_quote"
            mock_fc_1.args = {"symbol": "AAPL"}

            mock_part_1 = MagicMock()
            mock_part_1.function_call = mock_fc_1

            mock_candidate_1 = MagicMock()
            mock_candidate_1.content.parts = [mock_part_1]

            mock_response_1 = MagicMock()
            mock_response_1.candidates = [mock_candidate_1]
            mock_response_1.text = None

            # Second response: function call for news
            mock_fc_2 = MagicMock()
            mock_fc_2.name = "get_stock_news"
            mock_fc_2.args = {"symbol": "AAPL"}

            mock_part_2 = MagicMock()
            mock_part_2.function_call = mock_fc_2

            mock_candidate_2 = MagicMock()
            mock_candidate_2.content.parts = [mock_part_2]

            mock_response_2 = MagicMock()
            mock_response_2.candidates = [mock_candidate_2]
            mock_response_2.text = None

            # Third response: final answer
            mock_candidate_3 = MagicMock()
            mock_candidate_3.content.parts = []

            mock_response_3 = MagicMock()
            mock_response_3.candidates = [mock_candidate_3]
            mock_response_3.text = "Analysis complete."

            mock_client.aio.models.generate_content = AsyncMock(
                side_effect=[mock_response_1, mock_response_2, mock_response_3]
            )

            with patch(
                "app.tools.registry.ToolRegistry.execute_tool", new_callable=AsyncMock
            ) as mock_execute:
                mock_execute.return_value = {"result": "ok"}

                provider = GeminiProvider("test-key")
                text, calls = await provider.generate_with_tools(
                    system_prompt="Test", user_message="Analyze AAPL", tools=[MagicMock()]
                )

                assert text == "Analysis complete."
                assert len(calls) == 2
                assert calls[0]["name"] == "get_stock_quote"
                assert calls[1]["name"] == "get_stock_news"

    @pytest.mark.asyncio
    async def test_generate_with_tools_tool_error(self):
        """Test generate_with_tools when tool execution fails - tool call should still be recorded."""
        with patch("app.providers.gemini_provider.genai.Client") as mock_client_class:
            mock_client = MagicMock()
            mock_client_class.return_value = mock_client
            mock_client.aio = MagicMock()

            # First response: function call
            mock_fc = MagicMock()
            mock_fc.name = "get_stock_quote"
            mock_fc.args = {"symbol": "INVALID"}

            mock_part = MagicMock()
            mock_part.function_call = mock_fc

            mock_candidate = MagicMock()
            mock_candidate.content.parts = [mock_part]

            mock_response = MagicMock()
            mock_response.candidates = [mock_candidate]
            mock_response.text = None

            # Second response: after tool error, model responds with text
            mock_candidate_2 = MagicMock()
            mock_candidate_2.content.parts = []

            mock_response_2 = MagicMock()
            mock_response_2.candidates = [mock_candidate_2]
            mock_response_2.text = "Could not fetch stock data."

            mock_client.aio.models.generate_content = AsyncMock(
                side_effect=[mock_response, mock_response_2]
            )

            with patch(
                "app.tools.registry.ToolRegistry.execute_tool", new_callable=AsyncMock
            ) as mock_execute:
                mock_execute.side_effect = Exception("API error: Invalid symbol")

                provider = GeminiProvider("test-key")
                text, calls = await provider.generate_with_tools(
                    system_prompt="Test", user_message="Check INVALID stock", tools=[MagicMock()]
                )

                # Even on error, the tool call should be recorded
                assert len(calls) == 1
                assert calls[0]["name"] == "get_stock_quote"
                assert "error" in calls[0]["result"].lower() or "API error" in calls[0]["result"]

    @pytest.mark.asyncio
    async def test_generate_with_tools_max_iterations(self):
        """Test generate_with_tools with max tool iterations reached."""
        with patch("app.providers.gemini_provider.genai.Client") as mock_client_class:
            mock_client = MagicMock()
            mock_client_class.return_value = mock_client
            mock_client.aio = MagicMock()

            # All responses have function calls (will hit max iterations = 5)
            mock_fc = MagicMock()
            mock_fc.name = "get_stock_quote"
            mock_fc.args = {"symbol": "AAPL"}

            mock_part = MagicMock()
            mock_part.function_call = mock_fc

            mock_candidate = MagicMock()
            mock_candidate.content.parts = [mock_part]

            mock_response = MagicMock()
            mock_response.candidates = [mock_candidate]
            mock_response.text = None

            # Return the same response 6 times (more than max iterations)
            mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

            with patch(
                "app.tools.registry.ToolRegistry.execute_tool", new_callable=AsyncMock
            ) as mock_execute:
                mock_execute.return_value = {"price": 150}

                provider = GeminiProvider("test-key")
                text, calls = await provider.generate_with_tools(
                    system_prompt="Test",
                    user_message="Analyze AAPL",
                    tools=[MagicMock()],
                    max_tokens=1000,
                )

                # Should have made 5 tool calls (max iterations)
                assert len(calls) == 5
                for call in calls:
                    assert call["name"] == "get_stock_quote"

    @pytest.mark.asyncio
    async def test_generate_with_tools_empty_response(self):
        """Test generate_with_tools with empty candidate response."""
        with patch("app.providers.gemini_provider.genai.Client") as mock_client_class:
            mock_client = MagicMock()
            mock_client_class.return_value = mock_client
            mock_client.aio = MagicMock()

            # Response with no candidates
            mock_response = MagicMock()
            mock_response.candidates = []
            mock_response.text = ""

            mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

            provider = GeminiProvider("test-key")
            text, calls = await provider.generate_with_tools(
                system_prompt="Test", user_message="Hello!", tools=[MagicMock()]
            )

            assert text == ""

    @pytest.mark.asyncio
    async def test_generate_with_tools_model_override(self):
        """Test generate_with_tools with custom model override."""
        with patch("app.providers.gemini_provider.genai.Client") as mock_client_class:
            mock_client = MagicMock()
            mock_client_class.return_value = mock_client
            mock_client.aio = MagicMock()

            mock_candidate = MagicMock()
            mock_candidate.content.parts = []

            mock_response = MagicMock()
            mock_response.candidates = [mock_candidate]
            mock_response.text = "Response from custom model"

            mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

            provider = GeminiProvider("test-key")
            text, calls = await provider.generate_with_tools(
                system_prompt="Test",
                user_message="Hello!",
                tools=[MagicMock()],
                model="gemini-1.5-pro",
            )

            assert text == "Response from custom model"
            mock_client.aio.models.generate_content.assert_called_once()
            call_kwargs = mock_client.aio.models.generate_content.call_args
            assert call_kwargs.kwargs.get("model") == "gemini-1.5-pro"
