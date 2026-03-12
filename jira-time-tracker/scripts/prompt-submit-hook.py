#!/usr/bin/env python3
"""
Claude Code UserPromptSubmit hook: records the start time of each turn.

Fires when the user submits a message. Writes a turn-start file so the
Stop hook can calculate how long the AI took to respond.
"""

import json
import sys
import os
import time
from datetime import datetime, timezone

# Guard against triggering during claude -p summarization calls
if os.environ.get("JIRA_SUMMARIZING"):
    sys.exit(0)

TURN_FILE = os.path.expanduser("~/.claude/jira-tracker/.turn_start")


def main():
    try:
        hook_input = json.load(sys.stdin)
    except Exception:
        hook_input = {}

    now_epoch = int(time.time())
    now_jira  = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000+0000")

    # Store cwd from hook payload (used to detect git branch later)
    cwd = hook_input.get("cwd", os.getcwd())

    data = {
        "start_epoch": now_epoch,
        "start_jira":  now_jira,
        "cwd":         cwd,
    }

    os.makedirs(os.path.dirname(TURN_FILE), exist_ok=True)
    with open(TURN_FILE, "w") as f:
        json.dump(data, f)


if __name__ == "__main__":
    main()
