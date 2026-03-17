# Jira Time Tracker → Claude Code Plugin Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `jira-time-tracker` from a shell-script install into a distributable Claude Code plugin installable via `/plugin install`, including a status bar showing the active Jira ticket ID.

**Architecture:** Add the Claude Code plugin manifest structure (`plugin.json`, `hooks/hooks.json`, `commands/jira-setup.md`, `scripts/statusline.sh`) to the existing repo, fix two broken path references in the Python scripts, and clean up now-obsolete setup/wrapper files. No logic changes to the core tracking flow.

**Tech Stack:** Python 3 (stdlib only), JSON, Claude Code plugin system

**Spec:** `docs/superpowers/specs/2026-03-17-jira-time-tracker-plugin-design.md`

---

## Chunk 1: Plugin infrastructure + code fixes

### Task 1: Create plugin manifest

**Files:**
- Create: `jira-time-tracker/.claude-plugin/plugin.json`

- [ ] **Step 1: Create the directory and write plugin.json**

```bash
mkdir -p jira-time-tracker/.claude-plugin
```

Write `jira-time-tracker/.claude-plugin/plugin.json`:
```json
{
  "name": "jira-time-tracker",
  "version": "1.0.0",
  "description": "Automatically log work time to Jira from Claude Code sessions",
  "author": { "name": "your-org" }
}
```

- [ ] **Step 2: Validate JSON is parseable**

```bash
python3 -c "import json; json.load(open('jira-time-tracker/.claude-plugin/plugin.json')); print('OK')"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add jira-time-tracker/.claude-plugin/plugin.json
git commit -m "feat: add plugin.json manifest"
```

---

### Task 2: Create hooks declarations

**Files:**
- Create: `jira-time-tracker/hooks/hooks.json`

- [ ] **Step 1: Create the directory and write hooks.json**

```bash
mkdir -p jira-time-tracker/hooks
```

Write `jira-time-tracker/hooks/hooks.json`:
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

- [ ] **Step 2: Validate JSON is parseable**

```bash
python3 -c "import json; json.load(open('jira-time-tracker/hooks/hooks.json')); print('OK')"
```
Expected: `OK`

- [ ] **Step 3: Ensure scripts are executable**

```bash
chmod +x jira-time-tracker/scripts/prompt-submit-hook.py
chmod +x jira-time-tracker/scripts/stop-hook.py
chmod +x jira-time-tracker/scripts/log-worklog.py
```

- [ ] **Step 4: Commit**

```bash
git add jira-time-tracker/hooks/hooks.json
git commit -m "feat: add hooks/hooks.json for plugin hook declarations"
```

---

### Task 3: Fix stop-hook.py LOG_SCRIPT path

**Files:**
- Modify: `jira-time-tracker/scripts/stop-hook.py` (lines 24–25)

Currently `stop-hook.py` resolves `log-worklog.py` via a hardcoded `~/.claude/jira-tracker/` path that won't exist in the plugin context. Fix it to be relative to the script's own location.

- [ ] **Step 1: Write a test that will fail with the current code**

Create `jira-time-tracker/scripts/test_stop_hook_paths.py`:
```python
#!/usr/bin/env python3
"""Verify stop-hook.py resolves log-worklog.py relative to itself."""
import os
import ast

script_dir = os.path.dirname(os.path.abspath(__file__))
stop_hook_path = os.path.join(script_dir, "stop-hook.py")

with open(stop_hook_path) as f:
    source = f.read()

# Verify TRACKER_DIR is NOT present (dead code removed)
assert "TRACKER_DIR" not in source, "TRACKER_DIR should have been removed"

# Verify LOG_SCRIPT uses __file__-relative resolution
assert "__file__" in source, "LOG_SCRIPT must use __file__-relative path"
assert "~/.claude/jira-tracker" not in source, "Hardcoded ~/.claude path must be removed"

# Verify the resolved path actually exists
log_worklog = os.path.join(script_dir, "log-worklog.py")
assert os.path.exists(log_worklog), f"log-worklog.py not found at {log_worklog}"

print("OK")
```

- [ ] **Step 2: Run test — expect failure**

```bash
python3 jira-time-tracker/scripts/test_stop_hook_paths.py
```
Expected: `AssertionError: TRACKER_DIR should have been removed`

- [ ] **Step 3: Apply the fix to stop-hook.py**

In `jira-time-tracker/scripts/stop-hook.py`, replace lines 24–25:
```python
# REMOVE this line:
TRACKER_DIR = os.path.expanduser("~/.claude/jira-tracker")
# REPLACE this line:
LOG_SCRIPT  = os.path.join(TRACKER_DIR, "scripts", "log-worklog.py")
```

With this single line:
```python
LOG_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "log-worklog.py")
```

The block at lines 22–25 should look like this after the change:
```python
TURN_FILE   = os.path.expanduser("~/.claude/jira-tracker/.turn_start")
CARRY_FILE  = os.path.expanduser("~/.claude/jira-tracker/.carry_duration")
LOG_SCRIPT  = os.path.join(os.path.dirname(os.path.abspath(__file__)), "log-worklog.py")
```

- [ ] **Step 4: Run test — expect pass**

```bash
python3 jira-time-tracker/scripts/test_stop_hook_paths.py
```
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add jira-time-tracker/scripts/stop-hook.py jira-time-tracker/scripts/test_stop_hook_paths.py
git commit -m "fix: resolve log-worklog.py relative to script location, not ~/.claude"
```

---

### Task 4: Fix log-worklog.py (truncation + messages)

**Files:**
- Modify: `jira-time-tracker/scripts/log-worklog.py` (lines 8, 29, 38)

Three text fixes: docstring (50→100), runtime truncation (50→100), error message (setup.sh→/jira-setup).

- [ ] **Step 1: Write a test that will fail with the current code**

Create `jira-time-tracker/scripts/test_log_worklog.py`:
```python
#!/usr/bin/env python3
"""Verify log-worklog.py has correct truncation and messaging."""
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
log_worklog_path = os.path.join(script_dir, "log-worklog.py")

with open(log_worklog_path) as f:
    source = f.read()

# Docstring must say 100, not 50
assert "truncated to 50 chars" not in source, "Docstring still says 50 chars"
assert "truncated to 100 chars" in source, "Docstring should say 100 chars"

# Runtime truncation must be [:100], not [:50]
assert ".strip()[:50]" not in source, "Runtime still truncates at 50"
assert ".strip()[:100]" in source, "Runtime should truncate at 100"

# Error message must reference /jira-setup, not setup.sh
assert "setup.sh" not in source, "Error message still references setup.sh"
assert "/jira-setup" in source, "Error message should reference /jira-setup"

print("OK")
```

- [ ] **Step 2: Run test — expect failure**

```bash
python3 jira-time-tracker/scripts/test_log_worklog.py
```
Expected: `AssertionError: Docstring still says 50 chars`

- [ ] **Step 3: Apply the three fixes to log-worklog.py**

**Fix 1** — Line 8, docstring:
```python
# Before:
  JIRA_DESCRIPTION - Worklog comment (will be truncated to 50 chars)
# After:
  JIRA_DESCRIPTION - Worklog comment (will be truncated to 100 chars)
```

**Fix 2** — Line 38, runtime truncation:
```python
# Before:
    description = os.environ.get("JIRA_DESCRIPTION", "Claude Code session").strip()[:50]
# After:
    description = os.environ.get("JIRA_DESCRIPTION", "Claude Code session").strip()[:100]
```

**Fix 3** — Line 29, error message:
```python
# Before:
        print("Error: Config not found. Run setup.sh first.", file=sys.stderr)
# After:
        print("Error: Config not found. Run /jira-setup to configure.", file=sys.stderr)
```

- [ ] **Step 4: Run test — expect pass**

```bash
python3 jira-time-tracker/scripts/test_log_worklog.py
```
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add jira-time-tracker/scripts/log-worklog.py jira-time-tracker/scripts/test_log_worklog.py
git commit -m "fix: increase worklog description limit to 100 chars, update setup error message"
```

---

### Task 5: Delete obsolete files

**Files:**
- Delete: `jira-time-tracker/setup.sh`
- Delete: `jira-time-tracker/uninstall.sh`
- Delete: `jira-time-tracker/scripts/claude-jira`
- Delete: `jira-time-tracker/.claude/` (entire directory)

- [ ] **Step 1: Remove the files**

```bash
rm jira-time-tracker/setup.sh
rm jira-time-tracker/uninstall.sh
rm jira-time-tracker/scripts/claude-jira
rm -rf jira-time-tracker/.claude
```

- [ ] **Step 2: Verify they're gone and nothing else was deleted**

```bash
git status
```
Expected: deletions only from the expected list — `setup.sh`, `uninstall.sh`, `scripts/claude-jira`, and files under `.claude/`. No other changes.

- [ ] **Step 3: Commit**

```bash
git add -u jira-time-tracker/
git commit -m "chore: remove setup.sh, uninstall.sh, claude-jira wrapper and .claude test config"
```

---

## Chunk 2: Command and documentation

### Task 6: Create statusline script

**Files:**
- Create: `jira-time-tracker/scripts/statusline.sh`

- [ ] **Step 1: Write a test that verifies the script outputs correct values**

Create `jira-time-tracker/scripts/test_statusline.sh`:
```bash
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUSLINE="$SCRIPT_DIR/statusline.sh"

fail() { echo "FAIL: $1"; exit 1; }

# Test 1: branch with ticket ID → shows ticket
OUTPUT=$(echo '{"workspace":{"current_dir":"'"$SCRIPT_DIR"'"}}' | bash "$STATUSLINE")
# We're in a git repo with a branch that may or may not have a ticket.
# Just verify the script runs without error and outputs something non-empty.
[ -n "$OUTPUT" ] || fail "output was empty"

# Test 2: non-git directory → shows [no ticket]
OUTPUT=$(echo '{"workspace":{"current_dir":"/tmp"}}' | bash "$STATUSLINE")
[ "$OUTPUT" = "[no ticket]" ] || fail "expected '[no ticket]' for /tmp, got: $OUTPUT"

# Test 3: empty cwd → shows [no ticket]
OUTPUT=$(echo '{}' | bash "$STATUSLINE")
[ "$OUTPUT" = "[no ticket]" ] || fail "expected '[no ticket]' for empty cwd, got: $OUTPUT"

echo "OK"
```

- [ ] **Step 2: Run test — expect failure (script doesn't exist yet)**

```bash
bash jira-time-tracker/scripts/test_statusline.sh
```
Expected: `bash: .../statusline.sh: No such file or directory` or similar error

- [ ] **Step 3: Create the statusline script**

Write `jira-time-tracker/scripts/statusline.sh`:
```bash
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
```

- [ ] **Step 4: Make it executable**

```bash
chmod +x jira-time-tracker/scripts/statusline.sh
```

- [ ] **Step 5: Run test — expect pass**

```bash
bash jira-time-tracker/scripts/test_statusline.sh
```
Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add jira-time-tracker/scripts/statusline.sh jira-time-tracker/scripts/test_statusline.sh
git commit -m "feat: add statusline.sh to display Jira ticket ID in Claude Code status bar"
```

---

### Task 7: Create /jira-setup command

**Files:**
- Create: `jira-time-tracker/commands/jira-setup.md`

- [ ] **Step 1: Create the commands directory and write the command file**

```bash
mkdir -p jira-time-tracker/commands
```

Write `jira-time-tracker/commands/jira-setup.md`:
```markdown
---
description: Interactive setup for jira-time-tracker — configures Jira credentials and status line
---

Guide the user through setting up jira-time-tracker. Follow these steps exactly:

1. **Check for existing config**

   Check if `~/.claude/jira-tracker/config.conf` exists.
   - If it exists, show the current values (mask the API token — show only the last 4 characters) and ask: "A config already exists. Do you want to overwrite it? (yes/no)"
   - If the user says no, stop here and confirm the existing config is still in use.
   - If no config exists, proceed directly to step 2.

2. **Ask for Jira base URL**

   Ask: "What is your Jira base URL? (e.g. https://your-company.atlassian.net)"
   Wait for the user's answer before continuing.

3. **Ask for email**

   Ask: "What email address do you use to log in to Jira?"
   Wait for the user's answer before continuing.

4. **Ask for API token**

   Ask: "What is your Jira API token? You can generate one at https://id.atlassian.com/manage-profile/security/api-tokens"
   Wait for the user's answer before continuing.

5. **Write the config file**

   Use the Bash tool to:
   - Create the directory: `mkdir -p ~/.claude/jira-tracker`
   - Write the config file to `~/.claude/jira-tracker/config.conf` with exactly this format:
     ```
     JIRA_BASE_URL="<url>"
     JIRA_EMAIL="<email>"
     JIRA_API_TOKEN="<token>"
     ```
   - Set permissions: `chmod 600 ~/.claude/jira-tracker/config.conf`

6. **Configure the status line**

   Use the Bash tool to:
   - Find the plugin's `statusline.sh` by locating it relative to this command file:
     ```bash
     PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
     cp "$PLUGIN_DIR/scripts/statusline.sh" ~/.claude/jira-tracker/statusline.sh
     chmod +x ~/.claude/jira-tracker/statusline.sh
     ```
   - Read `~/.claude/settings.json` (create it as `{}` if it doesn't exist)
   - If `statusLine` already exists in `settings.json`, show its current value and ask: "A statusLine is already configured. Do you want to replace it with the Jira tracker status line? (yes/no)"
   - If approved (or if `statusLine` was absent), add/replace:
     ```json
     "statusLine": {
       "type": "command",
       "command": "~/.claude/jira-tracker/statusline.sh"
     }
     ```
   - Write the updated JSON back to `~/.claude/settings.json`

7. **Confirm and explain**

   Tell the user:
   - Setup is complete.
   - **Time tracking:** every turn, the tracker detects the Jira ticket ID from the git branch (e.g. `feature/PROJECT-1234-description` → `PROJECT-1234`), generates a short summary, and logs time to Jira. If no ticket is found, nothing is logged.
   - **Status bar:** the current Jira ticket ID is shown in the Claude Code status bar (🎫 PROJECT-1234, or `[no ticket]` when not on a ticket branch). Restart Claude Code to activate.
   - They can re-run `/jira-setup` at any time to update credentials or reconfigure.
```

- [ ] **Step 2: Commit**

```bash
git add jira-time-tracker/commands/jira-setup.md
git commit -m "feat: add /jira-setup interactive configuration command with status line setup"
```

---

### Task 8: Update root README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace the setup.sh bullet and remove claude-jira mention**

In `README.md`, make two edits to the `功能亮點` section for jira-time-tracker:

**Edit 1** — Replace the `setup.sh` bullet:
```
- 一次性 `setup.sh` 安裝，裝完後照常用 `claude` 即可
```
With:
```
- 一鍵安裝：透過 Claude Code plugin 系統安裝，`/jira-setup` 完成設定即可使用
```

**Edit 2** — Remove any bullet mentioning `claude-jira` (the wrapper command has been deleted). If no such bullet exists, skip this edit.

- [ ] **Step 2: Verify the file still renders correctly**

```bash
python3 -c "
with open('README.md') as f:
    content = f.read()
assert 'setup.sh' not in content, 'setup.sh reference should be removed'
assert 'jira-setup' in content, '/jira-setup reference should be present'
print('OK')
"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update root README to reflect plugin-based installation"
```

---

### Task 9: Rewrite jira-time-tracker/README.md

**Files:**
- Modify: `jira-time-tracker/README.md`

The installation section needs a full rewrite. All other sections (how it works, branch naming, troubleshooting, configuration) stay intact.

- [ ] **Step 1: Read the current README to identify exact section boundaries**

Open `jira-time-tracker/README.md` and note the line numbers of:
- The installation section heading and its content
- Any references to `setup.sh`, `uninstall.sh`, or `claude-jira`

- [ ] **Step 2: Replace the installation section**

Find the installation section (currently titled `## 安裝` or similar). Replace its entire content with:

```markdown
## 安裝

### 前置需求

- macOS
- [Claude Code](https://claude.ai/claude-code) 已安裝並登入
- Python 3
- Git

### 安裝步驟

**Step 1：加入 plugin 來源（每台機器只需一次）**

在 Claude Code 中執行：
```
/plugin marketplace add your-org/jira-time-tracker
```

**Step 2：安裝 plugin**

```
/plugin install jira-time-tracker@your-org
```

**Step 3：重啟 Claude Code**

完全關閉並重新開啟 Claude Code，讓 hooks 生效。

**Step 4：設定 Jira 憑證**

```
/jira-setup
```

依照互動式提示輸入 Jira URL、email 及 API token。
API token 可在此產生：https://id.atlassian.com/manage-profile/security/api-tokens

---

### 升級

```
/plugin update jira-time-tracker@your-org
```

### 移除

```
/plugin uninstall jira-time-tracker@your-org
```

設定檔 `~/.claude/jira-tracker/config.conf` 不會被自動刪除，需手動移除。
```

- [ ] **Step 3: Remove any remaining references to setup.sh, uninstall.sh, or claude-jira**

Search the entire file and remove or update any remaining mentions:
```bash
grep -n "setup\.sh\|uninstall\.sh\|claude-jira" jira-time-tracker/README.md
```
Expected: no matches. If any are found, update those lines to reflect the plugin-based workflow.

- [ ] **Step 4: Commit**

```bash
git add jira-time-tracker/README.md
git commit -m "docs: rewrite installation section for plugin-based distribution"
```

---

### Task 10: Smoke test the plugin locally

Verify the plugin installs and hooks fire before calling the work done.

- [ ] **Step 1: Create a dev marketplace manifest**

Write `jira-time-tracker/.claude-plugin/marketplace.json`:
```json
{
  "name": "jira-time-tracker-dev",
  "description": "Dev marketplace for local testing",
  "owner": { "name": "dev" },
  "plugins": [
    {
      "name": "jira-time-tracker",
      "description": "Automatically log work time to Jira from Claude Code sessions",
      "version": "1.0.0",
      "source": "./",
      "author": { "name": "your-org" }
    }
  ]
}
```

- [ ] **Step 2: Install via dev marketplace**

In Claude Code:
```
/plugin marketplace add /Users/josh.lo/www/claude/jira-time-tracker
/plugin install jira-time-tracker@jira-time-tracker-dev
```
Then restart Claude Code.

- [ ] **Step 3: Verify hooks are registered**

In Claude Code settings (or via CLI), confirm `UserPromptSubmit` and `Stop` hooks appear for the plugin.

- [ ] **Step 4: Run /jira-setup and verify config is written**

```
/jira-setup
```
After setup:
```bash
ls -la ~/.claude/jira-tracker/config.conf
cat ~/.claude/jira-tracker/config.conf
```
Expected: file exists, permissions are `600`, contains the three keys.

- [ ] **Step 5: Verify the status line script works directly**

```bash
echo '{"workspace":{"current_dir":"'"$(pwd)"'"}}' | bash ~/.claude/jira-tracker/statusline.sh
```
Expected: `🎫 B2CBE-2109` (or the ticket from the current branch), confirming the script was copied correctly and runs.

- [ ] **Step 6: Verify hooks fire on a test session**

Open a session on a branch with a ticket ID in the name (or create a test branch: `git checkout -b test/TEST-1-plugin-smoke-test`). Send a message and wait for the Stop hook to fire. Check stderr output for the `✓ Logged` confirmation or a Jira API error (both confirm the hook ran).

- [ ] **Step 7: Commit the dev marketplace manifest**

```bash
git add jira-time-tracker/.claude-plugin/marketplace.json
git commit -m "chore: add dev marketplace manifest for local testing"
```
