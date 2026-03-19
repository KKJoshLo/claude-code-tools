#!/usr/bin/env python3
"""
Claude Code Stop hook: logs each completed turn as a Jira worklog entry.

Flow per turn:
  - Short user message (≤5 chars, e.g. "1", "yes") → accumulate into carry buffer
  - Substantial message → merge carry + current duration, take first 150 chars of
    user prompt as description, then log to Jira
"""

import json
import sys
import os
import re
import time
import subprocess

TURN_FILE   = os.path.expanduser("~/.claude/jira-tracker/.turn_start")
CARRY_FILE  = os.path.expanduser("~/.claude/jira-tracker/.carry_duration")
TRACKER_DIR = os.path.expanduser("~/.claude/jira-tracker")
LOG_SCRIPT  = os.path.join(TRACKER_DIR, "scripts", "log-worklog.py")

SHORT_MSG_THRESHOLD = 5


def main():
    if not os.path.exists(TURN_FILE):
        sys.exit(0)

    try:
        hook_input = json.load(sys.stdin)
    except Exception:
        hook_input = {}

    try:
        with open(TURN_FILE) as f:
            turn = json.load(f)
    except Exception:
        sys.exit(0)
    finally:
        try:
            os.remove(TURN_FILE)
        except Exception:
            pass

    duration = int(time.time()) - turn.get("start_epoch", int(time.time()))

    # Skip turns shorter than 5 seconds
    if duration < 5:
        sys.exit(0)

    cwd    = turn.get("cwd") or hook_input.get("cwd") or os.getcwd()
    ticket = get_ticket(cwd)
    if not ticket:
        sys.exit(0)

    transcript_path = hook_input.get("transcript_path", "")
    last_msg        = extract_last_user_message(transcript_path)

    # Short message (selection/confirmation) → carry forward, don't log yet
    if len(last_msg) <= SHORT_MSG_THRESHOLD:
        add_carry(duration)
        sys.exit(0)

    carry = pop_carry()
    total = duration + carry

    description = last_msg[:150]

    env = os.environ.copy()
    env.update({
        "JIRA_TICKET":      ticket,
        "JIRA_DURATION":    str(total),
        "JIRA_STARTED":     turn.get("start_jira", ""),
        "JIRA_DESCRIPTION": description,
    })

    result = subprocess.run(
        [sys.executable, LOG_SCRIPT],
        env=env, capture_output=True, text=True,
    )
    if result.returncode == 0 and result.stdout:
        msg = result.stdout.strip()
        print(msg, file=sys.stderr)  # stderr only — stdout would be injected into Claude's conversation
    elif result.returncode != 0 and result.stderr:
        print(result.stderr, end="", file=sys.stderr)


def extract_recent_user_messages(transcript_path: str, n: int = 3) -> list:
    """Return the last n user messages from the transcript (truncated to 200 chars each)."""
    if not transcript_path or not os.path.exists(transcript_path):
        return []

    messages = []
    try:
        with open(transcript_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    msg  = json.loads(line)
                    # Support both flat format (role at top level) and
                    # nested format used by Claude Code (role inside "message")
                    nested = msg.get("message", {})
                    role   = msg.get("role") or nested.get("role", "")
                    if role not in ("human", "user"):
                        continue
                    content = msg.get("content") if msg.get("content") is not None else nested.get("content", "")
                    text    = ""
                    if isinstance(content, list):
                        for block in content:
                            if isinstance(block, dict) and block.get("type") == "text":
                                text = block["text"].strip()
                                if text:
                                    break
                    elif isinstance(content, str):
                        text = content.strip()
                    if text:
                        messages.append(text[:150])
                except json.JSONDecodeError:
                    continue
    except Exception:
        pass

    return messages[-n:]


def extract_last_user_message(transcript_path: str) -> str:
    messages = extract_recent_user_messages(transcript_path, n=1)
    if messages:
        return re.sub(r"\s+", " ", messages[0]).strip()
    return ""


def get_ticket(cwd: str) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", cwd, "branch", "--show-current"],
            capture_output=True, text=True, timeout=5,
        )
        match = re.search(r"([A-Z][A-Z0-9]+-[0-9]+)", result.stdout.strip())
        if match:
            return match.group(1)
    except Exception:
        pass
    return ""


def add_carry(seconds: int):
    carry = 0
    try:
        with open(CARRY_FILE) as f:
            carry = int(f.read().strip())
    except Exception:
        pass
    with open(CARRY_FILE, "w") as f:
        f.write(str(carry + seconds))


def pop_carry() -> int:
    try:
        with open(CARRY_FILE) as f:
            carry = int(f.read().strip())
        os.remove(CARRY_FILE)
        return carry
    except Exception:
        return 0


if __name__ == "__main__":
    main()
