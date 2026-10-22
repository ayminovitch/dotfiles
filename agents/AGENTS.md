# How I work

Global instructions for my coding agents (Claude Code and Gemini CLI). `agent-sync` imports this
file from `~/.claude/CLAUDE.md` and `~/.gemini/GEMINI.md`, together with my private notes in
`~/.config/dotfiles/about-me.md`. If a project has its own AGENTS.md or CLAUDE.md, that wins.

## Existing projects first

In a repo that already exists, follow its language, tools and conventions (package manager,
formatter, test runner, framework, code style), even if they differ from my defaults below.
Don't add uv, ruff, FastAPI or just to a project that doesn't use them unless I ask.
No AGENTS.md yet? Offer the `repo-onboard` skill.

## Defaults for new Python projects

These apply to projects made with `newproj`.

- Python is managed with uv only: `uv add`, `uv run`, `uv sync`. Never `pip install` into a
  global interpreter. Python 3.12+, `src/` layout, type hints everywhere, Pydantic v2.
- Quality: ruff (lint and format), mypy, pytest. `just check` runs all three.
- Services: FastAPI with uvicorn. Settings come from the environment through pydantic-settings.
- Data: Postgres with pgvector for RAG, in Docker. Ollama on `http://localhost:11434` for
  local models and embeddings.
- Containers: multi-stage Dockerfile built with uv, non-root user, no secrets in the image.

## Engineering

- Write it like it's going to production: handle errors, put timeouts and retries on network
  calls, log in a structured way, validate input, and test the happy path plus the main
  failure path.
- Before saying a task is done, run the project's checks (whatever its CI runs).
- When there's a real choice, say what it costs: security, money, latency, scaling, upkeep.
- LLM features: prompts live in versioned files, log tokens and latency, and build a small
  eval set before tuning prompts.

## Context and sessions

- If the project has a `PLAN.md`, read it first. It's how sessions and agents hand work to each
  other. Keep it up to date with the `handoff` skill, and update it when I say "handoff".
- One task per session. When a task is done, or the context is past ~60%, suggest a handoff
  and `/clear` instead of carrying on.
- Read only what you need: search with `rg` before opening files, read big files in parts, and
  never paste lockfiles, generated code or long logs into the chat. Filter them first.
- Push noisy work (long test runs, digging through logs, broad searches, docs) to a subagent
  and keep only its summary.
- If a CLI does the job (`gh`, `aws`, `docker`), use it instead of an MCP server.

## Security

- Never print, log or commit secrets. In my projects API keys live in the macOS Keychain
  (`secret set NAME`) and `.envrc` loads them. `.env` only holds settings and is gitignored;
  `.env.example` only has placeholders.
- Shell commands run inside Claude Code's sandbox, which hides API keys and credential files on
  purpose. Don't try to get around it. If something needs a key (evals, deploys), ask me to
  run it.
- Never run code from a repo I don't trust (take-home tests from strangers, random GitHub
  projects) directly on the Mac. Check it with the `repo-audit` skill first, then only run it
  with `sandbox <repo-url>`, which uses a throwaway container.
- Ask before anything destructive: deleting files, force-pushing, dropping data.

## Skills

They live in `~/dotfiles/agents/skills`. Use one when the task matches:
`mentor`, `repo-audit`, `repo-onboard`, `handoff`, `code-review`, `llm-feature`, `rag`,
`llm-evals`, `mcp-server`, `ai-agent`, `deploy-aws`, `mlx-finetune`, `interview-prep`.

When a feature or fix is finished, ask the `reviewer` subagent to review it before committing.

## Style

- Explain the reasoning behind decisions that aren't obvious, briefly.
- Small commits with Conventional Commit messages (`feat:`, `fix:`, `chore:`, `docs:`,
  `test:`, `refactor:`).
