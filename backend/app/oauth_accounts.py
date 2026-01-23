from __future__ import annotations

import json
from pathlib import Path


class OAuthAccountStore:
    def __init__(self, path: Path) -> None:
        self._path = path

    def load_accounts(self) -> list[dict]:
        if not self._path.exists():
            return []
        with self._path.open("r", encoding="utf-8") as handle:
            return json.load(handle)

    def save_accounts(self, accounts: list[dict]) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        with self._path.open("w", encoding="utf-8") as handle:
            json.dump(accounts, handle)

    def has_accounts(self) -> bool:
        return bool(self.load_accounts())
