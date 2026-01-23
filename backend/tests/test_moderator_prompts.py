import asyncio
from types import SimpleNamespace

from app.core.moderator import ModeratorService
from app.models import CouncilConfig, Debate, RoleType, ProviderType, AgentConfig


def _build_council() -> CouncilConfig:
    return CouncilConfig(
        name="Test Council",
        agents=[
            AgentConfig(
                name="Test Agent",
                provider=ProviderType.OLLAMA,
                role=RoleType.TECH_STRATEGIST,
            )
        ],
    )


def _build_debate() -> Debate:
    council_id = _build_council().id
    debate = Debate(council_id=council_id, topic="Test topic")
    return debate


def test_summary_prompt_enforces_length():
    captured = {}

    async def fake_generate(system_prompt: str, user_message: str, **_kwargs) -> str:
        captured["system_prompt"] = system_prompt
        captured["user_message"] = user_message
        return "summary"

    moderator = ModeratorService()
    moderator.provider = SimpleNamespace(generate=fake_generate)

    asyncio.run(moderator.generate_summary(_build_debate(), _build_council()))

    assert "200" in captured["user_message"]
    assert "200" in captured["system_prompt"]


def test_pro_prompt_enforces_length():
    captured = {}

    async def fake_generate(system_prompt: str, user_message: str, **_kwargs) -> str:
        captured["system_prompt"] = system_prompt
        captured["user_message"] = user_message
        return "1. pro"

    moderator = ModeratorService()
    moderator.provider = SimpleNamespace(generate=fake_generate)

    asyncio.run(moderator.extract_pro_points(_build_debate()))

    assert "200" in captured["user_message"]
    assert "200" in captured["system_prompt"]


def test_against_prompt_enforces_length():
    captured = {}

    async def fake_generate(system_prompt: str, user_message: str, **_kwargs) -> str:
        captured["system_prompt"] = system_prompt
        captured["user_message"] = user_message
        return "1. against"

    moderator = ModeratorService()
    moderator.provider = SimpleNamespace(generate=fake_generate)

    asyncio.run(moderator.extract_against_points(_build_debate()))

    assert "200" in captured["user_message"]
    assert "200" in captured["system_prompt"]
