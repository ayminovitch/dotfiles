---
name: repo-audit
description: Statically inspect an untrusted repository (job-interview take-home, GitHub project, npm/PyPI package, coding test) for malware BEFORE anything is installed or run — install hooks, auto-run editor tasks, obfuscated code, credential or crypto-wallet theft. Use when the user asks whether a repo or package is safe, or is about to run code from someone they don't know.
---

# Untrusted repository audit

Fake recruiters send "take-home tests" whose code steals SSH keys, browser passwords and crypto
wallets the moment you run `npm install`, open the folder in VS Code, or start the app. Your
job: find out what the code would do **without running any of it**.

## Hard rules

- **Never execute anything from the repo**: no `npm/pnpm/yarn install`, `pip install`,
  `uv sync`, `make`, `docker build`, `node`, `python`, tests, or scripts. Reading files is safe.
- Cloning is fine (`git clone --depth 1 <url> /tmp/audit-<name>`); git does not run a repo's
  own hooks on clone. Never clone it into your projects folder or open it in VS Code before the verdict.
- Do not "decode and run" obfuscated code to see what it does. Decode it as text only
  (base64/hex → print), never pipe it into an interpreter.

## Checklist (search with Grep/Read, cite `file:line` for every finding)

1. **Runs on install** — `package.json` `preinstall` / `install` / `postinstall` / `prepare`
   scripts; `setup.py`, `pyproject.toml` build hooks, `Makefile` default target; dependencies
   pulled from git URLs, tarballs or odd registries; typo-squatted package names.
2. **Runs on open** — `.vscode/tasks.json` with `"runOn": "folderOpen"`, `.vscode/settings.json`
   pointing at repo binaries, `.devcontainer` `postCreateCommand`, `.idea` run configs, git
   hooks under `.husky/`.
3. **Runs on start** — the entry point and every config file the framework loads
   (`next.config.*`, `tailwind.config.*`, `postcss.config.*`, `vite.config.*`, `babel.config.*`,
   `server.js`, `app.py`, `__init__.py`). Payloads often hide on one very long line or after
   hundreds of spaces to the right of normal code — check line lengths.
4. **Obfuscation** — `eval(`, `new Function(`, `Function("return this")`, `atob(`,
   `Buffer.from(…, 'base64'|'hex')`, `String.fromCharCode` chains, `\x` / `\u` escape soup,
   `exec(base64…)`, `__import__('base64')`, `marshal.loads`, `zlib.decompress`, minified code
   in a non-build folder, "images" or fonts (`.png`, `.woff`) that are really scripts.
5. **Process / network** — `child_process`, `exec`, `spawn`, `subprocess`, `os.system`,
   `curl … | sh`, requests to raw IP addresses, uncommon ports (e.g. 1224, 1244, 1245),
   paste sites, URL shorteners, Vercel/Netlify/ngrok hosts that download more code.
6. **What it touches** — `~/.ssh`, `~/.aws`, `~/.config/gh`, `.env`, macOS Keychain
   (`security find-generic-password`), browser profiles (`Login Data`, `Local State`,
   `Cookies`), wallet extensions and apps (MetaMask, Exodus, Phantom, Atomic), `Library/Application
   Support`, home-folder dot-directories it creates (e.g. `.n2`, `.n3`, `.npl`).
7. **Git history** — `git log --stat -5`: one huge "initial commit", recently added config
   files, author/date mismatches.

## Report format

**Verdict:** ✅ No red flags found / ⚠️ Suspicious / ⛔ Malicious — one sentence why.

**Findings:** table of severity · `file:line` · what it does (decoded if obfuscated).

**How to run it safely if they still need to:** the user's `sandbox <repo-url>` command
(throw-away Docker container, no access to their files) — never on the host. If the verdict is
⛔, say plainly: don't run it, delete the clone, and if anything was already run, rotate SSH
keys, GitHub/API tokens and browser-saved passwords, and move crypto to a new wallet.

"No red flags" is not a guarantee — say what you checked and what you could not (e.g. compiled
binaries, remote code it downloads later).
