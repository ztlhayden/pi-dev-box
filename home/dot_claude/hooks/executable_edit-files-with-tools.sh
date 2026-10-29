#!/usr/bin/env bash
# PreToolUse hook for Bash: send file edits to the Edit and Write tools. A script that rewrites a
# file (`sed -i`, `perl -i`, a python or node snippet that writes) skips the exact-match check that
# Edit makes, so a pattern that matches the wrong text corrupts the file silently. Best effort: it
# matches the command's text, and lets through anything that only writes under /tmp.
set -euo pipefail

cmd=$(jq -r '.tool_input.command // ""' <<<"$(cat)")

scripted=false
grep -Eq '\bsed\b[^|;&]*[[:space:]]-[a-zA-Z]*i' <<<"$cmd" && scripted=true
grep -Eq '\bperl\b[^|;&]*[[:space:]]-[a-zA-Z]*i' <<<"$cmd" && scripted=true
if grep -Eq '\b(python3?|node)\b' <<<"$cmd" &&
  grep -Eq '\.write\(|write_text\(|writeFileSync|writeFile\(' <<<"$cmd"; then
  scripted=true
fi
$scripted || exit 0

# Scratch work in /tmp is fine: a script that names /tmp and no other path gets through. A path
# starts a token (after a space, =, quote, bracket or redirect), so a sed expression such as
# `s/old/new/` is not one, and /dev/null is not a file being written.
others=$(grep -Eo "(^|[[:space:]=<>(\"'])(~|\.{0,2})/[^[:space:]'\"]+" <<<"$cmd" \
  | sed -E "s/^[[:space:]=<>(\"']//" | grep -Ev '^(/tmp|/dev)/' || true)
[[ -z $others ]] && grep -q '/tmp/' <<<"$cmd" && exit 0

jq -n '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: "Edit files with the Edit tool (or Write for a whole file), one exact replacement at a time. Scripts that rewrite files in place are blocked outside /tmp."
}}'
