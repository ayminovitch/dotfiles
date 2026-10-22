#!/bin/bash
# Notification hook: a macOS notification when Claude Code needs me (a permission prompt, or it's
# done and waiting). The text is passed as arguments instead of being pasted into the
# AppleScript, so a quote in the message can't break it.
input="$(cat)"
message="$(printf '%s' "$input" | jq -r '.message // "Claude Code needs your attention"' 2>/dev/null)"
project="$(basename "$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)")"
osascript \
  -e 'on run argv' \
  -e 'display notification (item 1 of argv) with title "Claude Code" subtitle (item 2 of argv) sound name "Glass"' \
  -e 'end run' \
  "${message:-Claude Code needs your attention}" "${project:-}" >/dev/null 2>&1
exit 0
