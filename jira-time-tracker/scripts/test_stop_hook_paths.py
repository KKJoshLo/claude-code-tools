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

# Verify the LOG_SCRIPT line specifically does not use a hardcoded path.
# Note: TURN_FILE and CARRY_FILE legitimately reference ~/.claude/jira-tracker/ as the
# user's runtime data directory — only the LOG_SCRIPT (script location) must be relative.
lines = source.split('\n')
log_script_line = [l for l in lines if l.strip().startswith('LOG_SCRIPT')][0]
assert "TRACKER_DIR" not in log_script_line, "LOG_SCRIPT must not depend on TRACKER_DIR"
assert "~/.claude" not in log_script_line, "LOG_SCRIPT must not use a hardcoded ~/.claude path"

# Verify the resolved path actually exists
log_worklog = os.path.join(script_dir, "log-worklog.py")
assert os.path.exists(log_worklog), f"log-worklog.py not found at {log_worklog}"

print("OK")
