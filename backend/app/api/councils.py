"""
AgentsCouncil Backend - Council API Routes
"""

from uuid import UUID

from fastapi import APIRouter, HTTPException

from app.auth import AuthContextDep
from app.models import (
    ROLE_PROMPTS,
    CouncilConfig,
    CouncilCreate,
    ProviderType,
    RoleType,
)
from app.providers import ProviderRegistry
from app.storage import Storage

router = APIRouter(prefix="/councils", tags=["councils"])


@router.get("/providers")
async def list_available_providers() -> dict:
    """List available AI providers (those with configured API keys)."""
    available = ProviderRegistry.get_available()
    return {
        "available": [p.value for p in available],
        "all": [p.value for p in ProviderType],
    }


@router.get("/providers/{provider_type}/models")
async def list_provider_models(provider_type: ProviderType) -> list[str]:
    """List available models for a specific provider."""
    provider = ProviderRegistry.get(provider_type)
    if not provider:
        raise HTTPException(
            status_code=404, detail=f"Provider {provider_type.value} is not available."
        )

    # Check if provider has list_models method (Ollama does)
    if hasattr(provider, "list_models"):
        return await provider.list_models()

    # Return default model for others (or empty list if unknown)
    return [provider.default_model]


@router.get("/roles")
async def list_roles() -> list[dict]:
    """List available built-in roles with their descriptions."""
    roles = []
    for role in RoleType:
        prompt = ROLE_PROMPTS.get(role, "")
        roles.append(
            {
                "id": role.value,
                "name": role.value.replace("_", " ").title(),
                "description": prompt[:200] + "..." if len(prompt) > 200 else prompt,
                "is_custom": role == RoleType.CUSTOM,
            }
        )
    return roles


@router.post("", response_model=CouncilConfig)
async def create_council(council_data: CouncilCreate, auth: AuthContextDep) -> CouncilConfig:
    """Create a new council configuration."""
    # Validate that all agent providers are available
    for agent in council_data.agents:
        if not ProviderRegistry.is_available(agent.provider):
            raise HTTPException(
                status_code=400,
                detail=f"Provider {agent.provider.value} is not configured. "
                f"Please add the API key to your .env file.",
            )

    council = CouncilConfig(
        name=council_data.name,
        agents=council_data.agents,
        max_rounds=council_data.max_rounds,
        consensus_threshold=council_data.consensus_threshold,
    )
    return await Storage.save_council(council)


@router.get("", response_model=list[CouncilConfig])
async def list_councils(auth: AuthContextDep) -> list[CouncilConfig]:
    """List all council configurations."""
    return await Storage.list_councils()


@router.get("/{council_id}", response_model=CouncilConfig)
async def get_council(council_id: UUID, auth: AuthContextDep) -> CouncilConfig:
    """Get a specific council configuration."""
    council = await Storage.get_council(council_id)
    if not council:
        raise HTTPException(status_code=404, detail="Council not found")
    return council


@router.put("/{council_id}", response_model=CouncilConfig)
async def update_council(
    council_id: UUID, council_data: CouncilCreate, auth: AuthContextDep
) -> CouncilConfig:
    """Update an existing council configuration."""
    existing = await Storage.get_council(council_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Council not found")

    # Validate that all agent providers are available
    for agent in council_data.agents:
        if not ProviderRegistry.is_available(agent.provider):
            raise HTTPException(
                status_code=400,
                detail=f"Provider {agent.provider.value} is not configured.",
            )

    # Preserve the original ID and CreatedAt
    updated_council = CouncilConfig(
        id=council_id,
        name=council_data.name,
        agents=council_data.agents,
        max_rounds=council_data.max_rounds,
        consensus_threshold=council_data.consensus_threshold,
        created_at=existing.created_at,
    )
    return await Storage.save_council(updated_council)


@router.delete("/{council_id}")
async def delete_council(council_id: UUID, auth: AuthContextDep) -> dict:
    """Delete a council configuration."""
    if await Storage.delete_council(council_id):
        return {"status": "deleted"}
    raise HTTPException(status_code=404, detail="Council not found")
