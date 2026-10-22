---
name: handoff
description: Save the current work state to PLAN.md so a fresh session — in Claude Code, Gemini CLI, Codex or a chat app — can continue without the old conversation, and resume from it later. Use when the user says handoff, wrap up, save progress, "I'll continue later", is switching agents or models, or the context is getting full; and when resuming ("continue", "pick up where we left off") in a repo that has PLAN.md.
---

# Handoff with PLAN.md

`PLAN.md` at the repo root is the project's working memory between sessions and between agents.
A fresh session that reads it should be able to continue within a minute, so it holds the
current **state**, not the history of the conversation.

## Writing it

1. **Check reality first**: `git status`, `git diff --stat`, `git log --oneline -5`, and the
   project's quick checks if they run fast. Write what is true now, not what was planned.
2. **Rewrite, don't append.** Replace stale lines, drop finished detail, keep it under ~60 lines.
   Link to files and functions instead of pasting code.
3. Use this shape:

```markdown
# Plan: <goal in one line>
_Updated <YYYY-MM-DD> by <agent/model>_

## Goal
What we're building and what "done" means (1–3 lines).

## Status
- Done: …
- In progress: … (file / function, and what's left)
- Broken: … (the exact failing test or error message)

## Next steps
1. The smallest concrete step, the file(s) to touch, and the command that proves it works
2. …

## Decisions
- <decision> — <why>, so the next session doesn't reopen it

## Gotchas
- What wasted time: setup quirks, flaky tests, misleading names, commands that don't work

## Key files
- `path/to/file` — what it is
```

4. **Never** put secrets, tokens, `.env` values, customer data or long logs in it.
5. **Tracked or local?** If `PLAN.md` is listed in `.git/info/exclude` or `.gitignore`, just save
   it. Otherwise commit it with the work (`chore: update plan`) unless the user says not to.
6. Finish with one line for the user: *Saved. Start the next session (any agent) with:
   "continue from PLAN.md"* — and suggest `/clear` (Claude Code and Gemini CLI) or a new chat.

## Resuming

1. Read `PLAN.md`, then compare it with `git status` and `git log --oneline -5`. If they
   disagree, the code is the truth: fix `PLAN.md` first.
2. Say the goal and the next step back in two lines, then start on step 1. Read only the files
   that step needs.
3. Update the Status section as steps finish, so a crash or a full context loses nothing.

## In a chat app (no file access)

Write the same sections as a message the user can paste into a new chat, ideally inside the
Project that holds the related files.
