#!/usr/bin/env bash
# PreToolUse hook for Bash: ask before a push that names main or master, except in ~/code/ai-notes,
# which agents own. Best effort: it reads the repo from `git -C <dir>`, a leading `cd <dir>`,
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

top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)
[[ $top == "$HOME/code/ai-notes" ]] && exit 0

jq -n '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "ask",
  permissionDecisionReason: "Push to main or master needs a specific OK (ai-notes is exempt)"
}}'
