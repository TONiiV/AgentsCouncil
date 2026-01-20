"""
AgentsCouncil Backend - Debate API Routes
"""
import asyncio
import logging
import traceback
from uuid import UUID

from fastapi import APIRouter, HTTPException, BackgroundTasks

from app.models import Debate, DebateCreate, DebateStatus
from app.core.debate_engine import DebateEngine
from app.storage import Storage


logger = logging.getLogger(__name__)

router = APIRouter(prefix="/debates", tags=["debates"])

# Track running debates
_running_debates: dict[UUID, asyncio.Task] = {}


async def _run_debate_task(debate_id: UUID, engine: DebateEngine) -> None:
    """Background task to run a debate."""
    try:
        logger.info(f"Starting debate {debate_id} on topic: {engine.topic}")
        result = await engine.run()
        Storage.save_debate(result)
        logger.info(f"Debate {debate_id} completed with status: {result.status.value}")
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        logger.error(f"Debate {debate_id} failed: {error_msg}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        debate = Storage.get_debate(debate_id)
        if debate:
            debate.status = DebateStatus.ERROR
            debate.error_message = error_msg
            Storage.save_debate(debate)
    finally:
        if debate_id in _running_debates:
            del _running_debates[debate_id]


@router.post("", response_model=Debate)
async def start_debate(
    debate_data: DebateCreate,
    background_tasks: BackgroundTasks,
) -> Debate:
    """Start a new debate on a topic."""
    # Get the council configuration
    council = Storage.get_council(debate_data.council_id)
    if not council:
        raise HTTPException(status_code=404, detail="Council not found")

    if len(council.agents) < 2:
        raise HTTPException(
            status_code=400,
            detail="Council must have at least 2 agents for a debate",
        )

    # Create debate engine
    engine = DebateEngine(council, debate_data.topic)
    
    # Save initial debate state
    Storage.save_debate(engine.debate)
    
    # Start debate in background
    task = asyncio.create_task(_run_debate_task(engine.debate.id, engine))
    _running_debates[engine.debate.id] = task

    return engine.debate


@router.get("", response_model=list[Debate])
async def list_debates(council_id: UUID | None = None) -> list[Debate]:
    """List all debates, optionally filtered by council."""
    return Storage.list_debates(council_id)


@router.get("/{debate_id}", response_model=Debate)
async def get_debate(debate_id: UUID) -> Debate:
    """Get a specific debate and its current state."""
    debate = Storage.get_debate(debate_id)
    if not debate:
        raise HTTPException(status_code=404, detail="Debate not found")
    return debate


@router.get("/{debate_id}/summary")
async def get_debate_summary(debate_id: UUID) -> dict:
    """Get the summary and key points from a completed debate."""
    debate = Storage.get_debate(debate_id)
    if not debate:
        raise HTTPException(status_code=404, detail="Debate not found")

    if debate.status not in [
        DebateStatus.CONSENSUS_REACHED,
        DebateStatus.ROUND_LIMIT_REACHED,
    ]:
        raise HTTPException(
            status_code=400,
            detail=f"Debate is not complete. Status: {debate.status.value}",
        )

    return {
        "topic": debate.topic,
        "status": debate.status.value,
        "total_rounds": len(debate.rounds),
        "summary": debate.summary,
        "pro_points": debate.pro_points,
        "against_points": debate.against_points,
    }


@router.post("/{debate_id}/cancel")
async def cancel_debate(debate_id: UUID) -> dict:
    """Cancel a running debate."""
    debate = Storage.get_debate(debate_id)
    if not debate:
        raise HTTPException(status_code=404, detail="Debate not found")

    if debate_id in _running_debates:
        _running_debates[debate_id].cancel()
        del _running_debates[debate_id]

    debate.status = DebateStatus.CANCELLED
    Storage.save_debate(debate)
    return {"status": "cancelled"}
