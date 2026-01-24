"""
AgentsCouncil Backend - Authentication Context

Provides JWT verification via Supabase JWKS and guest ID support.
"""

from dataclasses import dataclass
from typing import Annotated

import httpx
import jwt
from fastapi import Depends, Header, HTTPException, status
from jwt import PyJWKClient

from app.config import get_settings


@dataclass
class AuthContext:
    """Authentication context for requests.

    Either owner_id (authenticated user) or guest_id must be set.
    """

    owner_id: str | None = None
    guest_id: str | None = None

    @property
    def user_id(self) -> str:
        """Return the effective user identifier."""
        if self.owner_id:
            return self.owner_id
        if self.guest_id:
            return f"guest:{self.guest_id}"
        raise ValueError("No user identifier available")

    @property
    def is_authenticated(self) -> bool:
        """Return True if user is authenticated (not a guest)."""
        return self.owner_id is not None


# JWKS client cache
_jwks_client: PyJWKClient | None = None


def _get_jwks_client() -> PyJWKClient:
    """Get or create the JWKS client for Supabase."""
    global _jwks_client
    if _jwks_client is None:
        settings = get_settings()
        jwks_url = f"{settings.supabase_url}/auth/v1/.well-known/jwks.json"
        _jwks_client = PyJWKClient(jwks_url)
    return _jwks_client


def _verify_jwt(token: str) -> dict:
    """Verify JWT and return claims.

    Args:
        token: The JWT token string.

    Returns:
        The decoded token claims.

    Raises:
        HTTPException: If verification fails.
    """
    try:
        jwks_client = _get_jwks_client()
        signing_key = jwks_client.get_signing_key_from_jwt(token)

        settings = get_settings()
        # Supabase JWT issuer format
        issuer = f"{settings.supabase_url}/auth/v1"

        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience="authenticated",
            issuer=issuer,
        )
        return claims
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {e}",
        )
    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Unable to verify token: {e}",
        )


async def get_auth_context(
    authorization: Annotated[str | None, Header()] = None,
    x_guest_id: Annotated[str | None, Header()] = None,
) -> AuthContext:
    """FastAPI dependency to extract authentication context.

    Accepts either:
    - Authorization: Bearer <jwt> header (verified via Supabase JWKS)
    - X-Guest-Id header for unauthenticated users

    Args:
        authorization: Authorization header value.
        x_guest_id: Guest ID header value.

    Returns:
        AuthContext with owner_id or guest_id set.

    Raises:
        HTTPException: 401 if neither auth method is provided.
    """
    # Try JWT first
    if authorization and authorization.startswith("Bearer "):
        token = authorization[7:]  # Strip "Bearer "
        claims = _verify_jwt(token)
        return AuthContext(owner_id=claims.get("sub"))

    # Fall back to guest ID
    if x_guest_id:
        return AuthContext(guest_id=x_guest_id)

    # No auth provided
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Authentication required. Provide Authorization header or X-Guest-Id.",
        headers={"WWW-Authenticate": "Bearer"},
    )


# Type alias for dependency injection
AuthContextDep = Annotated[AuthContext, Depends(get_auth_context)]
