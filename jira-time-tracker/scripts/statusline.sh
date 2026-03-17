#!/bin/bash
# Claude Code status line: shows Jira ticket ID from current git branch.
# Receives JSON via stdin with workspace.current_dir.
# Outputs: "🎫 PROJECT-1234" or "[no ticket]"

input=$(cat)
cwd=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('workspace',{}).get('current_dir',''))" 2>/dev/null)

if [ -z "$cwd" ]; then
  echo "[no ticket]"
  exit 0
fi

branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
ticket=$(echo "$branch" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -1)

if [ -n "$ticket" ]; then
  echo "🎫 $ticket"
else
  echo "[no ticket]"
fi
