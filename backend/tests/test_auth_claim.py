"""
Tests for the guest data claim endpoint.
"""

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from unittest.mock import patch, MagicMock

from app.main import app
from app.models import CouncilConfig, AgentConfig, ProviderType, RoleType, Debate, DebateStatus
from app.storage import Storage
from uuid import uuid4


@pytest_asyncio.fixture
async def client():
    """Create an async test client."""
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport,
        base_url="http://test",
    ) as c:
        yield c


@pytest.fixture
def guest_headers():
    """Headers for guest user."""
    return {"X-Guest-Id": "test-guest-123"}


@pytest.fixture
def auth_headers():
    """Headers for authenticated user (mocked JWT)."""
    return {"Authorization": "Bearer test-jwt-token"}


@pytest.fixture
def sample_agent():
    """Create a sample agent."""
    return AgentConfig(
        id=uuid4(),
        name="Test Agent",
        provider=ProviderType.OPENAI,
        role=RoleType.INVESTMENT_ADVISOR,
    )


@pytest_asyncio.fixture
async def guest_council(sample_agent):
    """Create a council owned by a guest."""
    council = CouncilConfig(
        id=uuid4(),
        name="Guest Council",
        agents=[sample_agent],
    )
    await Storage.save_council(council, guest_id="test-guest-123")
    return council


@pytest_asyncio.fixture
async def guest_debate(guest_council):
    """Create a debate owned by a guest."""
    debate = Debate(
        id=uuid4(),
        council_id=guest_council.id,
        topic="Test topic",
        status=DebateStatus.PENDING,
    )
    await Storage.save_debate(debate, guest_id="test-guest-123")
    return debate


def mock_verify_jwt(token: str) -> dict:
    """Mock JWT verification."""
    if token == "test-jwt-token":
        return {"sub": "authenticated-user-123"}
    raise Exception("Invalid token")


@pytest.mark.asyncio
async def test_claim_guest_data(client, auth_headers, guest_headers, guest_council, guest_debate):
    """Test that authenticated user can claim guest data."""
    with patch("app.api.auth._verify_jwt", mock_verify_jwt):
        response = await client.post(
            "/api/auth/claim",
            headers={**auth_headers, **guest_headers},
        )

    assert response.status_code == 200
    data = response.json()
    assert "councils_updated" in data
    assert "debates_updated" in data
    assert data["councils_updated"] == 1
    assert data["debates_updated"] == 1


@pytest.mark.asyncio
async def test_claim_requires_authentication(client, guest_headers):
    """Test that claim endpoint requires JWT authentication."""
    response = await client.post(
        "/api/auth/claim",
        headers=guest_headers,  # Only guest header, no auth
    )

    # Should fail because no Bearer token
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_claim_requires_guest_id(client, auth_headers):
    """Test that claim endpoint requires X-Guest-Id header."""
    with patch("app.api.auth._verify_jwt", mock_verify_jwt):
        response = await client.post(
            "/api/auth/claim",
            headers=auth_headers,  # Only auth header, no guest ID
        )

    # Should fail because no guest ID
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_claim_no_data_to_claim(client, auth_headers, guest_headers):
    """Test claiming when no guest data exists."""
    with patch("app.api.auth._verify_jwt", mock_verify_jwt):
        response = await client.post(
            "/api/auth/claim",
            headers={**auth_headers, **guest_headers},
        )

    assert response.status_code == 200
    data = response.json()
    assert data["councils_updated"] == 0
    assert data["debates_updated"] == 0
