#!/usr/bin/env python3
"""
Log a worklog entry to Jira via REST API.
Reads parameters from environment variables:
  JIRA_TICKET      - Issue key (e.g., B2CBE-2083)
  JIRA_DURATION    - Time spent in seconds
  JIRA_STARTED     - Start time in Jira format (yyyy-MM-ddTHH:mm:ss.000+0000)
  JIRA_DESCRIPTION - Worklog comment (will be truncated to 50 chars)
"""

import urllib.request
import urllib.error
import json
import base64
import sys
import os

def load_config():
    config_file = os.path.expanduser("~/.claude/jira-tracker/config.conf")
    config = {}
    try:
        with open(config_file) as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    config[k.strip()] = v.strip().strip("\"'")
    except FileNotFoundError:
        print("Error: Config not found. Run setup.sh first.", file=sys.stderr)
        sys.exit(1)
    return config

def main():
    import math
    ticket      = os.environ.get("JIRA_TICKET", "").strip()
    raw_seconds = int(os.environ.get("JIRA_DURATION", "0"))
    started     = os.environ.get("JIRA_STARTED", "").strip()
    description = os.environ.get("JIRA_DESCRIPTION", "Claude Code session").strip()[:50]

    # Jira only displays minutes — round up, minimum 1 minute
    duration = max(60, math.ceil(raw_seconds / 60) * 60)

    if not ticket:
        print("Error: JIRA_TICKET is required.", file=sys.stderr)
        sys.exit(1)

    config = load_config()
    jira_url = config.get("JIRA_BASE_URL", "").rstrip("/")
    email    = config.get("JIRA_EMAIL", "")
    token    = config.get("JIRA_API_TOKEN", "")

    if not all([jira_url, email, token]):
        print("Error: Incomplete Jira config. Check ~/.claude/jira-tracker/config.conf", file=sys.stderr)
        sys.exit(1)

    credentials = base64.b64encode(f"{email}:{token}".encode()).decode()

    payload = {
        "timeSpentSeconds": duration,
        "started": started,
        "comment": {
            "type": "doc",
            "version": 1,
            "content": [{
                "type": "paragraph",
                "content": [{"type": "text", "text": description}]
            }]
        }
    }

    url  = f"{jira_url}/rest/api/3/issue/{ticket}/worklog"
    data = json.dumps(payload).encode("utf-8")
    req  = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type":  "application/json",
            "Authorization": f"Basic {credentials}",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req) as resp:
            hours = duration // 3600
            mins  = (duration % 3600) // 60
            print(f"✓ Logged {hours}h {mins}m to {ticket}: \"{description}\"")
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"✗ Failed to log to Jira (HTTP {e.code})", file=sys.stderr)
        try:
            detail = json.loads(body)
            msgs = detail.get("errorMessages", []) or [body[:200]]
            print(f"  {msgs[0]}", file=sys.stderr)
        except Exception:
            print(f"  {body[:200]}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
