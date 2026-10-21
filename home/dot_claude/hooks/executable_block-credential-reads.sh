#!/usr/bin/env bash
# PreToolUse hook for Bash: refuse commands that name a credential file in the home folder, so a
# token never lands in a transcript. The Read deny rules in settings.json cover the Read tool;
# this covers cat, grep and the rest. Best effort: it matches the command's text.
set -euo pipefail

cmd=$(jq -r '.tool_input.command // ""' <<<"$(cat)")

home='(~|\$HOME|\$\{HOME\}|'"$HOME"')'
files='\.ssh(/|\b)|\.npmrc\b|\.netrc\b|\.git-credentials\b|\.config/gh/hosts\.yml\b'
grep -Eq "$home/($files)" <<<"$cmd" || exit 0

jq -n '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: "That file holds credentials (SSH keys, npm or GitHub tokens). Leave it unread; if a task seems to need it, ask the user."
}}'
