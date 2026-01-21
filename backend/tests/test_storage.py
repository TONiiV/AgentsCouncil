"""
Tests for Storage Module
"""
from uuid import uuid4

from app.models import Debate, DebateStatus
from app.storage import Storage


class TestStorageCouncils:
    """Tests for council storage operations."""

    def test_save_council(self, sample_council):
        """Test saving a council."""
        result = Storage.save_council(sample_council)
        assert result.id == sample_council.id
        assert result.name == sample_council.name

    def test_get_council(self, sample_council):
        """Test retrieving a saved council."""
        Storage.save_council(sample_council)
        result = Storage.get_council(sample_council.id)
        assert result is not None
        assert result.id == sample_council.id
        assert result.name == sample_council.name

    def test_get_council_not_found(self):
        """Test retrieving a non-existent council."""
        result = Storage.get_council(uuid4())
        assert result is None

    def test_list_councils_empty(self):
        """Test listing councils when none exist."""
        result = Storage.list_councils()
        assert result == []

    def test_list_councils(self, sample_council):
        """Test listing councils."""
        Storage.save_council(sample_council)
        result = Storage.list_councils()
        assert len(result) == 1
        assert result[0].id == sample_council.id

    def test_delete_council(self, sample_council):
        """Test deleting a council."""
        Storage.save_council(sample_council)
        result = Storage.delete_council(sample_council.id)
        assert result is True
        assert Storage.get_council(sample_council.id) is None

    def test_delete_council_not_found(self):
        """Test deleting a non-existent council."""
        result = Storage.delete_council(uuid4())
        assert result is False


class TestStorageDebates:
    """Tests for debate storage operations."""

    def test_save_debate(self, sample_debate):
        """Test saving a debate."""
        result = Storage.save_debate(sample_debate)
        assert result.id == sample_debate.id
        assert result.topic == sample_debate.topic

    def test_get_debate(self, sample_debate):
        """Test retrieving a saved debate."""
        Storage.save_debate(sample_debate)
        result = Storage.get_debate(sample_debate.id)
        assert result is not None
        assert result.id == sample_debate.id

    def test_get_debate_not_found(self):
        """Test retrieving a non-existent debate."""
        result = Storage.get_debate(uuid4())
        assert result is None

    def test_list_debates_empty(self):
        """Test listing debates when none exist."""
        result = Storage.list_debates()
        assert result == []

    def test_list_debates(self, sample_debate):
        """Test listing debates."""
        Storage.save_debate(sample_debate)
        result = Storage.list_debates()
        assert len(result) == 1
        assert result[0].id == sample_debate.id

    def test_list_debates_filter_by_council(self, sample_debate, sample_council):
        """Test filtering debates by council_id."""
        Storage.save_debate(sample_debate)

        # Create another debate with a different council
        other_debate = Debate(
            council_id=uuid4(),
            topic="Different topic",
            status=DebateStatus.PENDING,
        )
        Storage.save_debate(other_debate)

        # Filter by the sample council
        result = Storage.list_debates(council_id=sample_debate.council_id)
        assert len(result) == 1
        assert result[0].id == sample_debate.id

    def test_update_debate_status(self, sample_debate):
        """Test updating a debate's status."""
        Storage.save_debate(sample_debate)

        # Update status
        sample_debate.status = DebateStatus.CONSENSUS_REACHED
        sample_debate.error_message = None
        Storage.save_debate(sample_debate)

        result = Storage.get_debate(sample_debate.id)
        assert result.status == DebateStatus.CONSENSUS_REACHED

    def test_update_debate_error(self, sample_debate):
        """Test updating debate with error message."""
        Storage.save_debate(sample_debate)

        sample_debate.status = DebateStatus.ERROR
        sample_debate.error_message = "Test error message"
        Storage.save_debate(sample_debate)

        result = Storage.get_debate(sample_debate.id)
        assert result.status == DebateStatus.ERROR
        assert result.error_message == "Test error message"


class TestStorageClear:
    """Tests for storage clear functionality."""

    def test_clear_storage(self, sample_council, sample_debate):
        """Test clearing all storage."""
        Storage.save_council(sample_council)
        Storage.save_debate(sample_debate)

        Storage.clear()

        assert Storage.list_councils() == []
        assert Storage.list_debates() == []
