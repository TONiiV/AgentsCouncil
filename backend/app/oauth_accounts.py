from __future__ import annotations

import json
import logging
import tempfile
from pathlib import Path


class OAuthAccountStore:
    def __init__(self, path: Path) -> None:
        self._path = path

    def load_accounts(self) -> list[dict]:
        if not self._path.exists():
            return []
        with self._path.open("r", encoding="utf-8") as handle:
            try:
                data = json.load(handle)
            except json.JSONDecodeError:
                logging.getLogger(__name__).warning(
                    "Invalid JSON in oauth accounts file %s",
                    self._path,
                )
                return []
        if not isinstance(data, list):
            logging.getLogger(__name__).warning(
                "OAuth accounts data is not a list in %s",
                self._path,
            )
            return []
        return data

    def save_accounts(self, accounts: list[dict]) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            "w",
            encoding="utf-8",
            dir=self._path.parent,
            delete=False,
        ) as handle:
            json.dump(accounts, handle)
            temp_path = Path(handle.name)
        temp_path.replace(self._path)

    def has_accounts(self) -> bool:
        return bool(self.load_accounts())
