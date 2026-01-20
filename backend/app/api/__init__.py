"""
AgentsCouncil Backend - API Module
"""
from app.api.councils import router as councils_router
from app.api.debates import router as debates_router
from app.api.websocket import router as websocket_router

__all__ = ["councils_router", "debates_router", "websocket_router"]
