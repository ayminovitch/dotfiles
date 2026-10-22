import os
from collections.abc import Iterator
from types import SimpleNamespace
from typing import Any

import litellm
import pytest
from pydantic import BaseModel, SecretStr, ValidationError

from __PKG__ import llm
from __PKG__.config import Settings


def _fake_response(text: str) -> Any:
    return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=text))])


def _fake_completion(replies: list[str], calls: list[dict[str, Any]]) -> Any:
    def fake(**kwargs: Any) -> Any:
        calls.append(kwargs)
        return _fake_response(replies[len(calls) - 1])

    return fake


@pytest.fixture(autouse=True)
def _fresh_tracing_setup() -> Iterator[None]:
    llm._setup_tracing.cache_clear()
    yield
    llm._setup_tracing.cache_clear()


class Invoice(BaseModel):
    vendor: str
    total: float


@pytest.fixture
def anthropic_settings(monkeypatch: pytest.MonkeyPatch) -> Settings:
    settings = Settings(llm_model="anthropic/test-model", anthropic_api_key=SecretStr("sk-test"))
    monkeypatch.setattr(llm, "get_settings", lambda: settings)
    return settings


@pytest.mark.usefixtures("anthropic_settings")
def test_complete_routes_to_configured_provider(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[dict[str, Any]] = []
    monkeypatch.setattr(litellm, "completion", _fake_completion(["hello"], calls))

    answer = llm.complete("Hi", system="Be brief")

    assert answer == "hello"
    assert calls[0]["model"] == "anthropic/test-model"
    assert calls[0]["api_key"] == "sk-test"
    assert calls[0]["messages"][0] == {"role": "system", "content": "Be brief"}


@pytest.mark.usefixtures("anthropic_settings")
def test_complete_json_returns_validated_object(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[dict[str, Any]] = []
    reply = '```json\n{"vendor": "ACME", "total": 12.5}\n```'
    monkeypatch.setattr(litellm, "completion", _fake_completion([reply], calls))
    monkeypatch.setattr(litellm, "supports_response_schema", lambda **_: True)

    invoice = llm.complete_json("Extract: ACME, 12.50", Invoice)

    assert invoice == Invoice(vendor="ACME", total=12.5)
    assert calls[0]["response_format"] is Invoice


@pytest.mark.usefixtures("anthropic_settings")
def test_complete_json_repairs_invalid_reply_once(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[dict[str, Any]] = []
    replies = ['{"vendor": "ACME"}', '{"vendor": "ACME", "total": 3}']
    monkeypatch.setattr(litellm, "completion", _fake_completion(replies, calls))
    monkeypatch.setattr(litellm, "supports_response_schema", lambda **_: False)

    invoice = llm.complete_json("Extract", Invoice)

    assert invoice.total == 3
    assert len(calls) == 2
    assert calls[0]["response_format"] == {"type": "json_object"}
    assert "invalid" in calls[1]["messages"][-1]["content"]


@pytest.mark.usefixtures("anthropic_settings")
def test_complete_json_gives_up_after_second_invalid_reply(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[dict[str, Any]] = []
    monkeypatch.setattr(litellm, "completion", _fake_completion(["nope", "still nope"], calls))
    monkeypatch.setattr(litellm, "supports_response_schema", lambda **_: False)

    with pytest.raises(ValidationError):
        llm.complete_json("Extract", Invoice)
    assert len(calls) == 2


def test_ollama_needs_no_key() -> None:
    settings = Settings(llm_model="ollama/gemma4:12b")
    creds = llm._credentials(settings.llm_model, settings)
    assert creds == {"api_base": settings.ollama_base_url}


@pytest.mark.parametrize("key", [None, SecretStr("")])
def test_missing_key_gives_clear_error(key: SecretStr | None) -> None:
    settings = Settings(openai_api_key=key)
    with pytest.raises(ValueError, match="No API key configured for provider 'openai'"):
        llm._credentials("openai/some-model", settings)


@pytest.mark.parametrize(
    ("model", "field"),
    [
        ("gemini/some-flash-model", "gemini_api_key"),
        ("groq/some-model", "groq_api_key"),
        ("openrouter/vendor/some-model:free", "openrouter_api_key"),
    ],
)
def test_free_tier_providers_use_their_own_key(model: str, field: str) -> None:
    settings = Settings.model_validate({field: "free-key"})
    assert llm._credentials(model, settings) == {"api_key": "free-key"}


def test_missing_free_tier_key_names_the_variable() -> None:
    settings = Settings(groq_api_key=None)
    with pytest.raises(ValueError, match="secret set GROQ_API_KEY"):
        llm._credentials("groq/some-model", settings)


def test_tracing_turns_on_when_both_keys_are_set(monkeypatch: pytest.MonkeyPatch) -> None:
    callbacks: list[str] = []
    monkeypatch.setattr(litellm, "callbacks", callbacks)
    monkeypatch.setattr(os, "environ", dict(os.environ))
    settings = Settings(langfuse_public_key="pk-lf-1", langfuse_secret_key=SecretStr("sk-lf-1"))
    monkeypatch.setattr(llm, "get_settings", lambda: settings)

    assert llm._setup_tracing() is True
    assert callbacks == ["langfuse_otel"]
    assert os.environ["LANGFUSE_SECRET_KEY"] == "sk-lf-1"


def test_tracing_stays_off_without_keys(monkeypatch: pytest.MonkeyPatch) -> None:
    callbacks: list[str] = []
    monkeypatch.setattr(litellm, "callbacks", callbacks)
    monkeypatch.setattr(llm, "get_settings", lambda: Settings(langfuse_public_key="pk-lf-1"))

    assert llm._setup_tracing() is False
    assert callbacks == []
