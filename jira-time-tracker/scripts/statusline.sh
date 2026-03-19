#!/usr/bin/env bash
# Claude Code statusline: show the Jira ticket being tracked in this session.
# Reads JIRA_TICKET env var set by claude-jira wrapper.
# Output: "⏱ B2CBE-2083" or empty (hides from statusline if empty).
#
# Claude Code pipes JSON session data to stdin; we discard it since we only
# need the JIRA_TICKET environment variable.

cat > /dev/null

if [[ -n "${JIRA_TICKET:-}" ]]; then
    echo "⏱ ${JIRA_TICKET}"
fi
