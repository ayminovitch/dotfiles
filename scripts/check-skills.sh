#!/bin/bash
# Check that every skill loads in Claude Code and Gemini CLI: SKILL.md starts with frontmatter,
# `name` matches the folder, and there's a description of 1-1024 characters. CI runs this.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

errors=0
fail() { printf '✗ %s\n' "$*"; errors=$((errors + 1)); }

for dir in agents/skills/*/; do
  folder="$(basename "$dir")"
  file="$dir/SKILL.md"
  [ -f "$file" ] || { fail "$folder: no SKILL.md"; continue; }
  [ "$(head -1 "$file")" = "---" ] || { fail "$folder: SKILL.md must start with '---' frontmatter"; continue; }
  front="$(awk 'NR == 1 { next } /^---$/ { exit } { print }' "$file")"
  name="$(printf '%s\n' "$front" | sed -n 's/^name:[[:space:]]*//p' | head -1)"
  desc="$(printf '%s\n' "$front" | sed -n 's/^description:[[:space:]]*//p' | head -1)"
  [ "$name" = "$folder" ] || fail "$folder: name is '$name', must match the folder name"
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "$folder: name must be lowercase words joined by dashes"
  if [ -z "$desc" ]; then fail "$folder: description is missing"
  elif [ "${#desc}" -gt 1024 ]; then fail "$folder: description is ${#desc} characters (max 1024)"
  else printf '✓ %s\n' "$folder"; fi
done

[ "$errors" -eq 0 ] || { printf '%d problem(s)\n' "$errors"; exit 1; }
