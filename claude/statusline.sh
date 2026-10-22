#!/bin/bash
# Claude Code status line. Looks like:  Opus · my-app · ▓▓▓░░░░░░░ 31% 62k · 5h 23% · week 41%
#
# Claude Code pipes session info into this script as JSON and shows whatever it prints.
# Runs locally, costs no tokens. Docs: https://code.claude.com/docs/en/statusline
#
# The bar goes yellow at 50% and red at 70%, with a nudge to /compact or /clear. On 1M-context
# models it also goes by token count (yellow at 100k, red at 140k) because long contexts get
# expensive and the answers get worse. The end shows the 5-hour and weekly plan limits, or the
# session cost if you're on an API key.
export LC_ALL=C   # so printf "%.2f" reads 0.42 the same way in every locale

input="$(cat)"
command -v jq >/dev/null || { echo "Claude Code (brew install jq for the full status line)"; exit 0; }

# One jq call. Fields are joined with \x1f so an empty value doesn't shift the rest
IFS=$'\x1f' read -r model project pct used five week cost < <(
  jq -r '
    def num: if . == null or . == "" then "" else floor end;
    [ (.model.display_name // "Claude"),
      ((.workspace.project_dir // .workspace.current_dir // "") | split("/") | last // ""),
      (.context_window.used_percentage // 0 | floor),
      (.context_window.total_input_tokens // 0),
      (.rate_limits.five_hour.used_percentage | num),
      (.rate_limits.seven_day.used_percentage | num),
      (.cost.total_cost_usd // 0)
    ] | map(tostring) | join("\u001f")' <<<"$input" 2>/dev/null
)
model="${model:-Claude}"; pct="${pct:-0}"; used="${used:-0}"; cost="${cost:-0}"

dim=$'\033[2m'; green=$'\033[32m'; yellow=$'\033[33m'; red=$'\033[31m'; reset=$'\033[0m'
sep=" ${dim}·${reset} "
level() { if [ "$1" -ge "$3" ]; then printf '%s' "$red"; elif [ "$1" -ge "$2" ]; then printf '%s' "$yellow"; else printf '%s' "$4"; fi; }

# "heat" is whichever is worse: % of the window, or tokens where 200k counts as 100
heat=$pct
(( used / 2000 > heat )) && heat=$(( used / 2000 ))
color="$(level "$heat" 50 70 "$green")"
filled=$(( (pct + 5) / 10 )); (( filled > 10 )) && filled=10
bar=""
for i in 1 2 3 4 5 6 7 8 9 10; do
  if (( i <= filled )); then bar+="▓"; else bar+="░"; fi
done
context="${color}${bar} ${pct}%${reset}"
(( used >= 1000 )) && context+=" ${dim}$(( used / 1000 ))k${reset}"
(( heat >= 70 )) && context+=" ${red}→ /compact or /clear${reset}"

# Plan limits on Pro/Max, session cost on an API key
if [ -n "$five" ]; then
  limits="$(level "$five" 70 90 "$dim")5h ${five}%${reset}"
  [ -n "$week" ] && limits+="${sep}$(level "$week" 70 90 "$dim")week ${week}%${reset}"
else
  limits="${dim}$(printf '$%.2f' "$cost")${reset}"
fi

out="${model}"
[ -n "$project" ] && out+="${sep}${project}"
printf '%s\n' "${out}${sep}${context}${sep}${limits}"
