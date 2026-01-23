"""
Tests for OAuth account management endpoints.
"""

from urllib.parse import parse_qs, urlparse
from unittest.mock import AsyncMock

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.oauth_accounts import OAuthAccountStore
from app.oauth_server import OAuthServer

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def client():
    """Create an async test client."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


def _set_oauth_server(server: OAuthServer) -> OAuthServer | None:
    previous = getattr(app.state, "oauth_server", None)
    app.state.oauth_server = server
    return previous


async def test_list_oauth_accounts(client, tmp_path):
    """Should list stored OAuth accounts (without sensitive tokens)."""
    store = OAuthAccountStore(tmp_path / "accounts.json")
    store.save_accounts(
        [
            {"email": "user1@gmail.com", "refresh_token": "secret1", "project_id": "proj1"},
            {"email": "user2@gmail.com", "refresh_token": "secret2", "project_id": "proj2"},
        ]
    )

    server = OAuthServer(
        client_id="client",
        client_secret="secret",
        redirect_uri="http://localhost/api/providers/google-oauth/callback",
        account_store=store,
    )
    previous = _set_oauth_server(server)

    try:
        response = await client.get("/api/providers/google-oauth/accounts")
    finally:
        if previous is None:
            delattr(app.state, "oauth_server")
        else:
            app.state.oauth_server = previous

    assert response.status_code == 200
    data = response.json()
    assert "accounts" in data
    assert len(data["accounts"]) == 2

    # Verify emails are returned
    emails = [acc["email"] for acc in data["accounts"]]
    assert "user1@gmail.com" in emails
    assert "user2@gmail.com" in emails

    # Verify tokens are NOT exposed
    for acc in data["accounts"]:
        assert "refresh_token" not in acc


async def test_list_oauth_accounts_empty(client, tmp_path):
    """Should return empty list when no accounts exist."""
    store = OAuthAccountStore(tmp_path / "accounts.json")

    server = OAuthServer(
        client_id="client",
        client_secret="secret",
        redirect_uri="http://localhost/api/providers/google-oauth/callback",
        account_store=store,
    )
    previous = _set_oauth_server(server)

    try:
        response = await client.get("/api/providers/google-oauth/accounts")
    finally:
        if previous is None:
            delattr(app.state, "oauth_server")
        else:
            app.state.oauth_server = previous

    assert response.status_code == 200
    data = response.json()
    assert data["accounts"] == []


async def test_delete_oauth_account(client, tmp_path):
    """Should delete an OAuth account by email."""
    store = OAuthAccountStore(tmp_path / "accounts.json")
    store.save_accounts(
        [
            {"email": "user1@gmail.com", "refresh_token": "secret1"},
            {"email": "user2@gmail.com", "refresh_token": "secret2"},
        ]
    )

    server = OAuthServer(
        client_id="client",
        client_secret="secret",
        redirect_uri="http://localhost/api/providers/google-oauth/callback",
        account_store=store,
    )
    previous = _set_oauth_server(server)

    try:
        response = await client.delete("/api/providers/google-oauth/accounts/user1@gmail.com")
    finally:
        if previous is None:
            delattr(app.state, "oauth_server")
        else:
            app.state.oauth_server = previous

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "deleted"
    assert data["email"] == "user1@gmail.com"

    # Verify account was actually removed
    remaining = store.load_accounts()
    assert len(remaining) == 1
    assert remaining[0]["email"] == "user2@gmail.com"


async def test_delete_oauth_account_not_found(client, tmp_path):
    """Should return 404 when account doesn't exist."""
    store = OAuthAccountStore(tmp_path / "accounts.json")
    store.save_accounts(
        [
            {"email": "existing@gmail.com", "refresh_token": "secret"},
        ]
    )

    server = OAuthServer(
        client_id="client",
        client_secret="secret",
        redirect_uri="http://localhost/api/providers/google-oauth/callback",
        account_store=store,
    )
    previous = _set_oauth_server(server)

    try:
        response = await client.delete("/api/providers/google-oauth/accounts/nonexistent@gmail.com")
    finally:
        if previous is None:
            delattr(app.state, "oauth_server")
        else:
            app.state.oauth_server = previous

    assert response.status_code == 404
