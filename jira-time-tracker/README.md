# Claude Code Jira Time Tracker

在 Claude Code 對話時，自動將工作時間記錄到對應的 Jira ticket worklog。

---

## 運作方式

- 每次你送出訊息，開始計時
- Claude 回答完畢，呼叫 AI 生成 ≤100 字的繁體中文摘要，寫入 Jira worklog
- 短回覆（≤5 字，如 `1`、`yes`、`ok`）不單獨寫 worklog，時間自動合併到下一輪
- Jira ticket 從當前 git branch 自動偵測（如 `feature/B2CBE-2083-xxx` → `B2CBE-2083`）
- 沒有 git branch 時，啟動時會詢問 ticket ID

---

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

---

## 使用

什麼都不用做，照常用 `claude` 即可。

```bash
cd your-project
git checkout feature/B2CBE-2083-optimize-search
claude                  # 自動追蹤時間到 B2CBE-2083
```

每輪對話結束後，Jira worklog 會自動出現一筆記錄，描述由 AI 根據對話內容生成。

---

## Branch 命名規則

Ticket ID 需出現在 branch 名稱中，支援以下格式：

```
feature/B2CBE-2083-some-description   ✓
bugfix/B2CBE-2083                     ✓
B2CBE-2083-hotfix                     ✓
```

---

## Configuration

設定檔位於 `~/.claude/jira-tracker/config.conf`，格式如下：

```bash
JIRA_BASE_URL="https://your-domain.atlassian.net"
JIRA_EMAIL="your.email@example.com"
JIRA_API_TOKEN="your-api-token"
```

檔案權限為 `600`（僅擁有者可讀），直接編輯即可更新設定，無需重新執行設定流程。

---

## Troubleshooting

### Ticket 偵測失敗

症狀：worklog 沒有寫入，或提示找不到 ticket

原因與解法：
- **Branch 命名不符**：確認 branch 名稱含有 `PROJECT-NNNNN` 格式（如 `B2CBE-2083`）
- **不在 git repo 中**：確認執行 `claude` 時在有 git 的目錄下
- **手動指定 ticket**：啟動時若無法偵測，會詢問 ticket ID，可直接輸入

### API 錯誤

症狀：`stop-hook.py` 報 401 / 403 錯誤

解法：
1. 確認 `~/.claude/jira-tracker/config.conf` 中 Email 和 API Token 正確
2. 至 [Atlassian API Tokens](https://id.atlassian.com/manage-profile/security/api-tokens) 重新產生 token
3. 更新 config.conf 後重試

### Hook 未觸發

症狀：`claude` 執行後完全沒有 worklog 活動

解法：
1. 確認 `~/.claude/settings.json` 中有 Stop 和 UserPromptSubmit hooks：
   ```bash
   cat ~/.claude/settings.json | python3 -m json.tool | grep -A5 '"hooks"'
   ```
2. 若 hooks 不在，重新執行 `/jira-setup`
