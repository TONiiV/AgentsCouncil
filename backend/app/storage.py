import json
import logging
from pathlib import Path
from uuid import UUID

from app import db
from app.models import CouncilConfig, Debate

# Setup basic logging
logger = logging.getLogger(__name__)

DATA_DIR = Path(__file__).parent.parent / "data"
STORAGE_FILE = DATA_DIR / "storage.json"


class Storage:
    """
    File-based JSON storage for MVP.
    Data is persisted to backend/data/storage.json.
    """

    _councils: dict[UUID, CouncilConfig] = {}
    _debates: dict[UUID, Debate] = {}
    _loaded: bool = False
    _db_path: Path | None = None

    @classmethod
    def configure(cls, db_path: Path) -> None:
        cls._db_path = db_path

    @classmethod
    async def initialize(cls) -> None:
        if cls._db_path is None:
            cls._db_path = DATA_DIR / "agentscouncil.db"
        await db.init_db(cls._db_path)

    @staticmethod
    def _ensure_loaded():
        """Load data from disk if not already loaded."""
        if Storage._loaded:
            return

        if not DATA_DIR.exists():
            DATA_DIR.mkdir(parents=True, exist_ok=True)

        if STORAGE_FILE.exists():
            try:
                with open(STORAGE_FILE, encoding="utf-8") as f:
                    data = json.load(f)

                # Parse Councils
                for c_data in data.get("councils", []):
                    try:
                        council = CouncilConfig(**c_data)
                        Storage._councils[council.id] = council
                    except Exception as e:
                        logger.error(f"Failed to load council: {e}")

                # Parse Debates
                for d_data in data.get("debates", []):
                    try:
                        debate = Debate(**d_data)
                        # Fix stuck debates on startup
                        if debate.status == "in_progress":
                            logger.warning(f"Found stuck debate {debate.id}. Marking as ERROR.")
                            debate.status = "error"
                            debate.error_message = "Interrupted by server restart"

                        Storage._debates[debate.id] = debate
                    except Exception as e:
                        logger.error(f"Failed to load debate: {e}")

                logger.info(
                    f"Loaded {len(Storage._councils)} councils and {len(Storage._debates)} debates."
                )
            except Exception as e:
                logger.error(f"Failed to load storage file: {e}")

        Storage._loaded = True

    @staticmethod
    def _save():
        """Save current state to disk."""
        if not DATA_DIR.exists():
            DATA_DIR.mkdir(parents=True, exist_ok=True)

        data = {
            "councils": [c.model_dump(mode="json") for c in Storage._councils.values()],
            "debates": [d.model_dump(mode="json") for d in Storage._debates.values()],
        }

        try:
            # Atomic write pattern: write to temp file then rename
            temp_file = STORAGE_FILE.with_suffix(".tmp")
            with open(temp_file, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, default=str)
            temp_file.replace(STORAGE_FILE)
        except Exception as e:
            logger.error(f"Failed to save storage: {e}")

    @classmethod
    def save_council(cls, council: CouncilConfig) -> CouncilConfig:
        cls._ensure_loaded()
        cls._councils[council.id] = council
        cls._save()
        return council

    @classmethod
    def get_council(cls, council_id: UUID) -> CouncilConfig | None:
        cls._ensure_loaded()
        return cls._councils.get(council_id)

    @classmethod
    def list_councils(cls) -> list[CouncilConfig]:
        cls._ensure_loaded()
        return list(cls._councils.values())

    @classmethod
    def delete_council(cls, council_id: UUID) -> bool:
        cls._ensure_loaded()
        if council_id in cls._councils:
            del cls._councils[council_id]
            cls._save()
            return True
        return False

    @classmethod
    def save_debate(cls, debate: Debate) -> Debate:
        cls._ensure_loaded()
        cls._debates[debate.id] = debate
        cls._save()
        return debate

    @classmethod
    def get_debate(cls, debate_id: UUID) -> Debate | None:
        cls._ensure_loaded()
        return cls._debates.get(debate_id)

    @classmethod
    def delete_debate(cls, debate_id: UUID) -> bool:
        """Delete a debate from storage."""
        cls._ensure_loaded()
        if debate_id in cls._debates:
            del cls._debates[debate_id]
            cls._save()
            return True
        return False

    @classmethod
    def list_debates(cls, council_id: UUID | None = None) -> list[Debate]:
        cls._ensure_loaded()
        debates = list(cls._debates.values())
        if council_id:
            debates = [d for d in debates if d.council_id == council_id]
        return debates

    @classmethod
    def clear(cls) -> None:
        """Clear all storage (for testing)."""
        cls._councils.clear()
        cls._debates.clear()
        cls._save()
