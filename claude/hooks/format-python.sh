#!/bin/bash
# PostToolUse hook: after Claude edits a .py file, sort its imports and format it with ruff.
# Only in projects that already use ruff (ruff.toml or [tool.ruff] in pyproject.toml), so a
# client's black/isort codebase never gets reformatted. It never removes code (an import Claude
# adds now may be used in its next edit) and always exits 0 so it can't block Claude.
file="$(jq -r '.tool_input.file_path // empty' 2>/dev/null)"
case "$file" in *.py|*.pyi) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0

# walk up from the file to the repo root looking for ruff config
uses_ruff=""
dir="$(cd "$(dirname "$file")" && pwd)"
while [ -n "$dir" ]; do
  if [ -f "$dir/ruff.toml" ] || [ -f "$dir/.ruff.toml" ] \
    || grep -q '^\[tool\.ruff' "$dir/pyproject.toml" 2>/dev/null; then uses_ruff=1; break; fi
  [ -e "$dir/.git" ] && break
  dir="${dir%/*}"
done
[ -n "$uses_ruff" ] || exit 0

ruff="$(command -v ruff || echo "$HOME/.local/bin/ruff")"
[ -x "$ruff" ] || exit 0
"$ruff" check --select I --fix --quiet "$file" >/dev/null 2>&1
"$ruff" format --quiet "$file" >/dev/null 2>&1
exit 0
