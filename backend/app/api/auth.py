"""
AgentsCouncil Backend - Auth API Routes

Provides authentication-related endpoints like claiming guest data.
"""

from typing import Annotated

from fastapi import APIRouter, Header, HTTPException, Request, status

from app.auth import AuthContext, _verify_jwt
from app.storage import Storage

router = APIRouter(prefix="/auth", tags=["auth"])


class ClaimResponse:
    """Response model for claim endpoint."""

    def __init__(self, councils_updated: int, debates_updated: int):
        self.councils_updated = councils_updated
        self.debates_updated = debates_updated


@router.post("/claim")
async def claim_guest_data(
    request: Request,
    authorization: Annotated[str | None, Header()] = None,
    x_guest_id: Annotated[str | None, Header()] = None,
) -> dict:
    """Claim guest data for an authenticated user.

    This endpoint allows a user who just logged in to migrate their guest data.
    It requires both a valid JWT token (Authorization header) and a guest ID
    (X-Guest-Id header). All councils and debates belonging to the guest will
    be transferred to the authenticated user.

    Args:
        authorization: Bearer token for authentication.
        x_guest_id: Guest ID whose data should be claimed.

    Returns:
        Dictionary with counts of updated councils and debates.

    Raises:
        HTTPException: 401 if JWT is missing or invalid.
        HTTPException: 400 if X-Guest-Id is missing.
    """
    # Verify JWT authentication
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header with Bearer token required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization[7:]  # Strip "Bearer "
    claims = _verify_jwt(token)
    owner_id = claims.get("sub")

    if not owner_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: missing subject claim",
        )

    # Require guest ID
    if not x_guest_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="X-Guest-Id header required to claim guest data",
        )

    # Use the configured storage backend (SQLite or Supabase)
    storage = getattr(request.app.state, "storage", Storage)
    result = await storage.claim_guest_data(guest_id=x_guest_id, owner_id=owner_id)

    return result
