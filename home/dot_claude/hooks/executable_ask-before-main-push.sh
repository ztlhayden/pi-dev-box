#!/usr/bin/env bash
# PreToolUse hook for Bash: ask before a push that names main or master, except in ~/code/ai-notes,
# ~/code/ztlhayden/hayden-skills and ~/code/ztlhayden/pi-dev-box (or a worktree of one), which
# agents own. Best effort: it reads the repo from `git -C <dir>`, a leading `cd <dir>`,
# or the session's working directory. Anything it cannot place counts as another repo.
set -euo pipefail

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
cwd=$(jq -r '.cwd // ""' <<<"$input")

grep -Eq 'git( -C [^ ]+)? push' <<<"$cmd" || exit 0
grep -Eq '\b(main|master)\b' <<<"$cmd" || exit 0

dir=$cwd
if [[ $cmd =~ git\ -C\ ([^ ]+)\ push ]]; then
  dir=${BASH_REMATCH[1]}
elif [[ $cmd =~ ^cd\ ([^ ;&]+)\ *(\&\&|\;) ]]; then
  dir=${BASH_REMATCH[1]}
fi
dir=${dir/#\~/$HOME}
[[ $dir == /* ]] || dir="$cwd/$dir"

# The main clone's folder, also from one of its worktrees.
common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
top=${common%/.git}
case $top in
  "$HOME/code/ai-notes" | "$HOME/code/ztlhayden/hayden-skills" | "$HOME/code/ztlhayden/pi-dev-box") exit 0 ;;
esac

jq -n '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "ask",
  permissionDecisionReason: "Push to main or master needs a specific OK (ai-notes, hayden-skills and pi-dev-box are exempt)"
}}'
