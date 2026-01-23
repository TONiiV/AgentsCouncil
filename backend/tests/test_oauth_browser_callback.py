"""
Tests for OAuth browser callback flow.
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


async def test_callback_returns_html_for_browser(client, tmp_path):
    """Callback should return HTML that posts message to opener."""
    store = OAuthAccountStore(tmp_path / "accounts.json")
    server = OAuthServer(
        client_id="client",
        client_secret="secret",
        redirect_uri="http://localhost/api/providers/google-oauth/callback",
        account_store=store,
    )
    server._exchange_code = AsyncMock(
        return_value={
            "access_token": "access",
            "refresh_token": "refresh",
            "project_id": "project",
        }
    )
    server._fetch_user_profile = AsyncMock(return_value={"email": "test@gmail.com"})
    previous = _set_oauth_server(server)

    try:
        # First get a valid state from login
        login_response = await client.get("/api/providers/google-oauth/login")
        login_url = login_response.json()["url"]
        query = parse_qs(urlparse(login_url).query)
        state = query["state"][0]

        response = await client.get(
            "/api/providers/google-oauth/callback",
            params={"code": "auth_code", "state": state},
            headers={"Accept": "text/html"},
        )
    finally:
        if previous is None:
            delattr(app.state, "oauth_server")
        else:
            app.state.oauth_server = previous

    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "window.opener.postMessage" in response.text
    assert "window.close()" in response.text


async def test_callback_returns_json_for_api(client, tmp_path):
    """Callback should return JSON for API requests (backward compatible)."""
    store = OAuthAccountStore(tmp_path / "accounts.json")
    server = OAuthServer(
        client_id="client",
        client_secret="secret",
        redirect_uri="http://localhost/api/providers/google-oauth/callback",
        account_store=store,
    )
    server._exchange_code = AsyncMock(
        return_value={
            "access_token": "access",
            "refresh_token": "refresh",
            "project_id": "project",
        }
    )
    server._fetch_user_profile = AsyncMock(return_value={"email": "test@gmail.com"})
    previous = _set_oauth_server(server)

    try:
        # First get a valid state from login
        login_response = await client.get("/api/providers/google-oauth/login")
        login_url = login_response.json()["url"]
        query = parse_qs(urlparse(login_url).query)
        state = query["state"][0]

        response = await client.get(
            "/api/providers/google-oauth/callback",
            params={"code": "auth_code", "state": state},
            headers={"Accept": "application/json"},
        )
    finally:
        if previous is None:
            delattr(app.state, "oauth_server")
        else:
            app.state.oauth_server = previous

    assert response.status_code == 200
    assert "application/json" in response.headers["content-type"]
    data = response.json()
    assert data["status"] == "stored"


async def test_callback_html_shows_error(client, tmp_path):
    """Callback HTML should display error message when OAuth fails."""
    store = OAuthAccountStore(tmp_path / "accounts.json")
    server = OAuthServer(
        client_id="client",
        client_secret="secret",
        redirect_uri="http://localhost/api/providers/google-oauth/callback",
        account_store=store,
    )
    previous = _set_oauth_server(server)

    try:
        # Use an invalid state directly (no login first)
        response = await client.get(
            "/api/providers/google-oauth/callback",
            params={"code": "auth_code", "state": "invalid_state"},
            headers={"Accept": "text/html"},
        )
    finally:
        if previous is None:
            delattr(app.state, "oauth_server")
        else:
            app.state.oauth_server = previous

    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "Authentication Failed" in response.text or "error" in response.text.lower()
