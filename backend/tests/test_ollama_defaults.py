from app.providers.ollama_provider import OllamaProvider


def test_ollama_default_model_is_qwen3_8b():
    provider = OllamaProvider(base_url="http://localhost:11434/api")
    assert provider.default_model == "qwen3:8b"
