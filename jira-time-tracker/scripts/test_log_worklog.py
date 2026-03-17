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
