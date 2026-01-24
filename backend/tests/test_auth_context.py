"""
Tests for authentication context and JWT verification.
"""

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client():
    """Create an async test client without any auth headers."""
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        yield client


async def test_councils_requires_auth(client: AsyncClient):
    """Test that councils endpoint requires authentication."""
    response = await client.get("/api/councils")
    assert response.status_code == 401


async def test_councils_list_with_guest_id(client: AsyncClient):
    """Test that councils endpoint accepts X-Guest-Id header."""
    response = await client.get(
        "/api/councils",
        headers={"X-Guest-Id": "test-guest-123"},
    )
    assert response.status_code == 200


async def test_debates_requires_auth(client: AsyncClient):
    """Test that debates endpoint requires authentication."""
    response = await client.get("/api/debates")
    assert response.status_code == 401


async def test_debates_list_with_guest_id(client: AsyncClient):
    """Test that debates endpoint accepts X-Guest-Id header."""
    response = await client.get(
        "/api/debates",
        headers={"X-Guest-Id": "test-guest-456"},
    )
    assert response.status_code == 200


async def test_providers_does_not_require_auth(client: AsyncClient):
    """Test that providers endpoint is public (no auth required)."""
    response = await client.get("/api/councils/providers")
    assert response.status_code == 200


async def test_roles_does_not_require_auth(client: AsyncClient):
    """Test that roles endpoint is public (no auth required)."""
    response = await client.get("/api/councils/roles")
    assert response.status_code == 200


class TestAuthContextClass:
    """Unit tests for AuthContext class."""

    def test_user_id_returns_owner_id(self):
        """Test that user_id returns owner_id when set."""
        from app.auth import AuthContext

        auth = AuthContext(owner_id="user-123")
        assert auth.user_id == "user-123"

    def test_user_id_returns_prefixed_guest_id(self):
        """Test that user_id returns prefixed guest_id when set."""
        from app.auth import AuthContext

        auth = AuthContext(guest_id="guest-456")
        assert auth.user_id == "guest:guest-456"

    def test_user_id_prefers_owner_over_guest(self):
        """Test that user_id prefers owner_id over guest_id."""
        from app.auth import AuthContext

        auth = AuthContext(owner_id="user-123", guest_id="guest-456")
        assert auth.user_id == "user-123"

    def test_user_id_raises_when_neither_set(self):
        """Test that user_id raises ValueError when neither is set."""
        from app.auth import AuthContext

        auth = AuthContext()
        with pytest.raises(ValueError, match="No user identifier"):
            _ = auth.user_id

    def test_is_authenticated_true_when_owner_set(self):
        """Test is_authenticated returns True when owner_id is set."""
        from app.auth import AuthContext

        auth = AuthContext(owner_id="user-123")
        assert auth.is_authenticated is True

    def test_is_authenticated_false_when_guest(self):
        """Test is_authenticated returns False for guest users."""
        from app.auth import AuthContext

        auth = AuthContext(guest_id="guest-456")
        assert auth.is_authenticated is False
