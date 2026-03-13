#!/usr/bin/env bash
# Claude Code Jira Time Tracker — uninstall
# Removes all files, hooks, and aliases added by setup.sh

set -euo pipefail

TRACKER_DIR="${HOME}/.claude/jira-tracker"
SETTINGS_FILE="${HOME}/.claude/settings.json"

echo "=== Claude Code Jira Time Tracker Uninstall ==="
echo ""

# ── Remove hooks from settings.json ──────────────────────────────────────────

if [[ -f "$SETTINGS_FILE" ]]; then
  python3 << PYEOF
import json, os

settings_file = "${SETTINGS_FILE}"
marker_commands = [
    os.path.expanduser("~/.claude/jira-tracker/scripts/stop-hook.py"),
    os.path.expanduser("~/.claude/jira-tracker/scripts/prompt-submit-hook.py"),
]

try:
    with open(settings_file) as f:
        settings = json.load(f)
except Exception as e:
    print(f"⚠  Could not read settings.json: {e}")
    raise SystemExit(1)

hooks = settings.get("hooks", {})
changed = False

for event in list(hooks.keys()):
    original_len = len(hooks[event])
    hooks[event] = [
        entry for entry in hooks[event]
        if not any(
            h.get("command") in marker_commands
            for h in entry.get("hooks", [])
        )
    ]
    if len(hooks[event]) < original_len:
        changed = True
    # Remove the event key entirely if no hooks remain
    if not hooks[event]:
        del hooks[event]

if changed:
    with open(settings_file, "w") as f:
        json.dump(settings, f, indent=2)
    print("✓ Hooks removed from settings.json")
else:
    print("✓ No tracker hooks found in settings.json")
PYEOF
else
  echo "✓ settings.json not found, skipping"
fi

# ── Remove alias from shell rc ────────────────────────────────────────────────

for RC in "${HOME}/.zshrc" "${HOME}/.bashrc"; do
  if [[ -f "$RC" ]] && grep -q "jira-time-tracker" "$RC" 2>/dev/null; then
    # Remove the two lines added by setup.sh
    TMP=$(mktemp)
    grep -v "jira-time-tracker" "$RC" | grep -v "alias claude='claude-jira'" > "$TMP"
    mv "$TMP" "$RC"
    echo "✓ Alias removed from ${RC}"
    echo "  Run: source ${RC}"
  fi
done

# ── Remove symlink ─────────────────────────────────────────────────────────────

for BIN in "/usr/local/bin/claude-jira" "${HOME}/.local/bin/claude-jira"; do
  if [[ -L "$BIN" ]]; then
    rm "$BIN"
    echo "✓ Removed symlink: ${BIN}"
  fi
done

# ── Remove tracker directory ──────────────────────────────────────────────────

if [[ -d "$TRACKER_DIR" ]]; then
  rm -rf "$TRACKER_DIR"
  echo "✓ Removed ${TRACKER_DIR}"
else
  echo "✓ ${TRACKER_DIR} not found, skipping"
fi

# ── Remove leftover temp files ────────────────────────────────────────────────

for F in \
  "${HOME}/.claude/jira-tracker/.turn_start" \
  "${HOME}/.claude/jira-tracker/.carry_duration" \
  "${HOME}/.claude/jira-tracker/.current_session"; do
  [[ -f "$F" ]] && rm "$F"
done

echo ""
echo "=== Uninstall complete ==="
echo ""
echo "Note: pre-install backups (settings.json.bak.*) were kept for your reference."
