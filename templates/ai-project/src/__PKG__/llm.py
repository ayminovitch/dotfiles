"""Call any LLM provider (local Ollama, free tiers or paid APIs) through one API.

Switch providers by changing LLM_MODEL in .env, no code changes:
    LLM_MODEL=ollama/gemma4:12b                  local, free, private
    LLM_MODEL=gemini/<flash-model>               free tier (Google AI Studio key, no card)
    LLM_MODEL=groq/<model-name>                  free tier, very fast (console.groq.com)
    LLM_MODEL=openrouter/<vendor>/<model>:free   free models (openrouter.ai/models?max_price=0)
    LLM_MODEL=openai/<model-name>                paid
    LLM_MODEL=anthropic/<model-name>             paid

Usage:
    from __PKG__.llm import complete, complete_json

    answer = complete("Summarize this contract in 3 bullets: ...")

    class Invoice(BaseModel):
        vendor: str
        total: float

    invoice = complete_json(f"Extract the invoice fields:\\n{text}", Invoice)  # validated object

Tracing: set LANGFUSE_PUBLIC_KEY / LANGFUSE_SECRET_KEY in .env and every call shows up in Langfuse.
"""

import functools
import json
import logging
import os
import time
from typing import Any

import litellm
from pydantic import BaseModel, SecretStr, ValidationError

from __PKG__.config import Settings, get_settings

logger = logging.getLogger(__name__)


def _credentials(model: str, settings: Settings) -> dict[str, str]:
    """API key / base URL for the provider named in `model` (prefix before the first '/')."""
    provider = model.split("/", 1)[0]
    if provider == "ollama":
        return {"api_base": settings.ollama_base_url}
    keys: dict[str, SecretStr | None] = {
        "openai": settings.openai_api_key,
        "anthropic": settings.anthropic_api_key,
        "gemini": settings.gemini_api_key,
        "groq": settings.groq_api_key,
        "openrouter": settings.openrouter_api_key,
    }
    key = keys.get(provider)
    if key is None or not key.get_secret_value():
        name = f"{provider.upper()}_API_KEY"
        raise ValueError(
            f"No API key configured for provider '{provider}' "
            f"(run `secret set {name}`, or set {name} in .env)"
        )
    return {"api_key": key.get_secret_value()}


def _messages(prompt: str, system: str | None) -> list[dict[str, str]]:
    messages = [{"role": "system", "content": system}] if system else []
    messages.append({"role": "user", "content": prompt})
    return messages


@functools.cache
def _setup_tracing() -> bool:
    """Send every call to Langfuse when both keys are set (LiteLLM reads them from os.environ)."""
    settings = get_settings()
    if not (settings.langfuse_public_key and settings.langfuse_secret_key):
        return False
    os.environ["LANGFUSE_PUBLIC_KEY"] = settings.langfuse_public_key
    os.environ["LANGFUSE_SECRET_KEY"] = settings.langfuse_secret_key.get_secret_value()
    os.environ["LANGFUSE_HOST"] = settings.langfuse_host
    if "langfuse_otel" not in litellm.callbacks:
        litellm.callbacks.append("langfuse_otel")
    logger.info("LLM tracing on → %s", settings.langfuse_host)
    return True


def _call(model: str, messages: list[dict[str, str]], **kwargs: Any) -> str:
    """One model call with timeout + retries; logs model, tokens and latency (never the prompt)."""
    _setup_tracing()
    started = time.perf_counter()
    response: Any = litellm.completion(
        model=model,
        messages=messages,
        timeout=60,
        num_retries=2,
        **_credentials(model, get_settings()),
        **kwargs,
    )
    usage = getattr(response, "usage", None)
    logger.info(
        "llm call model=%s tokens_in=%s tokens_out=%s seconds=%.2f",
        model,
        getattr(usage, "prompt_tokens", "?"),
        getattr(usage, "completion_tokens", "?"),
        time.perf_counter() - started,
    )
    return str(response.choices[0].message.content or "")


def complete(prompt: str, *, system: str | None = None, model: str | None = None) -> str:
    """Send one prompt and return the text answer."""
    return _call(model or get_settings().llm_model, _messages(prompt, system))


def _supports_schema(model: str) -> bool:
    try:
        return bool(litellm.supports_response_schema(model=model))
    except Exception:
        return False


def _strip_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else ""
        text = text.removesuffix("```")
    return text.strip()


def complete_json[T: BaseModel](
    prompt: str, schema: type[T], *, system: str | None = None, model: str | None = None
) -> T:
    """Ask for JSON matching `schema` and return it validated.

    Uses the provider's structured-output mode when it has one (OpenAI, Claude, Gemini) and
    plain JSON mode otherwise (Ollama). If the reply doesn't validate, the error is sent back
    once so the model can fix it; a second failure raises pydantic.ValidationError.
    """
    model = model or get_settings().llm_model
    rules = "Reply with only a JSON object that matches this JSON schema:\n" + json.dumps(
        schema.model_json_schema()
    )
    messages = _messages(prompt, f"{system}\n\n{rules}" if system else rules)
    response_format: Any = schema if _supports_schema(model) else {"type": "json_object"}

    for attempt in range(2):
        text = _strip_fences(_call(model, messages, response_format=response_format))
        try:
            return schema.model_validate_json(text)
        except ValidationError as exc:
            if attempt == 1:
                raise
            messages.append({"role": "assistant", "content": text})
            messages.append(
                {
                    "role": "user",
                    "content": f"That JSON was invalid: {exc}. Reply with fixed JSON only.",
                }
            )
    raise AssertionError("unreachable")
