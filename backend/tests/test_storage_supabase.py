"""
Tests for Supabase Storage Module

These tests use mocking to verify the SupabaseStorage class
without requiring an actual Supabase connection.
"""

from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest

from app.models import (
    AgentConfig,
    CouncilConfig,
    Debate,
    DebateStatus,
    ProviderType,
    RoleType,
)


@pytest.fixture
def sample_agents():
    """Create sample agents for testing."""
    return [
        AgentConfig(
            id=uuid4(),
            name="Test Agent 1",
            provider=ProviderType.GEMINI,
            role=RoleType.TECH_STRATEGIST,
        ),
        AgentConfig(
            id=uuid4(),
            name="Test Agent 2",
            provider=ProviderType.ANTHROPIC,
            role=RoleType.DEVILS_ADVOCATE,
        ),
    ]


@pytest.fixture
def sample_council(sample_agents):
    """Create a sample council for testing."""
    return CouncilConfig(
        id=uuid4(),
        name="Test Council",
        agents=sample_agents,
        max_rounds=3,
        consensus_threshold=0.8,
    )


@pytest.fixture
def sample_debate(sample_council):
    """Create a sample debate for testing."""
    return Debate(
        id=uuid4(),
        council_id=sample_council.id,
        topic="Test topic",
        status=DebateStatus.PENDING,
    )


class TestSupabaseStorageInterface:
    """Tests to verify SupabaseStorage interface matches Storage."""

    def test_storage_supabase_module_exists(self):
        """Test that the storage_supabase module can be imported."""
        from app.storage_supabase import SupabaseStorage

        assert SupabaseStorage is not None

    def test_has_required_methods(self):
        """Test that SupabaseStorage has all required methods."""
        from app.storage_supabase import SupabaseStorage

        # Check all required class methods exist
        assert hasattr(SupabaseStorage, "configure")
        assert hasattr(SupabaseStorage, "initialize")
        assert hasattr(SupabaseStorage, "save_council")
        assert hasattr(SupabaseStorage, "get_council")
        assert hasattr(SupabaseStorage, "list_councils")
        assert hasattr(SupabaseStorage, "delete_council")
        assert hasattr(SupabaseStorage, "save_debate")
        assert hasattr(SupabaseStorage, "get_debate")
        assert hasattr(SupabaseStorage, "list_debates")
        assert hasattr(SupabaseStorage, "delete_debate")
        assert hasattr(SupabaseStorage, "clear")


class TestSupabaseStorageWithMock:
    """Tests with mocked asyncpg connection."""

    @pytest.fixture
    def mock_pool(self):
        """Create a mock asyncpg connection pool."""
        pool = MagicMock()
        conn = AsyncMock()
        pool.acquire.return_value.__aenter__ = AsyncMock(return_value=conn)
        pool.acquire.return_value.__aexit__ = AsyncMock(return_value=None)
        return pool, conn

    @pytest.mark.asyncio
    async def test_save_council_sets_owner(self, mock_pool, sample_council):
        """Test that save_council accepts owner_id parameter."""
        pool, conn = mock_pool
        owner_id = "owner-123"

        with patch("app.storage_supabase.SupabaseStorage._pool", pool):
            with patch("app.storage_supabase.SupabaseStorage._initialized", True):
                from app.storage_supabase import SupabaseStorage

                await SupabaseStorage.save_council(sample_council, owner_id=owner_id)

                # Verify execute was called (council insert + agent deletes + agent inserts)
                assert conn.execute.called

    @pytest.mark.asyncio
    async def test_save_council_sets_guest_id(self, mock_pool, sample_council):
        """Test that save_council accepts guest_id parameter."""
        pool, conn = mock_pool
        guest_id = "guest-456"

        with patch("app.storage_supabase.SupabaseStorage._pool", pool):
            with patch("app.storage_supabase.SupabaseStorage._initialized", True):
                from app.storage_supabase import SupabaseStorage

                await SupabaseStorage.save_council(sample_council, guest_id=guest_id)

                assert conn.execute.called

    @pytest.mark.asyncio
    async def test_list_councils_filters_by_owner(self, mock_pool):
        """Test that list_councils accepts owner_id parameter."""
        pool, conn = mock_pool
        owner_id = "owner-123"

        # Mock empty result
        conn.fetch.return_value = []

        with patch("app.storage_supabase.SupabaseStorage._pool", pool):
            with patch("app.storage_supabase.SupabaseStorage._initialized", True):
                from app.storage_supabase import SupabaseStorage

                councils = await SupabaseStorage.list_councils(owner_id=owner_id)

                assert councils == []
                # Verify fetch was called with owner_id filter
                conn.fetch.assert_called()
                call_args = conn.fetch.call_args
                assert "owner_id" in call_args[0][0]
                assert owner_id in call_args[0]

    @pytest.mark.asyncio
    async def test_save_debate_sets_owner(self, mock_pool, sample_debate):
        """Test that save_debate accepts owner_id parameter."""
        pool, conn = mock_pool
        owner_id = "owner-123"

        with patch("app.storage_supabase.SupabaseStorage._pool", pool):
            with patch("app.storage_supabase.SupabaseStorage._initialized", True):
                from app.storage_supabase import SupabaseStorage

                await SupabaseStorage.save_debate(sample_debate, owner_id=owner_id)

                assert conn.execute.called

    @pytest.mark.asyncio
    async def test_list_debates_filters_by_owner(self, mock_pool):
        """Test that list_debates accepts owner_id parameter."""
        pool, conn = mock_pool
        owner_id = "owner-123"

        # Mock empty result
        conn.fetch.return_value = []

        with patch("app.storage_supabase.SupabaseStorage._pool", pool):
            with patch("app.storage_supabase.SupabaseStorage._initialized", True):
                from app.storage_supabase import SupabaseStorage

                debates = await SupabaseStorage.list_debates(owner_id=owner_id)

                assert debates == []
                conn.fetch.assert_called()
