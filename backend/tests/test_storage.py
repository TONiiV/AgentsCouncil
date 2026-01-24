"""
Tests for Storage Module
"""

from uuid import uuid4

import pytest

from app.models import AgentConfig, CouncilConfig, Debate, DebateStatus, ProviderType, RoleType
from app.storage import Storage


class TestStorageCouncils:
    """Tests for council storage operations."""

    @pytest.mark.asyncio
    async def test_initialize_creates_database(self, tmp_path):
        """Test initializing storage creates the database file."""
        db_path = tmp_path / "agentscouncil.db"
        Storage.configure(db_path)

        await Storage.initialize()

        assert db_path.exists()

    @pytest.mark.asyncio
    async def test_configure_resets_database_path(self, tmp_path):
        """Test configure resets initialization for new database paths."""
        first_path = tmp_path / "first.db"
        second_path = tmp_path / "second.db"

        Storage.configure(first_path)
        await Storage.initialize()

        Storage.configure(second_path)
        await Storage.initialize()

        assert second_path.exists()

    @pytest.mark.asyncio
    async def test_save_council(self, sample_council):
        """Test saving a council."""
        result = await Storage.save_council(sample_council)
        assert result.id == sample_council.id
        assert result.name == sample_council.name

    @pytest.mark.asyncio
    async def test_get_council(self, sample_council):
        """Test retrieving a saved council."""
        await Storage.save_council(sample_council)
        result = await Storage.get_council(sample_council.id)
        assert result is not None
        assert result.id == sample_council.id
        assert result.name == sample_council.name

    @pytest.mark.asyncio
    async def test_get_council_not_found(self):
        """Test retrieving a non-existent council."""
        result = await Storage.get_council(uuid4())
        assert result is None

    @pytest.mark.asyncio
    async def test_list_councils_empty(self):
        """Test listing councils when none exist."""
        result = await Storage.list_councils()
        assert result == []

    @pytest.mark.asyncio
    async def test_list_councils(self, sample_council):
        """Test listing councils."""
        await Storage.save_council(sample_council)
        result = await Storage.list_councils()
        assert len(result) == 1
        assert result[0].id == sample_council.id

    @pytest.mark.asyncio
    async def test_delete_council(self, sample_council):
        """Test deleting a council."""
        await Storage.save_council(sample_council)
        result = await Storage.delete_council(sample_council.id)
        assert result is True
        assert await Storage.get_council(sample_council.id) is None

    @pytest.mark.asyncio
    async def test_delete_council_not_found(self):
        """Test deleting a non-existent council."""
        result = await Storage.delete_council(uuid4())
        assert result is False


class TestStorageDebates:
    """Tests for debate storage operations."""

    @pytest.mark.asyncio
    async def test_save_debate(self, sample_debate):
        """Test saving a debate."""
        result = await Storage.save_debate(sample_debate)
        assert result.id == sample_debate.id
        assert result.topic == sample_debate.topic

    @pytest.mark.asyncio
    async def test_get_debate(self, sample_debate):
        """Test retrieving a saved debate."""
        await Storage.save_debate(sample_debate)
        result = await Storage.get_debate(sample_debate.id)
        assert result is not None
        assert result.id == sample_debate.id

    @pytest.mark.asyncio
    async def test_get_debate_not_found(self):
        """Test retrieving a non-existent debate."""
        result = await Storage.get_debate(uuid4())
        assert result is None

    @pytest.mark.asyncio
    async def test_list_debates_empty(self):
        """Test listing debates when none exist."""
        result = await Storage.list_debates()
        assert result == []

    @pytest.mark.asyncio
    async def test_list_debates(self, sample_debate):
        """Test listing debates."""
        await Storage.save_debate(sample_debate)
        result = await Storage.list_debates()
        assert len(result) == 1
        assert result[0].id == sample_debate.id

    @pytest.mark.asyncio
    async def test_list_debates_filter_by_council(self, sample_debate):
        """Test filtering debates by council_id."""
        await Storage.save_debate(sample_debate)

        other_debate = Debate(
            council_id=uuid4(),
            topic="Different topic",
            status=DebateStatus.PENDING,
        )
        await Storage.save_debate(other_debate)

        result = await Storage.list_debates(council_id=sample_debate.council_id)
        assert len(result) == 1
        assert result[0].id == sample_debate.id

    @pytest.mark.asyncio
    async def test_update_debate_status(self, sample_debate):
        """Test updating a debate's status."""
        await Storage.save_debate(sample_debate)

        sample_debate.status = DebateStatus.CONSENSUS_REACHED
        sample_debate.error_message = None
        await Storage.save_debate(sample_debate)

        result = await Storage.get_debate(sample_debate.id)
        assert result is not None
        assert result.status == DebateStatus.CONSENSUS_REACHED

    @pytest.mark.asyncio
    async def test_update_debate_error(self, sample_debate):
        """Test updating debate with error message."""
        await Storage.save_debate(sample_debate)

        sample_debate.status = DebateStatus.ERROR
        sample_debate.error_message = "Test error message"
        await Storage.save_debate(sample_debate)

        result = await Storage.get_debate(sample_debate.id)
        assert result is not None
        assert result.status == DebateStatus.ERROR
        assert result.error_message == "Test error message"


class TestStorageOwnerFiltering:
    """Tests for owner-based filtering."""

    @pytest.mark.asyncio
    async def test_list_councils_filters_owner(self, sample_council):
        """Test listing councils filtered by owner_id."""
        owner_id = "owner-123"
        other_owner_id = "owner-456"

        # Save council with owner_id
        await Storage.save_council(sample_council, owner_id=owner_id)

        # Create another council with different owner (with fresh agent IDs)
        other_agents = [
            AgentConfig(
                id=uuid4(),
                name=agent.name,
                provider=agent.provider,
                role=agent.role,
            )
            for agent in sample_council.agents
        ]
        other_council = CouncilConfig(
            name="Other Council",
            agents=other_agents,
            max_rounds=3,
            consensus_threshold=0.8,
        )
        await Storage.save_council(other_council, owner_id=other_owner_id)

        # List councils for owner_id should only return the first council
        councils = await Storage.list_councils(owner_id=owner_id)
        assert len(councils) == 1
        assert councils[0].id == sample_council.id

    @pytest.mark.asyncio
    async def test_list_councils_excludes_guest_rows_when_owner_set(self, sample_council):
        """Test that guest rows are not returned when owner_id is set."""
        owner_id = "owner-123"
        guest_id = "guest-789"

        # Save council with owner_id
        await Storage.save_council(sample_council, owner_id=owner_id)

        # Create guest council (no owner, just guest_id) with fresh agent IDs
        guest_agents = [
            AgentConfig(
                id=uuid4(),
                name=agent.name,
                provider=agent.provider,
                role=agent.role,
            )
            for agent in sample_council.agents
        ]
        guest_council = CouncilConfig(
            name="Guest Council",
            agents=guest_agents,
            max_rounds=3,
            consensus_threshold=0.8,
        )
        await Storage.save_council(guest_council, guest_id=guest_id)

        # List councils for owner_id should not include the guest council
        councils = await Storage.list_councils(owner_id=owner_id)
        assert len(councils) == 1
        assert councils[0].id == sample_council.id

    @pytest.mark.asyncio
    async def test_list_debates_filters_owner(self, sample_council, sample_debate):
        """Test listing debates filtered by owner_id."""
        owner_id = "owner-123"
        other_owner_id = "owner-456"

        # Save council and debate with owner_id
        await Storage.save_council(sample_council, owner_id=owner_id)
        await Storage.save_debate(sample_debate, owner_id=owner_id)

        # Create another debate with different owner
        other_debate = Debate(
            council_id=sample_council.id,
            topic="Other topic",
            status=DebateStatus.PENDING,
        )
        await Storage.save_debate(other_debate, owner_id=other_owner_id)

        # List debates for owner_id should only return the first debate
        debates = await Storage.list_debates(owner_id=owner_id)
        assert len(debates) == 1
        assert debates[0].id == sample_debate.id


class TestStorageClear:
    """Tests for storage clear functionality."""

    @pytest.mark.asyncio
    async def test_clear_storage(self, sample_council, sample_debate):
        """Test clearing all storage."""
        await Storage.save_council(sample_council)
        await Storage.save_debate(sample_debate)

        await Storage.clear()

        assert await Storage.list_councils() == []
        assert await Storage.list_debates() == []
