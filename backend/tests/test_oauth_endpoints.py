"""
Tests for OAuth endpoints.
"""

from urllib.parse import parse_qs, urlparse
from unittest.mock import AsyncMock

from app.main import app
from app.oauth_accounts import OAuthAccountStore
from app.oauth_server import OAuthServer


def _set_oauth_server(server: OAuthServer) -> OAuthServer | None:
    previous = getattr(app.state, "oauth_server", None)
    app.state.oauth_server = server
    return previous


def test_google_oauth_login_returns_url(client, tmp_path):
    store = OAuthAccountStore(tmp_path / "accounts.json")
    server = OAuthServer(
        client_id="client",
        client_secret="secret",
        redirect_uri="http://localhost/api/providers/google-oauth/callback",
        account_store=store,
    )
    previous = _set_oauth_server(server)

    try:
        response = client.get("/api/providers/google-oauth/login")
    finally:
        if previous is None:
            delattr(app.state, "oauth_server")
        else:
            app.state.oauth_server = previous

    assert response.status_code == 200
    data = response.json()
    assert "url" in data
    url = data["url"]
    assert "code_challenge" in url
    assert "code_challenge_method=S256" in url


def test_google_oauth_callback_stores_account(client, tmp_path):
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
    server._fetch_user_profile = AsyncMock(return_value={"email": "user@example.com"})
    previous = _set_oauth_server(server)

    try:
        login_response = client.get("/api/providers/google-oauth/login")
        login_url = login_response.json()["url"]
        query = parse_qs(urlparse(login_url).query)
        state = query["state"][0]
        response = client.get(
            "/api/providers/google-oauth/callback",
            params={"code": "auth-code", "state": state},
        )
    finally:
        if previous is None:
            delattr(app.state, "oauth_server")
        else:
            app.state.oauth_server = previous

    assert response.status_code == 200
    data = response.json()
    assert data["account"]["email"] == "user@example.com"
    accounts = store.load_accounts()
    assert accounts == [
        {
            "email": "user@example.com",
            "refresh_token": "refresh",
            "project_id": "project",
        }
    ]
