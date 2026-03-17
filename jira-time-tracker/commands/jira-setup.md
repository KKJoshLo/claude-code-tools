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
   - Copy the statusline script using `${CLAUDE_PLUGIN_ROOT}` (provided by the plugin system):
     ```bash
     cp "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh" ~/.claude/jira-tracker/statusline.sh
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
