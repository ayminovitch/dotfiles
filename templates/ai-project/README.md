# __PROJECT__

TODO: what this project does, for whom, and why it matters (2–3 sentences).

## Quick start

```bash
secret set ANTHROPIC_API_KEY   # once per key: stored in the macOS Keychain, loaded by .envrc
direnv allow                   # load .env + keys whenever you cd here (newproj did this)
uv sync                        # install dependencies
just db                   # start Postgres + pgvector (optional)
just dev                  # API on http://localhost:8000, docs at /docs
```

## Switch AI provider

Change one line in `.env`, no code changes. Free tiers have daily request limits, and some
(Gemini outside the EU/UK) may use your prompts to improve their models: send no private data.
Check each provider's model list for current names.

```bash
# Free
LLM_MODEL=ollama/gemma4:12b                  # local, private, offline (ollama pull gemma4:12b)
LLM_MODEL=gemini/<flash-model>               # free tier, no card: aistudio.google.com → secret set GEMINI_API_KEY
LLM_MODEL=groq/<model>                       # free tier, very fast: console.groq.com → secret set GROQ_API_KEY
LLM_MODEL=openrouter/<vendor>/<model>:free   # free models: openrouter.ai → secret set OPENROUTER_API_KEY
# Paid
LLM_MODEL=anthropic/<model>                  # secret set ANTHROPIC_API_KEY
LLM_MODEL=openai/<model>                     # secret set OPENAI_API_KEY
```

## Development

| Command      | What it does                         |
|--------------|--------------------------------------|
| `just test`  | Run tests                            |
| `just lint`  | Ruff lint + format check + mypy      |
| `just fmt`   | Auto-fix and format                  |
| `just check` | Everything CI runs                   |
| `just eval`  | Quality evals with the real model    |
| `just docker`| Build and run the production image   |

## See every LLM call (optional)

```bash
langfuse up      # local Langfuse dashboard in Docker → http://localhost:3000
langfuse keys    # paste the 3 lines into .env and every call gets traced
```

## Stack

Python 3.12 · uv · FastAPI · Pydantic · Postgres + pgvector · Ollama / hosted LLMs · Docker · GitHub Actions
