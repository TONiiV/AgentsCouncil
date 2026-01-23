from app.oauth_accounts import OAuthAccountStore


def test_store_roundtrip(tmp_path):
    store = OAuthAccountStore(tmp_path / "accounts.json")
    store.save_accounts([
        {"email": "a@b.com", "refresh_token": "r", "project_id": "p"}
    ])
    loaded = store.load_accounts()
    assert loaded[0]["email"] == "a@b.com"


def test_has_accounts_true_when_data_exists(tmp_path):
    store = OAuthAccountStore(tmp_path / "accounts.json")
    store.save_accounts([
        {"email": "a@b.com", "refresh_token": "r", "project_id": "p"}
    ])

    assert store.has_accounts() is True


def test_has_accounts_false_when_missing(tmp_path):
    store = OAuthAccountStore(tmp_path / "accounts.json")

    assert store.has_accounts() is False


def test_load_accounts_returns_empty_on_invalid_json(tmp_path, caplog):
    path = tmp_path / "accounts.json"
    path.write_text("{invalid", encoding="utf-8")
    store = OAuthAccountStore(path)

    with caplog.at_level("WARNING"):
        accounts = store.load_accounts()

    assert accounts == []
    assert "invalid" in caplog.text.lower()


def test_load_accounts_returns_empty_on_non_list_data(tmp_path, caplog):
    path = tmp_path / "accounts.json"
    path.write_text("{\"email\": \"a@b.com\"}", encoding="utf-8")
    store = OAuthAccountStore(path)

    with caplog.at_level("WARNING"):
        accounts = store.load_accounts()

    assert accounts == []
    assert "list" in caplog.text.lower()
