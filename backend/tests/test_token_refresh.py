"""
Tests for OAuth token refresh functionality.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

pytestmark = pytest.mark.asyncio


async def test_refresh_access_token():
    """Should exchange refresh token for new access token."""
    from app.oauth_server import OAuthServer
    from app.oauth_accounts import OAuthAccountStore

    mock_store = MagicMock(spec=OAuthAccountStore)
    mock_store.load_accounts.return_value = [
        {"email": "test@gmail.com", "refresh_token": "valid_refresh"}
    ]

    server = OAuthServer(
        client_id="test_id",
        client_secret="test_secret",
        redirect_uri="http://localhost/callback",
        account_store=mock_store,
    )

    # Mock the HTTP client's post method
    mock_response = MagicMock()
    mock_response.json.return_value = {
        "access_token": "new_access_token",
        "expires_in": 3600,
    }
    mock_response.raise_for_status = MagicMock()

    with patch.object(server, "_http_client") as mock_client:
        mock_client.post = AsyncMock(return_value=mock_response)

        token = await server.refresh_access_token("valid_refresh")
        assert token == "new_access_token"

        # Verify the correct endpoint was called
        mock_client.post.assert_called_once()
        call_kwargs = mock_client.post.call_args
        assert "refresh_token" in str(call_kwargs)


async def test_get_valid_access_token():
    """Should get a valid access token by refreshing from stored account."""
    from app.oauth_server import OAuthServer
    from app.oauth_accounts import OAuthAccountStore

    mock_store = MagicMock(spec=OAuthAccountStore)
    mock_store.load_accounts.return_value = [
        {"email": "test@gmail.com", "refresh_token": "stored_refresh"}
    ]

    server = OAuthServer(
        client_id="test_id",
        client_secret="test_secret",
        redirect_uri="http://localhost/callback",
        account_store=mock_store,
    )

    # Mock refresh_access_token
    with patch.object(server, "refresh_access_token", new_callable=AsyncMock) as mock_refresh:
        mock_refresh.return_value = "fresh_access_token"

        token = await server.get_valid_access_token()
        assert token == "fresh_access_token"
        mock_refresh.assert_called_once_with("stored_refresh")


async def test_get_valid_access_token_by_email():
    """Should get access token for a specific email."""
    from app.oauth_server import OAuthServer
    from app.oauth_accounts import OAuthAccountStore

    mock_store = MagicMock(spec=OAuthAccountStore)
    mock_store.load_accounts.return_value = [
        {"email": "first@gmail.com", "refresh_token": "first_refresh"},
        {"email": "second@gmail.com", "refresh_token": "second_refresh"},
    ]

    server = OAuthServer(
        client_id="test_id",
        client_secret="test_secret",
        redirect_uri="http://localhost/callback",
        account_store=mock_store,
    )

    with patch.object(server, "refresh_access_token", new_callable=AsyncMock) as mock_refresh:
        mock_refresh.return_value = "second_token"

        token = await server.get_valid_access_token(email="second@gmail.com")
        assert token == "second_token"
        mock_refresh.assert_called_once_with("second_refresh")


async def test_get_valid_access_token_no_accounts():
    """Should raise error when no OAuth accounts are configured."""
    from app.oauth_server import OAuthServer
    from app.oauth_accounts import OAuthAccountStore

    mock_store = MagicMock(spec=OAuthAccountStore)
    mock_store.load_accounts.return_value = []

    server = OAuthServer(
        client_id="test_id",
        client_secret="test_secret",
        redirect_uri="http://localhost/callback",
        account_store=mock_store,
    )

    with pytest.raises(ValueError, match="No OAuth accounts configured"):
        await server.get_valid_access_token()


async def test_get_valid_access_token_no_refresh_token():
    """Should raise error when account has no refresh token."""
    from app.oauth_server import OAuthServer
    from app.oauth_accounts import OAuthAccountStore

    mock_store = MagicMock(spec=OAuthAccountStore)
    mock_store.load_accounts.return_value = [
        {"email": "test@gmail.com"}  # No refresh_token
    ]

    server = OAuthServer(
        client_id="test_id",
        client_secret="test_secret",
        redirect_uri="http://localhost/callback",
        account_store=mock_store,
    )

    with pytest.raises(ValueError, match="No refresh token available"):
        await server.get_valid_access_token()
