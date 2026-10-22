---
name: code-review
description: Review uncommitted changes, a branch or a pull request for bugs, security holes, missing tests and LLM-specific pitfalls, and report findings ranked by severity with concrete fixes. Use when the user asks for a review, before committing or opening a PR, or when a feature is finished.
---

# Code review

Review like a senior engineer who will be paged when this breaks: find what can go wrong in
production, not style nits (the project's formatter, linter and type checker handle those).
Works for any language: use the project's own tools and conventions (see its `AGENTS.md`).

## 1. Get the change and its intent

- Uncommitted work: `git diff HEAD` (plus `git status` for new files — read them in full).
- A branch: `git diff main...HEAD` and `git log --oneline main..HEAD`.
- A PR: `gh pr diff <n>` and `gh pr view <n>` (read the description and linked issue).
- Read enough surrounding code to understand each change — callers, the tests, the config it uses.
  State the intent in one sentence before judging anything.

## 2. Run the checks

The project's lint, type and test commands — from its `AGENTS.md`, CI config or task runner
(`just check` in my Python template; `npm test`, `go test ./...`, `composer test`, … elsewhere).
Ask before running anything that needs a database, network or Docker. A red check is the first
finding. Never "fix" anything during a review — report it.

## 3. Look for, in this order

1. **Correctness** — wrong logic, unhandled `None`/empty/huge input, off-by-one, timezone and
   encoding bugs, broken error paths, race conditions, resources not closed.
2. **Security** — injection (SQL, shell, prompt), missing auth or ownership checks (can user A
   reach user B's data?), secrets in code/logs/prompts, unsafe deserialization, SSRF from
   user-supplied URLs, `eval`/`exec`/`subprocess` with untrusted input, new dependencies from
   unknown sources.
3. **LLM-specific** — model output used without validation; user or retrieved text able to
   override instructions; no timeout/retry/limit on model calls; unbounded loops in agents;
   prompts or completions logged at INFO; cost explosions (no max tokens, calls in loops);
   provider SDK imported directly instead of the project's `llm` module (skip this section when
   the change doesn't touch LLM code).
4. **Tests** — is the new behavior tested, including the main failure path? Would the test fail
   if the feature broke, or does it only test a mock?
5. **Operability** — useful logs and error messages, new settings documented (e.g. in
   `.env.example`), migrations safe to run on a live database, backwards-compatible API changes.
6. **Simplicity** — dead code, duplication, abstractions with one user, names that mislead.

## 4. Report

**Verdict:** ✅ Ready · ⚠️ Ready after fixes · ⛔ Needs rework — one sentence why.

Then findings, most severe first. For each:
- **Severity** (blocker / should-fix / consider) · `path/to/file:42`
- What goes wrong, as a concrete scenario ("a user who sends an empty list gets a 500 because…")
- The fix, as a short code snippet when it helps.

End with what is good about the change (one or two lines) and anything you could not verify.
Skip findings you are not confident about rather than padding the list.
