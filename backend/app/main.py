"""
AgentsCouncil Backend - FastAPI Application
"""

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import councils_router, debates_router, providers_router, websocket_router
from app.config import get_settings
from app.oauth_server import create_oauth_server
from app.providers import ProviderRegistry, set_oauth_server_instance
from app.storage import Storage


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    settings = get_settings()
    app.state.oauth_server = create_oauth_server()

    # Set OAuth server instance for provider token refresh
    set_oauth_server_instance(app.state.oauth_server)

    # Initialize providers (must be after OAuth server is set)
    ProviderRegistry.initialize()
    Storage.configure(Path(settings.database_path))
    await Storage.initialize()

    available = ProviderRegistry.get_available()
    print("🤖 AgentsCouncil Backend starting...")
    print(f"📡 Available AI providers: {[p.value for p in available]}")

    if not available:
        print("⚠️  Warning: No AI providers configured. Add API keys to .env file.")

    yield

    # Shutdown
    await app.state.oauth_server.close()
    print("👋 AgentsCouncil Backend shutting down...")


app = FastAPI(
    title="AgentsCouncil API",
    description="Multi-AI debate platform where AI agents discuss topics and reach consensus",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS middleware for Flutter frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(councils_router, prefix="/api")
app.include_router(debates_router, prefix="/api")
app.include_router(providers_router, prefix="/api/providers")
app.include_router(websocket_router)


@app.get("/")
async def root():
    """Root endpoint with API info."""
    settings = get_settings()
    available = ProviderRegistry.get_available()
    return {
        "name": "AgentsCouncil API",
        "version": "0.1.0",
        "status": "running",
        "available_providers": [p.value for p in available],
        "docs_url": "/docs",
    }


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "healthy"}
