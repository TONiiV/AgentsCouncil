"""Tests for application settings."""

from app.config import get_settings


def test_settings_has_supabase_config():
    """Verify Supabase configuration fields exist in settings."""
    settings = get_settings()
    assert hasattr(settings, "supabase_url")
    assert hasattr(settings, "supabase_service_role_key")
