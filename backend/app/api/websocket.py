"""
AgentsCouncil Backend - WebSocket Routes
"""

import asyncio
from uuid import UUID

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.models import DebateUpdate
from app.storage import Storage

router = APIRouter(tags=["websocket"])


# Connection manager for debate subscriptions
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[UUID, list[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, debate_id: UUID):
        await websocket.accept()
        if debate_id not in self.active_connections:
            self.active_connections[debate_id] = []
        self.active_connections[debate_id].append(websocket)

    def disconnect(self, websocket: WebSocket, debate_id: UUID):
        if debate_id in self.active_connections:
            if websocket in self.active_connections[debate_id]:
                self.active_connections[debate_id].remove(websocket)
            if not self.active_connections[debate_id]:
                del self.active_connections[debate_id]

    async def broadcast(self, debate_id: UUID, message: dict):
        if debate_id in self.active_connections:
            disconnected = []
            for connection in self.active_connections[debate_id]:
                try:
                    await connection.send_json(message)
                except Exception:
                    disconnected.append(connection)
            # Clean up disconnected
            for conn in disconnected:
                self.disconnect(conn, debate_id)


manager = ConnectionManager()


@router.websocket("/ws/debates/{debate_id}")
async def debate_websocket(websocket: WebSocket, debate_id: UUID):
    """WebSocket endpoint for real-time debate updates."""
    await manager.connect(websocket, debate_id)

    try:
        # Send current state
        debate = Storage.get_debate(debate_id)
        if debate:
            await websocket.send_json(
                {
                    "event_type": "initial_state",
                    "data": debate.model_dump(mode="json"),
                }
            )

        # Keep connection alive and listen for messages
        while True:
            try:
                # Just keep the connection alive, client can send pings
                data = await asyncio.wait_for(
                    websocket.receive_text(),
                    timeout=30.0,
                )
                # Handle ping
                if data == "ping":
                    await websocket.send_text("pong")
            except TimeoutError:
                # Send heartbeat
                await websocket.send_text("heartbeat")
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(websocket, debate_id)


async def broadcast_debate_update(update: DebateUpdate):
    """Broadcast a debate update to all connected clients."""
    await manager.broadcast(
        update.debate_id,
        {
            "event_type": update.event_type,
            "data": update.data,
        },
    )
