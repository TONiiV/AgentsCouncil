"""
Tests for Google OAuth provider.
"""

from unittest.mock import ANY, AsyncMock

import pytest

from app.providers.google_oauth_provider import GoogleOAuthProvider


@pytest.mark.asyncio
async def test_generate_uses_access_token():
    token = "token"
    provider = GoogleOAuthProvider(token_getter=AsyncMock(return_value=token))
    provider._post = AsyncMock(return_value={"content": "ok"})
    result = await provider.generate("sys", "msg")
    assert result == "ok"
    provider._post.assert_awaited_once_with(
        f"/models/{provider.default_model}:generateContent",
        token,
        ANY,
    )
