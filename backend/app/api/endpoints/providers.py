"""
AgentsCouncil Backend - Provider Endpoints
"""

from fastapi import APIRouter, Depends, HTTPException

from app.models import ProviderType
from app.oauth_server import OAuthServer, get_oauth_server
from app.providers import ProviderRegistry

router = APIRouter(tags=["providers"])


@router.get("/{provider}/models")
async def list_provider_models(provider: ProviderType):
    """List available models for a specific provider."""
    if not ProviderRegistry.is_available(provider):
        raise HTTPException(
            status_code=400,
            detail=f"Provider {provider.value} is not configured.",
        )

    provider_instance = ProviderRegistry.get(provider)
    if not provider_instance:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get provider instance for {provider.value}",
        )

    # Some providers might not support listing models dynamically
    # For now, we rely on the provider implementation
    try:
        if hasattr(provider_instance, "list_models"):
            models = await provider_instance.list_models()
            return {"models": models}
        else:
            # Fallback for providers without list_models (e.g. OpenAI/Anthropic fixed lists)
            # This could be improved by adding list_models to BaseProvider
            return {"models": [provider_instance.default_model]}

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch models: {e}",
        ) from e


@router.get("/google-oauth/login")
async def google_oauth_login(server: OAuthServer = Depends(get_oauth_server)):
    return {"url": server.get_login_url()}


@router.get("/google-oauth/callback")
async def google_oauth_callback(
    code: str,
    state: str,
    server: OAuthServer = Depends(get_oauth_server),
):
    try:
        account = await server.handle_callback(code, state)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"status": "stored", "account": account}
