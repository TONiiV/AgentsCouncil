"""
AgentsCouncil Backend - FastAPI Application
"""

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import auth_router, councils_router, debates_router, providers_router, websocket_router
from app.config import get_settings
from app.oauth_server import create_oauth_server
from app.providers import ProviderRegistry
from app.storage import Storage
from app.storage_supabase import SupabaseStorage


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    settings = get_settings()
    app.state.oauth_server = create_oauth_server()
    ProviderRegistry.initialize()

    # Initialize storage based on configuration
    if settings.supabase_url and settings.supabase_service_role_key:
        # Use Supabase PostgreSQL storage
        if settings.supabase_database_url:
            # Use explicit database URL if provided
            database_url = settings.supabase_database_url
        else:
            # Build database URL from Supabase project URL
            # Extract project ref from URL (e.g., https://xxxx.supabase.co -> xxxx)
            import re

            match = re.match(r"https://([^.]+)\.supabase\.co", settings.supabase_url)
            if match:
                project_ref = match.group(1)
                database_url = f"postgresql://postgres:{settings.supabase_service_role_key}@db.{project_ref}.supabase.co:5432/postgres"
            else:
                raise ValueError(
                    "Cannot construct database URL from supabase_url. "
                    "Please provide SUPABASE_DATABASE_URL explicitly."
                )

        await SupabaseStorage.configure(database_url)
        await SupabaseStorage.initialize()
        app.state.storage = SupabaseStorage
        print("📦 Using Supabase PostgreSQL storage")
    else:
        # Use SQLite storage
        Storage.configure(Path(settings.database_path))
        await Storage.initialize()
        app.state.storage = Storage
        print("📦 Using SQLite storage")

    available = ProviderRegistry.get_available()
    print("🤖 AgentsCouncil Backend starting...")
    print(f"📡 Available AI providers: {[p.value for p in available]}")

    if not available:
        print("⚠️  Warning: No AI providers configured. Add API keys to .env file.")

    yield

    # Shutdown
    await app.state.oauth_server.close()
    if hasattr(app.state, "storage") and app.state.storage is SupabaseStorage:
        await SupabaseStorage.close()
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
app.include_router(auth_router, prefix="/api")
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
