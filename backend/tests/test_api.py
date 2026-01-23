"""
Tests for FastAPI REST Endpoints
"""

from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models import (
    AgentConfig,
    CouncilConfig,
    DebateStatus,
    ProviderType,
    RoleType,
)
from app.providers import ProviderRegistry
from app.storage import Storage


@pytest.fixture
def client():
    """Create a test client."""
    with TestClient(app) as c:
        yield c


class TestRootEndpoint:
    """Tests for the root endpoint."""

    def test_root_endpoint(self, client):
        """Test the root endpoint returns API info."""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "AgentsCouncil API"
        assert "version" in data
        assert "status" in data

    def test_health_endpoint(self, client):
        """Test the health check endpoint."""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"


class TestCouncilsAPI:
    """Tests for council endpoints."""

    def test_list_councils_empty(self, client):
        """Test listing councils when none exist."""
        response = client.get("/api/councils")
        assert response.status_code == 200
        assert response.json() == []

    def test_list_available_providers(self, client):
        """Test listing available providers."""
        response = client.get("/api/councils/providers")
        assert response.status_code == 200
        data = response.json()
        assert "available" in data
        assert "all" in data
        assert "openai" in data["all"]
        assert "anthropic" in data["all"]
        assert "gemini" in data["all"]

    def test_list_roles(self, client):
        """Test listing available roles."""
        response = client.get("/api/councils/roles")
        assert response.status_code == 200
        roles = response.json()
        assert len(roles) > 0
        # Check structure
        assert "id" in roles[0]
        assert "name" in roles[0]
        assert "description" in roles[0]

    @patch.object(ProviderRegistry, "is_available", return_value=True)
    def test_create_council(self, mock_is_available, client):
        """Test creating a council."""
        council_data = {
            "name": "Test Council",
            "agents": [
                {
                    "name": "Agent 1",
                    "provider": "gemini",
                    "role": "tech_strategist",
                },
                {
                    "name": "Agent 2",
                    "provider": "gemini",
                    "role": "devils_advocate",
                },
            ],
            "max_rounds": 3,
            "consensus_threshold": 0.75,
        }

        response = client.post("/api/councils", json=council_data)
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Test Council"
        assert len(data["agents"]) == 2
        assert data["max_rounds"] == 3

    def test_create_council_unavailable_provider(self, client):
        """Test creating a council with unavailable provider."""
        # Clear registry to ensure no providers available
        with patch.object(ProviderRegistry, "is_available", return_value=False):
            council_data = {
                "name": "Test Council",
                "agents": [
                    {
                        "name": "Agent 1",
                        "provider": "openai",
                        "role": "tech_strategist",
                    },
                ],
            }

            response = client.post("/api/councils", json=council_data)
            assert response.status_code == 400
            assert "not configured" in response.json()["detail"]

    def test_get_council(self, client, sample_council):
        """Test getting a specific council."""
        Storage.save_council(sample_council)

        response = client.get(f"/api/councils/{sample_council.id}")
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == sample_council.name

    def test_get_council_not_found(self, client):
        """Test getting a non-existent council."""
        response = client.get(f"/api/councils/{uuid4()}")
        assert response.status_code == 404

    def test_delete_council(self, client, sample_council):
        """Test deleting a council."""
        Storage.save_council(sample_council)

        response = client.delete(f"/api/councils/{sample_council.id}")
        assert response.status_code == 200
        assert response.json()["status"] == "deleted"

    def test_delete_council_not_found(self, client):
        """Test deleting a non-existent council."""
        response = client.delete(f"/api/councils/{uuid4()}")
        assert response.status_code == 404


class TestDebatesAPI:
    """Tests for debate endpoints."""

    def test_list_debates_empty(self, client):
        """Test listing debates when none exist."""
        response = client.get("/api/debates")
        assert response.status_code == 200
        assert response.json() == []

    def test_list_debates(self, client, sample_debate):
        """Test listing debates."""
        Storage.save_debate(sample_debate)

        response = client.get("/api/debates")
        assert response.status_code == 200
        debates = response.json()
        assert len(debates) == 1

    def test_get_debate(self, client, sample_debate):
        """Test getting a specific debate."""
        Storage.save_debate(sample_debate)

        response = client.get(f"/api/debates/{sample_debate.id}")
        assert response.status_code == 200
        data = response.json()
        assert data["topic"] == sample_debate.topic

    def test_get_debate_not_found(self, client):
        """Test getting a non-existent debate."""
        response = client.get(f"/api/debates/{uuid4()}")
        assert response.status_code == 404

    def test_start_debate_council_not_found(self, client):
        """Test starting a debate with non-existent council."""
        debate_data = {
            "council_id": str(uuid4()),
            "topic": "Test topic",
        }

        response = client.post("/api/debates", json=debate_data)
        assert response.status_code == 404
        assert "Council not found" in response.json()["detail"]

    def test_start_debate_insufficient_agents(self, client):
        """Test starting a debate with insufficient agents."""
        # Create a council with only 1 agent
        council = CouncilConfig(
            name="Small Council",
            agents=[
                AgentConfig(
                    name="Solo Agent",
                    provider=ProviderType.GEMINI,
                    role=RoleType.TECH_STRATEGIST,
                )
            ],
        )
        Storage.save_council(council)

        debate_data = {
            "council_id": str(council.id),
            "topic": "Test topic",
        }

        response = client.post("/api/debates", json=debate_data)
        assert response.status_code == 400
        assert "at least 2 agents" in response.json()["detail"]

    def test_cancel_debate(self, client, sample_debate):
        """Test cancelling a debate."""
        Storage.save_debate(sample_debate)

        response = client.post(f"/api/debates/{sample_debate.id}/cancel")
        assert response.status_code == 200
        assert response.json()["status"] == "cancelled"

        # Verify status was updated
        updated = Storage.get_debate(sample_debate.id)
        assert updated.status == DebateStatus.CANCELLED

    def test_cancel_debate_not_found(self, client):
        """Test cancelling a non-existent debate."""
        response = client.post(f"/api/debates/{uuid4()}/cancel")
        assert response.status_code == 404

    def test_get_debate_summary_not_complete(self, client, sample_debate):
        """Test getting summary of incomplete debate."""
        sample_debate.status = DebateStatus.IN_PROGRESS
        Storage.save_debate(sample_debate)

        response = client.get(f"/api/debates/{sample_debate.id}/summary")
        assert response.status_code == 400
        assert "not complete" in response.json()["detail"]

    def test_get_debate_summary_complete(self, client, completed_debate):
        """Test getting summary of completed debate."""
        Storage.save_debate(completed_debate)

        response = client.get(f"/api/debates/{completed_debate.id}/summary")
        assert response.status_code == 200
        data = response.json()
        assert "topic" in data
        assert "status" in data
        assert "total_rounds" in data

    def test_debate_error_message_in_response(self, client, sample_debate):
        """Test that error message is included in debate response."""
        sample_debate.status = DebateStatus.ERROR
        sample_debate.error_message = "Test error: API call failed"
        Storage.save_debate(sample_debate)

        response = client.get(f"/api/debates/{sample_debate.id}")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "error"
        assert data["error_message"] == "Test error: API call failed"


class TestProvidersAPI:
    """Tests for provider endpoints."""

    def test_list_provider_models(self, client):
        """Test listing models for a provider."""
        # We need to mock the ProviderRegistry to return a mock provider with list_models
        from app.models import ProviderType
        from app.providers import ProviderRegistry

        mock_provider = MagicMock()
        mock_provider.list_models = AsyncMock(return_value=["model1", "model2"])

        with (
            patch.object(ProviderRegistry, "get", return_value=mock_provider),
            patch.object(ProviderRegistry, "is_available", return_value=True),
        ):

            response = client.get(f"/api/providers/{ProviderType.GEMINI.value}/models")
            assert response.status_code == 200
            data = response.json()
            assert "models" in data
            models = data["models"]
            assert "model1" in models
