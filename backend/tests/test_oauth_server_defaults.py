from app.oauth_server import (
    ANTIGRAVITY_CLIENT_ID,
    ANTIGRAVITY_CLIENT_SECRET,
    ANTIGRAVITY_SCOPES,
    create_oauth_server,
)


def test_oauth_server_defaults_use_antigravity_settings(monkeypatch):
    monkeypatch.delenv("GOOGLE_OAUTH_CLIENT_ID", raising=False)
    monkeypatch.delenv("GOOGLE_OAUTH_CLIENT_SECRET", raising=False)
    monkeypatch.delenv("GOOGLE_OAUTH_SCOPE", raising=False)

    server = create_oauth_server()

    assert server.client_id == ANTIGRAVITY_CLIENT_ID
    assert server.client_secret == ANTIGRAVITY_CLIENT_SECRET
    assert ANTIGRAVITY_SCOPES[0] in server.scope
