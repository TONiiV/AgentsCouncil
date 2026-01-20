---
name: Multi-Agent Development Patterns
description: Patterns and best practices for building multi-agent AI systems with provider abstraction, async orchestration, and testing strategies
---

# Multi-Agent Development Patterns

This skill provides patterns and best practices for working with the AgentsCouncil multi-agent AI debate system.

## Provider Pattern

All AI providers (OpenAI, Anthropic, Gemini) implement a common interface, allowing easy switching and parallel execution.

### Base Provider Interface

```python
from abc import ABC, abstractmethod

class BaseProvider(ABC):
    """Abstract base class for AI providers."""

    @abstractmethod
    async def generate(
        self,
        prompt: str,
        system_prompt: str = "",
        temperature: float = 0.7,
        max_tokens: int = 1000,
    ) -> str:
        """Generate a response from the AI model."""
        pass

    @abstractmethod
    def is_available(self) -> bool:
        """Check if the provider is configured and available."""
        pass
```

### Provider Registration Pattern

```python
class ProviderRegistry:
    """Central registry for AI providers."""

    _providers: dict[ProviderType, BaseProvider] = {}

    @classmethod
    def register(cls, provider_type: ProviderType, provider: BaseProvider) -> None:
        cls._providers[provider_type] = provider

    @classmethod
    def get(cls, provider_type: ProviderType) -> BaseProvider:
        provider = cls._providers.get(provider_type)
        if not provider or not provider.is_available():
            raise ProviderNotAvailable(f"{provider_type} is not configured")
        return provider

    @classmethod
    def get_available(cls) -> list[ProviderType]:
        return [pt for pt, p in cls._providers.items() if p.is_available()]
```

## Async Debate Orchestration

### Running Parallel Agent Responses

```python
import asyncio
from typing import Sequence

async def run_debate_round(
    agents: Sequence[AgentConfig],
    topic: str,
    context: list[str],
) -> list[AgentResponse]:
    """Run a single debate round with parallel agent responses."""

    # Create tasks for all agents
    tasks = [
        generate_agent_response(agent, topic, context)
        for agent in agents
    ]

    # Gather with return_exceptions to handle partial failures
    results = await asyncio.gather(*tasks, return_exceptions=True)

    responses = []
    for agent, result in zip(agents, results):
        if isinstance(result, Exception):
            # Handle failed agent gracefully
            responses.append(create_error_response(agent, result))
        else:
            responses.append(result)

    return responses
```

### Streaming with WebSocket

```python
async def stream_debate_updates(
    websocket: WebSocket,
    debate: Debate,
) -> None:
    """Stream debate updates to connected clients."""

    async for event in debate.events():
        update = DebateUpdate(
            debate_id=debate.id,
            event_type=event.type,
            data=event.data,
        )
        await websocket.send_json(update.model_dump())
```

## Error Handling for AI APIs

### Retry Strategy with Exponential Backoff

```python
import asyncio
from typing import TypeVar, Callable, Awaitable

T = TypeVar('T')

async def retry_with_backoff(
    func: Callable[[], Awaitable[T]],
    max_retries: int = 3,
    base_delay: float = 1.0,
    max_delay: float = 30.0,
    retryable_exceptions: tuple = (RateLimitError, TimeoutError),
) -> T:
    """Execute async function with exponential backoff retry."""

    last_exception = None

    for attempt in range(max_retries):
        try:
            return await func()
        except retryable_exceptions as e:
            last_exception = e
            if attempt < max_retries - 1:
                delay = min(base_delay * (2 ** attempt), max_delay)
                await asyncio.sleep(delay)

    raise last_exception
```

### Provider-Specific Error Handling

```python
from enum import Enum

class ProviderErrorType(Enum):
    RATE_LIMIT = "rate_limit"
    TIMEOUT = "timeout"
    INVALID_REQUEST = "invalid_request"
    MODEL_OVERLOADED = "model_overloaded"
    AUTHENTICATION = "authentication"
    UNKNOWN = "unknown"

def classify_provider_error(error: Exception, provider: ProviderType) -> ProviderErrorType:
    """Classify provider errors for appropriate handling."""
    error_msg = str(error).lower()

    if "rate limit" in error_msg or "429" in error_msg:
        return ProviderErrorType.RATE_LIMIT
    elif "timeout" in error_msg:
        return ProviderErrorType.TIMEOUT
    elif "401" in error_msg or "authentication" in error_msg:
        return ProviderErrorType.AUTHENTICATION
    elif "overloaded" in error_msg or "503" in error_msg:
        return ProviderErrorType.MODEL_OVERLOADED
    else:
        return ProviderErrorType.UNKNOWN
```

## Testing Non-Deterministic AI Outputs

### Mocking Provider Responses

```python
import pytest
from unittest.mock import AsyncMock

@pytest.fixture
def mock_openai_provider():
    """Create a mock OpenAI provider for testing."""
    mock = AsyncMock(spec=OpenAIProvider)
    mock.generate.return_value = "This is a test response from the AI."
    mock.is_available.return_value = True
    return mock

@pytest.mark.asyncio
async def test_debate_round_uses_all_agents(mock_openai_provider, monkeypatch):
    """Test that a debate round calls all agents."""
    monkeypatch.setattr(
        ProviderRegistry,
        "get",
        lambda _: mock_openai_provider
    )

    agents = [
        AgentConfig(name="Agent1", provider=ProviderType.OPENAI, role=RoleType.INVESTMENT_ADVISOR),
        AgentConfig(name="Agent2", provider=ProviderType.OPENAI, role=RoleType.LEGAL_ADVISOR),
    ]

    responses = await run_debate_round(agents, "Test topic", [])

    assert len(responses) == 2
    assert mock_openai_provider.generate.call_count == 2
```

### Testing Vote Aggregation

```python
@pytest.mark.parametrize("votes,expected_consensus", [
    ({"1": VoteType.AGREE, "2": VoteType.AGREE, "3": VoteType.AGREE}, True),
    ({"1": VoteType.AGREE, "2": VoteType.AGREE, "3": VoteType.DISAGREE}, False),
    ({"1": VoteType.AGREE, "2": VoteType.ABSTAIN}, True),  # 100% of non-abstaining
])
def test_consensus_calculation(votes, expected_consensus):
    """Test consensus reaches expected result based on votes."""
    result = check_consensus(votes, threshold=0.8)
    assert result == expected_consensus
```

### Integration Test Pattern

```python
@pytest.mark.integration
@pytest.mark.skipif(
    not os.getenv("OPENAI_API_KEY"),
    reason="OPENAI_API_KEY not set"
)
@pytest.mark.asyncio
async def test_real_openai_integration():
    """Integration test with real OpenAI API - run manually."""
    provider = OpenAIProvider()
    response = await provider.generate(
        prompt="Say 'Hello, test passed!'",
        max_tokens=20,
    )
    assert "hello" in response.lower()
```

## Flutter State Management for Debates

### Riverpod Provider for Debate State

```dart
@riverpod
class DebateNotifier extends _$DebateNotifier {
  @override
  FutureOr<Debate?> build(String debateId) async {
    // Fetch initial debate state
    final api = ref.read(apiServiceProvider);
    return await api.getDebate(debateId);
  }

  Future<void> startDebate() async {
    final debate = await future;
    if (debate == null) return;

    state = const AsyncLoading();
    try {
      final api = ref.read(apiServiceProvider);
      final updated = await api.startDebate(debate.id);
      state = AsyncData(updated);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
```

### WebSocket Updates Integration

```dart
@riverpod
Stream<DebateUpdate> debateUpdates(Ref ref, String debateId) {
  final wsService = ref.read(websocketServiceProvider);
  return wsService.debateUpdates(debateId);
}

// In widget
ref.listen(debateUpdatesProvider(debateId), (_, next) {
  next.whenData((update) {
    // Handle real-time update
    ref.invalidate(debateProvider(debateId));
  });
});
```

## Prompts for AI Roles

When implementing new agent roles, follow this pattern:

```python
ROLE_PROMPTS: dict[RoleType, str] = {
    RoleType.INVESTMENT_ADVISOR: """You are an Investment Advisor with expertise in...

    When analyzing topics:
    1. Consider ROI and financial implications
    2. Evaluate risk factors
    3. Reference market trends when relevant
    4. Be data-driven in your analysis

    Voting guidelines:
    - AGREE if financially sound with manageable risk
    - DISAGREE if financially risky or poor ROI
    - ABSTAIN if outside your expertise
    """,
}
```

## Checklist for New Features

When adding features to the multi-agent system:

- [ ] Follow the provider pattern for new AI integrations
- [ ] Use async/await consistently
- [ ] Handle provider errors with appropriate retry logic
- [ ] Add unit tests with mocked providers
- [ ] Update WebSocket events if adding new debate states
- [ ] Document new role prompts
- [ ] Consider consensus implications of new vote types
