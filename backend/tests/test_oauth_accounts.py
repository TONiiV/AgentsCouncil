from app.oauth_accounts import OAuthAccountStore


def test_store_roundtrip(tmp_path):
    store = OAuthAccountStore(tmp_path / "accounts.json")
    store.save_accounts([
        {"email": "a@b.com", "refresh_token": "r", "project_id": "p"}
    ])
    loaded = store.load_accounts()
    assert loaded[0]["email"] == "a@b.com"
