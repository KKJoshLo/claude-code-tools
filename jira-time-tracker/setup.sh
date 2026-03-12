#!/usr/bin/env bash
# Claude Code Jira Time Tracker — one-time setup
# Run from the jira-time-tracker directory:
#   bash setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKER_DIR="${HOME}/.claude/jira-tracker"
SETTINGS_FILE="${HOME}/.claude/settings.json"

echo "=== Claude Code Jira Time Tracker Setup ==="
echo ""

# ── Install scripts ───────────────────────────────────────────────────────────

mkdir -p "${TRACKER_DIR}/scripts"

cp "${SCRIPT_DIR}/scripts/claude-jira"            "${TRACKER_DIR}/scripts/claude-jira"
cp "${SCRIPT_DIR}/scripts/stop-hook.py"           "${TRACKER_DIR}/scripts/stop-hook.py"
cp "${SCRIPT_DIR}/scripts/prompt-submit-hook.py"  "${TRACKER_DIR}/scripts/prompt-submit-hook.py"
cp "${SCRIPT_DIR}/scripts/log-worklog.py"         "${TRACKER_DIR}/scripts/log-worklog.py"

chmod +x "${TRACKER_DIR}/scripts/claude-jira"
chmod +x "${TRACKER_DIR}/scripts/stop-hook.py"
chmod +x "${TRACKER_DIR}/scripts/prompt-submit-hook.py"

# ── Gather Jira credentials ───────────────────────────────────────────────────

echo "Jira credentials:"
read -rp "  Base URL [https://kkday.atlassian.net]: " JIRA_URL
JIRA_URL="${JIRA_URL:-https://kkday.atlassian.net}"

read -rp "  Email: " JIRA_EMAIL
read -rsp "  API Token: " JIRA_API_TOKEN
echo ""

# Save config (owner-read only)
cat > "${TRACKER_DIR}/config.conf" << EOF
JIRA_BASE_URL="${JIRA_URL}"
JIRA_EMAIL="${JIRA_EMAIL}"
JIRA_API_TOKEN="${JIRA_API_TOKEN}"
EOF
chmod 600 "${TRACKER_DIR}/config.conf"
echo "✓ Config saved to ${TRACKER_DIR}/config.conf"

# ── Register Stop hook in Claude Code settings ────────────────────────────────

python3 << PYEOF
import json, os, sys

settings_file = os.path.expanduser("~/.claude/settings.json")
hook_script   = os.path.expanduser("~/.claude/jira-tracker/scripts/stop-hook.py")

try:
    with open(settings_file) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

hooks = settings.setdefault("hooks", {})

def register_hook(hooks, event, command):
    hooks.setdefault(event, [])
    already = any(
        h.get("command") == command
        for entry in hooks[event]
        for h in entry.get("hooks", [])
    )
    if not already:
        hooks[event].append({
            "matcher": "",
            "hooks": [{"type": "command", "command": command}]
        })
        return True
    return False

stop_hook   = os.path.expanduser("~/.claude/jira-tracker/scripts/stop-hook.py")
submit_hook = os.path.expanduser("~/.claude/jira-tracker/scripts/prompt-submit-hook.py")

added_stop   = register_hook(hooks, "Stop",              stop_hook)
added_submit = register_hook(hooks, "UserPromptSubmit",  submit_hook)

os.makedirs(os.path.dirname(settings_file), exist_ok=True)
with open(settings_file, "w") as f:
    json.dump(settings, f, indent=2)

print(f"✓ Stop hook {'registered' if added_stop else 'already registered'}")
print(f"✓ UserPromptSubmit hook {'registered' if added_submit else 'already registered'}")
PYEOF

# ── Install claude-jira command ───────────────────────────────────────────────

INSTALLED_PATH=""

if [[ -d "/usr/local/bin" && -w "/usr/local/bin" ]]; then
  ln -sf "${TRACKER_DIR}/scripts/claude-jira" "/usr/local/bin/claude-jira"
  INSTALLED_PATH="/usr/local/bin/claude-jira"
else
  mkdir -p "${HOME}/.local/bin"
  ln -sf "${TRACKER_DIR}/scripts/claude-jira" "${HOME}/.local/bin/claude-jira"
  INSTALLED_PATH="${HOME}/.local/bin/claude-jira"

  if ! echo ":${PATH}:" | grep -q ":${HOME}/.local/bin:"; then
    echo ""
    echo "⚠  ~/.local/bin is not in your PATH."
    echo "   Add this line to your ~/.zshrc (or ~/.bashrc):"
    echo ""
    echo "     export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "   Then reload: source ~/.zshrc"
  fi
fi

echo "✓ Installed: ${INSTALLED_PATH}"

# ── Alias claude → claude-jira ────────────────────────────────────────────────

SHELL_RC=""
if [[ -f "${HOME}/.zshrc" ]]; then
  SHELL_RC="${HOME}/.zshrc"
elif [[ -f "${HOME}/.bashrc" ]]; then
  SHELL_RC="${HOME}/.bashrc"
fi

ALIAS_LINE="alias claude='claude-jira'  # jira-time-tracker"

if [[ -n "$SHELL_RC" ]]; then
  if grep -q "jira-time-tracker" "$SHELL_RC" 2>/dev/null; then
    echo "✓ Shell alias already set in ${SHELL_RC}"
  else
    echo "" >> "$SHELL_RC"
    echo "# Auto-added by jira-time-tracker setup" >> "$SHELL_RC"
    echo "$ALIAS_LINE" >> "$SHELL_RC"
    echo "✓ Added alias to ${SHELL_RC}: alias claude='claude-jira'"
    echo "  Run: source ${SHELL_RC}"
  fi
else
  echo "⚠  Could not find ~/.zshrc or ~/.bashrc."
  echo "   Manually add this line to your shell config:"
  echo "   ${ALIAS_LINE}"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Just use 'claude' as usual — time tracking is now automatic."
echo "When you exit a session, elapsed time is logged to the Jira ticket"
echo "detected from your git branch (e.g. feature/B2CBE-2083-... → B2CBE-2083)."
