---
name: repo-onboard
description: Prepare an existing repository in any language or framework for AI coding agents — write one short AGENTS.md (read by Claude Code, Gemini CLI and Codex) with the project's real commands, layout and conventions, committed or kept local-only for client and team repos. Use when the user starts working in an existing project, asks to onboard or set up a repo for agents, or a repo has no AGENTS.md.
---

# Onboard an existing repo

Goal: one short, accurate `AGENTS.md`, so every agent works the project's way from the first
message instead of re-exploring the repo (and burning tokens) every session.

## 0. Safety

If the repo isn't the user's or their team's (recruiter test, random GitHub project), use the
`repo-audit` skill first and don't run any of its code on this Mac — only through `sandbox`.

## 1. One question

"Is this your own repo, or a client/team repo where AI files shouldn't be committed?"
→ **commit** or **local-only**.

## 2. Explore cheaply — read, don't run

Stop as soon as you have the facts:

1. Existing agent files: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.cursor/rules/`,
   `.cursorrules`, `.github/copilot-instructions.md`, `.windsurfrules`. Merge what's useful.
2. `README`, `CONTRIBUTING`.
3. CI config (`.github/workflows/`, `.gitlab-ci.yml`, …): the most reliable source of the real
   install, lint, test and build commands.
4. Manifests and task runners: `package.json` scripts, `pyproject.toml`, `composer.json`,
   `go.mod`, `Cargo.toml`, `pom.xml` / `build.gradle`, `Gemfile`, `*.csproj`, `Makefile`,
   `justfile`, `Taskfile.yml`, `docker-compose*.yml`.
5. Formatter and linter configs (ESLint, Biome, Prettier, ruff, PHP-CS-Fixer, golangci-lint,
   rustfmt, `.editorconfig`).
6. The shape of the code: `git ls-files | cut -d/ -f1-2 | sort | uniq -c | sort -rn | head -30`,
   then 2–3 representative files (one handler/controller/component, one test).

Skip lockfiles, generated code, vendored dependencies, build output and data files.

## 3. Write AGENTS.md — under 80 lines, facts only

```markdown
# <project>: instructions for AI coding agents

<One or two lines: what it does and for whom.>

## Stack
Language + version, framework, database, package manager, key libraries.

## Commands
- Install: …
- Run locally: …
- Test: all · one file · one test
- Lint + format: …
- Type check / build: …
- Before finishing a task: <what CI runs>

## Layout
- `dir/`: what lives there (only the important folders)

## Conventions
- Patterns to follow, as seen in the code: naming, error handling, logging, how tests are
  written, where new code goes.

## Don't
- Generated or vendored paths, migration rules, files owned by other teams, secrets.
```

- Write only what the repo shows. If unsure, write `TODO: confirm …`; never guess.
- The project's tools win over the user's personal defaults: npm and Jest stay npm and Jest,
  PHPUnit stays PHPUnit. Don't add uv, ruff, FastAPI or just to a project that doesn't use them.
- Monorepo: a short root `AGENTS.md` plus one per package folder; agents load the nearest one.

## 4. Verify the commands

Run the cheap, local ones (lint, unit tests). Ask first if a command needs a database, Docker,
network access, credentials or takes minutes. If a command fails because of missing setup, keep
it in `AGENTS.md` and tell the user what the setup needs.

## 5. Wire it up

Claude Code, Codex and Gemini CLI (with this Mac's settings) read `AGENTS.md` directly.

- If the repo already has a `CLAUDE.md`, Claude Code reads it **instead of** `AGENTS.md`:
  - commit mode: add the line `@AGENTS.md` to `CLAUDE.md` and move duplicated content out of it;
  - local-only mode: leave `CLAUDE.md` alone and create `CLAUDE.local.md` containing `@AGENTS.md`.
- **Local-only**: add these lines to `.git/info/exclude` (a personal ignore list that is never
  committed; don't touch the repo's `.gitignore`):
  ```
  AGENTS.md
  PLAN.md
  CLAUDE.local.md
  .claude/settings.local.json
  ```
  If the repo already tracks an `AGENTS.md`, edit nothing tracked; put personal notes in
  `CLAUDE.local.md` instead.
- **Commit**: `git add AGENTS.md` (and `CLAUDE.md` if changed),
  `docs: add AGENTS.md for AI coding agents`.
- Optional, to stop permission prompts for safe commands: allow them in
  `.claude/settings.json` (commit mode) or `.claude/settings.local.json` (local-only), e.g.
  `{"permissions": {"allow": ["Bash(npm test *)", "Bash(npm run lint *)"]}}`.
  Never allow deploys, database migrations against real databases, or `git push`.

## 6. Finish

Show the final `AGENTS.md`, say what is committed and what is local, and suggest starting a new
session (`/clear`) so it loads. For multi-session work, the `handoff` skill keeps `PLAN.md`.
