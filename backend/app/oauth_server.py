"""
AgentsCouncil Backend - OAuth server helpers.
"""

from __future__ import annotations

import base64
import hashlib
import os
import secrets
from pathlib import Path
from urllib.parse import urlencode

import httpx
from fastapi import Request

from app.oauth_accounts import OAuthAccountStore

ANTIGRAVITY_CLIENT_ID = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
ANTIGRAVITY_CLIENT_SECRET = "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"
ANTIGRAVITY_SCOPES = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/userinfo.profile",
    "https://www.googleapis.com/auth/cclog",
    "https://www.googleapis.com/auth/experimentsandconfigs",
]
ANTIGRAVITY_SCOPE = " ".join(ANTIGRAVITY_SCOPES)


def _code_challenge(verifier: str) -> str:
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    encoded = base64.urlsafe_b64encode(digest).rstrip(b"=")
    return encoded.decode("ascii")


class OAuthServer:
    def __init__(
        self,
        client_id: str,
        client_secret: str,
        redirect_uri: str,
        account_store: OAuthAccountStore,
        auth_url: str | None = None,
        token_url: str | None = None,
        userinfo_url: str | None = None,
        scope: str | None = None,
        session_store: dict[str, str] | None = None,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self.client_id = client_id
        self.client_secret = client_secret
        self.redirect_uri = redirect_uri
        self.auth_url = auth_url or "https://accounts.google.com/o/oauth2/v2/auth"
        self.token_url = token_url or "https://oauth2.googleapis.com/token"
        self.userinfo_url = userinfo_url or "https://www.googleapis.com/oauth2/v3/userinfo"
        self.scope = scope or "openid email profile"
        self.account_store = account_store
        self._session_store = session_store or {}
        self._http_client = http_client or httpx.AsyncClient(timeout=30.0)

    def get_login_url(self) -> str:
        code_verifier = secrets.token_urlsafe(64)
        state = secrets.token_urlsafe(16)
        self._session_store[state] = code_verifier
        params = {
            "client_id": self.client_id,
            "redirect_uri": self.redirect_uri,
            "response_type": "code",
            "scope": self.scope,
            "code_challenge": _code_challenge(code_verifier),
            "code_challenge_method": "S256",
            "access_type": "offline",
            "prompt": "consent",
            "state": state,
        }
        return f"{self.auth_url}?{urlencode(params)}"

    async def handle_callback(self, code: str, state: str) -> dict:
        code_verifier = self._session_store.pop(state, None)
        if not code_verifier:
            raise ValueError("Invalid OAuth state.")
        token_data = await self._exchange_code(code, code_verifier)
        access_token = token_data.get("access_token")
        refresh_token = token_data.get("refresh_token", "")
        profile = await self._fetch_user_profile(access_token)
        account = {
            "email": profile.get("email", ""),
            "refresh_token": refresh_token,
            "project_id": token_data.get("project_id"),
        }
        self._store_account(account)
        return account

    async def close(self) -> None:
        await self._http_client.aclose()

    async def refresh_access_token(self, refresh_token: str) -> str:
        """Exchange refresh token for a new access token."""
        response = await self._http_client.post(
            self.token_url,
            data={
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "refresh_token": refresh_token,
                "grant_type": "refresh_token",
            },
        )
        response.raise_for_status()
        data = response.json()
        return data["access_token"]

    async def get_valid_access_token(self, email: str | None = None) -> str:
        """Get a valid access token, refreshing if necessary."""
        accounts = self.account_store.load_accounts()
        if not accounts:
            raise ValueError("No OAuth accounts configured")

        # Use first account or find by email
        account = accounts[0]
        if email:
            account = next((a for a in accounts if a.get("email") == email), accounts[0])

        refresh_token = account.get("refresh_token")
        if not refresh_token:
            raise ValueError("No refresh token available")

        return await self.refresh_access_token(refresh_token)

    async def _exchange_code(self, code: str, code_verifier: str) -> dict:
        response = await self._http_client.post(
            self.token_url,
            data={
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "code": code,
                "code_verifier": code_verifier,
                "redirect_uri": self.redirect_uri,
                "grant_type": "authorization_code",
            },
        )
        response.raise_for_status()
        return response.json()

    async def _fetch_user_profile(self, access_token: str | None) -> dict:
        if not access_token:
            return {}
        response = await self._http_client.get(
            self.userinfo_url,
            headers={"Authorization": f"Bearer {access_token}"},
        )
        response.raise_for_status()
        return response.json()

    def _store_account(self, account: dict) -> None:
        accounts = self.account_store.load_accounts()
        accounts.append(account)
        self.account_store.save_accounts(accounts)


def create_oauth_server() -> OAuthServer:
    client_id = os.getenv("GOOGLE_OAUTH_CLIENT_ID", ANTIGRAVITY_CLIENT_ID)
    client_secret = os.getenv("GOOGLE_OAUTH_CLIENT_SECRET", ANTIGRAVITY_CLIENT_SECRET)
    redirect_uri = os.getenv(
        "GOOGLE_OAUTH_REDIRECT_URI",
        "http://localhost:8000/api/providers/google-oauth/callback",
    )
    scope = os.getenv("GOOGLE_OAUTH_SCOPE", ANTIGRAVITY_SCOPE)
    accounts_path = Path(os.getenv("GOOGLE_OAUTH_ACCOUNTS_PATH", "data/oauth_accounts.json"))
    store = OAuthAccountStore(accounts_path)
    return OAuthServer(
        client_id=client_id,
        client_secret=client_secret,
        redirect_uri=redirect_uri,
        scope=scope,
        account_store=store,
    )


def get_oauth_server(request: Request) -> OAuthServer:
    return request.app.state.oauth_server
