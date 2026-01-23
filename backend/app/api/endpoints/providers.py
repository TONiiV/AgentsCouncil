"""
AgentsCouncil Backend - Provider Endpoints
"""

from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from app.models import ProviderType
from app.oauth_server import OAuthServer, get_oauth_server
from app.providers import ProviderRegistry

router = APIRouter(tags=["providers"])

# Set up Jinja2 templates for OAuth callback HTML
_templates_dir = Path(__file__).parent.parent.parent / "templates"
templates = Jinja2Templates(directory=str(_templates_dir))


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
    request: Request,
    code: str,
    state: str,
    server: OAuthServer = Depends(get_oauth_server),
):
    accept = request.headers.get("accept", "")

    try:
        account = await server.handle_callback(code, state)
    except ValueError as exc:
        if "text/html" in accept:
            return templates.TemplateResponse(
                request,
                "oauth_callback.html",
                {"error": str(exc)},
            )
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    # Return HTML for browser requests (popup flow)
    if "text/html" in accept:
        return templates.TemplateResponse(
            request,
            "oauth_callback.html",
            {"email": account.get("email", ""), "error": None},
        )

    # Return JSON for API requests (backward compatible)
    return {"status": "stored", "account": account}


@router.get("/google-oauth/accounts")
async def list_oauth_accounts(server: OAuthServer = Depends(get_oauth_server)):
    """List OAuth accounts (emails only, no tokens exposed)."""
    accounts = server.account_store.load_accounts()
    return {
        "accounts": [
            {"email": acc.get("email"), "project_id": acc.get("project_id")} for acc in accounts
        ]
    }


@router.delete("/google-oauth/accounts/{email}")
async def delete_oauth_account(
    email: str,
    server: OAuthServer = Depends(get_oauth_server),
):
    """Remove an OAuth account."""
    accounts = server.account_store.load_accounts()
    original_count = len(accounts)
    accounts = [acc for acc in accounts if acc.get("email") != email]

    if len(accounts) == original_count:
        raise HTTPException(status_code=404, detail="Account not found")

    server.account_store.save_accounts(accounts)
    return {"status": "deleted", "email": email}
