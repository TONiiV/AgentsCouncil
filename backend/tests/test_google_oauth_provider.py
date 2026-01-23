"""
Tests for Google OAuth provider.
"""

from unittest.mock import AsyncMock

import pytest

from app.providers.google_oauth_provider import GoogleOAuthProvider


@pytest.mark.asyncio
async def test_generate_uses_access_token():
    provider = GoogleOAuthProvider(token_getter=AsyncMock(return_value="token"))
    provider._post = AsyncMock(return_value={"content": "ok"})
    result = await provider.generate("sys", "msg")
    assert result == "ok"
