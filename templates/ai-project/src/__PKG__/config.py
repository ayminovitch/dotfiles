"""Application settings, loaded from environment variables and `.env`.

API keys come from the environment (direnv loads them from the macOS Keychain via `.envrc`);
`.env` holds the other settings.
"""

from functools import lru_cache
from pathlib import Path

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


def _env_file() -> str | None:
    """Return ".env" if this process may read it.

    AI coding agents' sandboxes block reading `.env`; the app then runs on environment variables
    and defaults instead of crashing with PermissionError.
    """
    try:
        Path(".env").read_bytes()
    except OSError:
        return None
    return ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=_env_file(), env_file_encoding="utf-8", extra="ignore"
    )

    app_name: str = "__PROJECT__"
    environment: str = "local"
    log_level: str = "INFO"

    # Which model to use. Switching provider is just this one value (see llm.py)
    llm_model: str = "ollama/gemma4:12b"

    # LLM providers, all optional. Store the keys you use with `secret set <NAME>`.
    # Free tiers without a credit card: Gemini (Google AI Studio), Groq, OpenRouter ":free" models.
    openai_api_key: SecretStr | None = None
    anthropic_api_key: SecretStr | None = None
    gemini_api_key: SecretStr | None = None
    groq_api_key: SecretStr | None = None
    openrouter_api_key: SecretStr | None = None

    # Local models and vector store
    ollama_base_url: str = "http://localhost:11434"
    database_url: str = "postgresql://app:app@localhost:5432/__PKG__"

    # Tracing (optional): set both keys to send every LLM call to Langfuse. Run `langfuse up`
    # and `langfuse keys` for a local dashboard
    langfuse_public_key: str | None = None
    langfuse_secret_key: SecretStr | None = None
    langfuse_host: str = "http://localhost:3000"


@lru_cache
def get_settings() -> Settings:
    """Return settings once per process (cached)."""
    return Settings()
