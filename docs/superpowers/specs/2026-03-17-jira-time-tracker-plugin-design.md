# Jira Time Tracker — Claude Code Plugin Design

**Date:** 2026-03-17
**Status:** Approved

---

## Overview

Convert the existing `jira-time-tracker` shell-script toolset into a proper Claude Code plugin. The goal is to make installation trivially easy for team members (and eventually the whole company) without changing any of the core time-tracking logic.

Distribution method: **Direct GitHub** — users add the repo as a marketplace source and install via `/plugin install`.

---

## Directory Structure

```
jira-time-tracker/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata only (name, version, author)
├── hooks/
│   └── hooks.json               # Hook declarations — auto-loaded by Claude Code
├── scripts/
│   ├── prompt-submit-hook.py    # UNCHANGED
│   ├── stop-hook.py             # Modified: fix LOG_SCRIPT path (see Code Changes)
│   ├── log-worklog.py           # Modified: fix 50→100 char truncation + error message
│   └── statusline.sh            # New: outputs Jira ticket ID to Claude Code status bar
├── commands/
│   └── jira-setup.md            # New: /jira-setup interactive setup command
├── config.example               # Keep as reference
└── README.md                    # Updated: plugin-based install instructions
```

**Files deleted:**
- `setup.sh` — replaced by plugin install + `/jira-setup`
- `uninstall.sh` — replaced by `/plugin uninstall`
- `scripts/claude-jira` — branch detection already exists in `stop-hook.py`; wrapper is redundant
- `.claude/` directory (entire) — contains only `settings.local.json`, a local test artifact

---

## Components

### 1. `plugin.json`

Contains only plugin metadata. Hooks are declared separately in `hooks/hooks.json`.

```json
{
  "name": "jira-time-tracker",
  "version": "1.0.0",
  "description": "Automatically log work time to Jira from Claude Code sessions",
  "author": { "name": "your-org" }
}
```

### 2. `hooks/hooks.json`

Declares the two hooks using `${CLAUDE_PLUGIN_ROOT}` for portable paths. This file is auto-loaded by Claude Code — do NOT reference it in `plugin.json`. No `matcher` key is needed because both hooks should fire unconditionally on every turn.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/prompt-submit-hook.py"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/stop-hook.py"
          }
        ]
      }
    ]
  }
}
```

### 3. Code Changes to Existing Scripts

**`stop-hook.py` — fix `LOG_SCRIPT` path (lines 24–25)**

Current (broken in plugin context):
```python
TRACKER_DIR = os.path.expanduser("~/.claude/jira-tracker")   # line 24 — delete
LOG_SCRIPT  = os.path.join(TRACKER_DIR, "scripts", "log-worklog.py")  # line 25 — replace
```

Fixed (delete `TRACKER_DIR` entirely; replace `LOG_SCRIPT` to use script's own location):
```python
LOG_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "log-worklog.py")
```

`TRACKER_DIR` is unused after this change and must be deleted to avoid dead code.

**`log-worklog.py` — three fixes**

1. Line 8 (docstring): Update description of `JIRA_DESCRIPTION`:
   ```python
   # Before
   JIRA_DESCRIPTION - Worklog comment (will be truncated to 50 chars)
   # After
   JIRA_DESCRIPTION - Worklog comment (will be truncated to 100 chars)
   ```

2. Line 38: Fix runtime truncation from 50 to 100 chars:
   ```python
   # Before
   description = os.environ.get("JIRA_DESCRIPTION", "Claude Code session").strip()[:50]
   # After
   description = os.environ.get("JIRA_DESCRIPTION", "Claude Code session").strip()[:100]
   ```

3. Line 29: Update error message (no longer using setup.sh):
   ```python
   # Before
   print("Error: Config not found. Run setup.sh first.", file=sys.stderr)
   # After
   print("Error: Config not found. Run /jira-setup to configure.", file=sys.stderr)
   ```

**`prompt-submit-hook.py` — no changes needed.** Branch detection already exists in `stop-hook.py`'s `get_ticket()` function and is unrelated to this hook.

### 5. `scripts/statusline.sh` — Status Line Script

A bash script that Claude Code calls to render the status bar. It receives a JSON payload via stdin containing `workspace.current_dir`, runs `git branch --show-current` in that directory, and outputs the Jira ticket ID on the first line of stdout.

**Output format:**
- Branch has ticket: `🎫 PROJECT-1234`
- Branch has no ticket: `[no ticket]`
- Not a git repo: `[no ticket]`

**Script is copied** to `~/.claude/jira-tracker/statusline.sh` during `/jira-setup` so its path in `settings.json` is stable across plugin version upgrades.

```bash
#!/bin/bash
# Read JSON input from stdin
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
```

### 4. `commands/jira-setup.md` — `/jira-setup` Command

A slash command that instructs Claude to guide the user interactively through first-time (or re-)configuration:

**Behavior:**
1. Check if `~/.claude/jira-tracker/config.conf` already exists — if so, ask user if they want to overwrite
2. Ask for Jira base URL (e.g., `https://your-company.atlassian.net`)
3. Ask for work email
4. Ask for API token (link to `id.atlassian.com/manage-profile/security/api-tokens`)
5. Create `~/.claude/jira-tracker/` directory if it doesn't exist, then write `config.conf` with `chmod 600`

   Config file format (matches `config.example`):
   ```
   JIRA_BASE_URL="https://your-company.atlassian.net"
   JIRA_EMAIL="your.email@company.com"
   JIRA_API_TOKEN="your-api-token"
   ```
6. Configure the Claude Code status line:
   - Copy `scripts/statusline.sh` from the plugin install location to `~/.claude/jira-tracker/statusline.sh` and `chmod +x`
   - Update `~/.claude/settings.json` to add:
     ```json
     "statusLine": {
       "type": "command",
       "command": "~/.claude/jira-tracker/statusline.sh"
     }
     ```
   - If `statusLine` already exists in `settings.json`, ask the user before overwriting
7. Confirm setup is complete; show a brief explanation of how auto-tracking and status line work

**No credential validation** against the Jira API at setup time (keeps the command simple; errors surface naturally when the first worklog is attempted).

---

## Data Flow (unchanged)

```
UserPromptSubmit hook fires
  → Guard against JIRA_SUMMARIZING recursion
  → Write cwd + timestamp to ~/.claude/jira-tracker/.turn_start

Stop hook fires
  → Read .turn_start (cwd + elapsed time)
  → get_ticket(cwd): run git branch, extract PROJECT-NNNNN with regex
  → Handle short-message carryover (≤5 chars merged into next turn)
  → Generate ≤100 char Traditional Chinese summary via `claude -p`
  → Call log-worklog.py via subprocess with JIRA_* env vars
  → POST worklog to Jira REST API v3
```

---

## Installation Flow (new)

```bash
# Step 1: Add plugin source (once per machine)
/plugin marketplace add your-org/jira-time-tracker

# Step 2: Install
/plugin install jira-time-tracker@your-org

# Step 3: Restart Claude Code, then configure
/jira-setup

# To upgrade
/plugin update jira-time-tracker@your-org

# To uninstall
/plugin uninstall jira-time-tracker@your-org
```

---

## README Updates

**Root `README.md`** (`/claude/README.md`):
- Replace the `setup.sh` bullet in "功能亮點" with: `一鍵安裝：透過 Claude Code plugin 系統安裝，/jira-setup 完成設定即可使用`
- Remove the `claude-jira` wrapper mention from "功能亮點"

**`jira-time-tracker/README.md`**:
- Rewrite the installation section using the new plugin flow (4 steps above)
- Keep intact: "How it works", branch naming requirements, troubleshooting section
- Remove: setup.sh/uninstall.sh documentation, `claude-jira` usage instructions
- Add: upgrade and uninstall instructions using `/plugin` commands

---

## Out of Scope

- MCP-based Jira API refactor
- Multi-language support for summaries
- Auto-update mechanism (users run `/plugin update` manually)
- Windows/Linux support (macOS only, same as current)
- Credential validation in `/jira-setup`
