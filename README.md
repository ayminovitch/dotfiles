# dotfiles

[![ci](https://github.com/ayminovitch/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/ayminovitch/dotfiles/actions/workflows/ci.yml)

My Mac setup for backend and AI work. One script takes a fresh MacBook to a working machine in
about half an hour: Python with uv, Claude Code and Gemini CLI with my own rules and skills,
local models through Ollama, and a project template that has evals and tracing from day one.

It runs on a 16 GB M1 Pro, so a lot of the choices (OrbStack instead of Docker Desktop, 12B
models, uv instead of conda) come from not having RAM to spare.

![VS Code with my Archipelago Dark theme](docs/vscode.png)

## Install

On a new Mac:

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)" && brew install gh && gh auth login
gh repo clone ayminovitch/dotfiles ~/dotfiles     # or your fork
bash ~/dotfiles/scripts/bootstrap.sh
```

`bootstrap.sh` asks before every step and skips anything that's already done, so you can run it
on a machine that's already set up. Anything it replaces gets a `.backup-<timestamp>` copy.
Afterwards open LuLu and BlockBlock once so macOS lets them run, then check everything with
`ai-doctor`.

The repo has to live in `~/dotfiles`.

## Make it yours

Nothing personal is committed. Your own stuff goes in files that stay on your Mac, and
bootstrap creates them from the examples:

| File | What goes in it |
|---|---|
| `~/.zshrc.local` | aliases, extra paths, `CODE_DIR` (where your code lives) and `NEWPROJ_DIR` |
| `~/.config/dotfiles/about-me.md` | a few lines about you and your machine, read by both coding agents |
| `~/.gitconfig` | your name, email and signing key (`git/gitconfig` only holds shared settings) |
| Keychain | API keys, via `secret set NAME` |

Then edit `Brewfile.apps` (my everyday apps) and `vscode/extensions.txt` to taste.

## What's in here

```
Brewfile             CLI tools, Ollama, Gemini CLI, VS Code, OrbStack, LuLu, BlockBlock
Brewfile.apps        apps I use every day (optional)
zsh/                 zshrc (oh-my-zsh + Powerlevel10k), zprofile, p10k config
git/                 shared git config (delta for diffs, rebase on pull, zdiff3 conflicts)
vscode/              settings, extensions, Python file templates, PyCharm-style look
jetbrains/           PyCharm plugins to install, and built-in ones to keep switched off
agents/              rules and skills for Claude Code and Gemini CLI
claude/              Claude Code settings, hooks, status line, reviewer subagent
templates/ai-project the Python project template used by newproj
bin/                 the commands below
scripts/             bootstrap, SSH key setup, CI checks
macos/defaults.sh    a few Finder and keyboard tweaks (optional)
```

## Commands

| Command | What it does |
|---|---|
| `newproj rag-bot` | new Python/AI project from the template |
| `secret set GROQ_API_KEY` | store an API key in the Keychain (`secret list` to see them) |
| `agent-sync` | push rules, skills and settings to both agents |
| `ai-doctor` | health check: security, toolchain, agents, models |
| `dotup` | update everything, then run ai-doctor (I do it weekly) |
| `sandbox <git-url>` | open a repo I don't trust in a throwaway container |
| `langfuse up` | local dashboard of every LLM call |
| `vscode-sync` | make VS Code's extensions match `extensions.txt` |
| `charm .` | open the current folder in PyCharm |
| `pycharm-sync` | make PyCharm's plugins match `jetbrains/plugins.txt` (`--save` to update the list) |

## Editors

I write Python in PyCharm and use VS Code for everything else. PyCharm indexes the project and
every installed package, so it offers the import for any name as soon as I type it, which
Pylance never quite matched.

PyCharm comes from JetBrains Toolbox (in `Brewfile.apps`). Two parts keep it the same on every
Mac:

- plugins: `jetbrains/plugins.txt`, a short list with a note on why each one is there. A line
  is a plugin ID or the number from its Marketplace link. `pycharm-sync` installs what's missing
  and asks before moving any other plugin to the Trash (never PyCharm's own, or ones a listed
  plugin needs). Quit PyCharm first, it can't change plugins while it's open. After adding or
  removing one in PyCharm, `pycharm-sync --save` updates the list and keeps the notes
- built-in plugins I don't use (JavaScript, CSS, remote development, language packs...):
  `jetbrains/disabled.txt`, applied by the same `pycharm-sync` and saved by the same `--save`.
  It never switches off Python or the SSH plugin Python needs, and switches them back on if
  they were turned off by mistake
- settings (theme, keymap, code style, actions on save): Settings → Backup and Sync, signed in
  with a JetBrains account, with its Plugins box unticked so it doesn't fight `plugins.txt`
  (a plugin removed while it syncs plugins also gets disabled in your other JetBrains IDEs).
  I keep settings out of git on purpose: PyCharm rewrites its config files, and their folder
  changes with every version

For a project made with `newproj`:

- open it with `charm .`. PyCharm usually finds the project's `.venv` on its own; if not, click
  the interpreter in the status bar and add the existing one
- Ruff: Settings → Python → Tools → External Tools, turn Ruff on with formatting and import
  sorting, then Settings → Tools → Actions on Save → Reformat code and Optimize imports
- Claude Code: the Claude Code plugin from the Marketplace, or just `claude` in the terminal tab.
  So Esc reaches Claude instead of jumping to the editor: Settings → Tools → Terminal, untick
  "Move focus to the editor with Escape"
- on battery: File → Power Save Mode pauses background inspections until you turn it off

## Coding agents

Both agents read `agents/AGENTS.md`: how I want projects handled, my defaults for new Python
projects, and the security rules. A project's own AGENTS.md always wins, and in an existing repo
they follow that repo's tools instead of mine.

Skills (they load when the task matches, or call one with `/name` in Claude Code):

- `mentor` teaches step by step instead of dumping code
- `repo-audit` reads an unknown repo for install hooks and stealer code without running it
- `repo-onboard` writes an AGENTS.md for an existing project, in any language, optionally
  kept out of git for client repos
- `handoff` saves where a task stands to `PLAN.md`, so the next session (or another agent) picks
  it up without the old chat
- `code-review`, also used by the `reviewer` subagent before I commit
- `llm-feature`, `rag`, `llm-evals`, `mcp-server`, `ai-agent` for building AI features
- `deploy-aws` (ECS Express Mode, GitHub Actions with OIDC), `mlx-finetune` (LoRA on the Mac),
  `interview-prep`

Claude Code also gets:

- a sandbox: its shell commands can't read `~/.ssh`, `~/.aws`, `gh` or Docker credentials, or
  `.env`, and API keys are stripped from their environment
- a status line with model, context used and plan limits, so I know when to `/clear`
- hooks that run ruff on Python files it edits (only in projects that use ruff) and send a
  notification when it's waiting for me

## Project template

```bash
newproj invoice-rag
cd ~/Projects/invoice-rag
just dev        # FastAPI on :8000
just check      # ruff, mypy, pytest, same as CI
just eval       # evals against a real model
```

FastAPI, LiteLLM, pydantic-settings, pytest, an eval set, optional Langfuse tracing, a non-root
Dockerfile, pre-commit with gitleaks, GitHub Actions. The model is one line in `.env`, and the
free options work out of the box:

```bash
LLM_MODEL=ollama/gemma4:12b                  # local
LLM_MODEL=gemini/<flash-model>               # Google AI Studio free tier
LLM_MODEL=groq/<model>                       # Groq free tier
LLM_MODEL=openrouter/<vendor>/<model>:free   # OpenRouter free models
```

## Security

I treat my laptop as a target, because developers are one:

- unknown repos (take-home tests from strangers especially) get `repo-audit` first and only ever
  run inside `sandbox`; VS Code won't auto-run tasks when a folder opens, and PyCharm asks
  before trusting a new project
- API keys live in the Keychain, not in files; `ai-doctor` flags any `.env` that still has one
- gitleaks runs before every commit, and commits are signed with an SSH key
  (`scripts/new-ssh-key.sh`)
- LuLu asks before unknown apps connect out, BlockBlock warns when something installs itself
  to run at login

## License

MIT. Take whatever's useful.
