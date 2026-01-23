from unittest.mock import AsyncMock, MagicMock

import pytest

from app.providers.ollama_provider import OllamaProvider


@pytest.fixture
def ollama_provider():
    return OllamaProvider(base_url="http://localhost:11434/api")


@pytest.mark.asyncio
async def test_ollama_generate(ollama_provider):
    mock_client = AsyncMock()
    mock_response = MagicMock()
    mock_response.raise_for_status.return_value = None
    mock_response.json.return_value = {"message": {"content": "Test response"}}
    mock_client.post.return_value = mock_response

    ollama_provider.client = mock_client

    response = await ollama_provider.generate(system_prompt="sys", user_message="user")
    assert response == "Test response"
    mock_client.post.assert_called_once()


@pytest.mark.asyncio
async def test_ollama_generate_stream(ollama_provider):
    mock_client = AsyncMock()

    # Mock the response object
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status.return_value = None
    mock_response.aread = AsyncMock(return_value=b"error text")

    # Mock aiter_lines
    lines = [
        '{"message": {"content": "Hello"}, "done": false}',
        '{"message": {"content": " world"}, "done": true}',
    ]

    async def mock_aiter_lines():
        for line in lines:
            yield line

    mock_response.aiter_lines = mock_aiter_lines

    # Mock the context manager returned by stream()
    mock_ctx = AsyncMock()
    mock_ctx.__aenter__.return_value = mock_response

    # Important: stream() is not async, it returns an async context manager
    # So we replace the auto-created AsyncMock with a MagicMock for the method itself
    mock_client.stream = MagicMock(return_value=mock_ctx)

    ollama_provider.client = mock_client

    chunks = []
    async for chunk in ollama_provider.generate_stream(system_prompt="sys", user_message="user"):
        chunks.append(chunk)

    assert "".join(chunks) == "Hello world"


@pytest.mark.asyncio
async def test_ollama_list_models(ollama_provider):
    mock_client = AsyncMock()
    mock_response = MagicMock()
    mock_response.raise_for_status.return_value = None
    mock_response.json.return_value = {"models": [{"name": "llama3"}, {"name": "mistral"}]}
    mock_client.get.return_value = mock_response

    ollama_provider.client = mock_client

    models = await ollama_provider.list_models()
    assert "llama3" in models
    assert "mistral" in models
