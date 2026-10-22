# __PROJECT__: notes for coding agents

## Commands
- Install: `uv sync`
- Run API: `just dev` (http://localhost:8000, docs at /docs)
- Test: `just test` · Lint + types: `just lint` · Auto-fix: `just fmt`
- Quality evals (real model calls): `just eval`. Run it after changing prompts, models or retrieval.
  It needs API keys, which agents' sandboxes hide on purpose: ask me to run it.
- Before finishing any task: `just check` must pass.
- Database (Postgres + pgvector): `just db`

## Layout
- `src/__PKG__/`: application code (`main.py` = FastAPI app, `config.py` = settings,
  `llm.py` = `complete()` / `complete_json()` for any model provider)
- `tests/`: pytest tests, same structure as `src/`
- `evals/`: `cases.jsonl` and the runner. Add a case for every bad answer you fix

## Rules
- Add dependencies with `uv add <pkg>` (dev tools: `uv add --dev <pkg>`); never edit `uv.lock` by hand.
- Type hints on every function; `mypy --strict` must pass.
- Settings come from `config.get_settings()`; never read `os.environ` directly.
- Call models through `llm.complete()` or `llm.complete_json(prompt, Model)` (LiteLLM). Never import
  a provider SDK directly, so the provider stays a one-line `LLM_MODEL` change in `.env`.
- Never hard-code or log secrets. New settings go in `config.py` **and** `.env.example`; new API
  keys go in `.envrc` (`secret env …`) and are stored with `secret set`, never in `.env`.
- Every new endpoint or pipeline step gets a test.
