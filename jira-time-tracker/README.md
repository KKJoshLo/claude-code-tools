# Claude Code Jira Time Tracker

在 Claude Code 對話時，自動將工作時間記錄到對應的 Jira ticket worklog。

---

## 運作方式

- 每次你送出訊息，開始計時
- Claude 回答完畢，擷取使用者 prompt 的前 150 字，寫入 Jira worklog
- 短回覆（≤5 字，如 `1`、`yes`、`ok`）不單獨寫 worklog，時間自動合併到下一輪
- Jira ticket 從當前 git branch 自動偵測（如 `feature/B2CBE-2083-xxx` → `B2CBE-2083`）
- 沒有 git branch 時，啟動時會詢問 ticket ID

---

## 安裝（一次性）

### 1. 取得 Jira API Token

前往 [id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens)，點 **Create API token**，複製產生的 token。

### 2. 執行 setup.sh

```bash
git clone <this-repo>
cd jira-time-tracker
bash setup.sh
```

過程中會詢問：

```
Jira credentials:
  Base URL [https://kkday.atlassian.net]:   ← 輸入你的 Atlassian 網址（直接 Enter 使用預設值）
  Email: your.email@example.com
  API Token: <貼上剛才複製的 token>
```

### 3. 套用 alias

```bash
source ~/.zshrc
```

完成。

---

## Installation Safety

`setup.sh` 會修改以下檔案，並在修改前自動備份：

| 檔案 | 備份格式 | 說明 |
|------|----------|------|
| `~/.claude/settings.json` | `settings.json.bak.setup.<timestamp>` | 新增 Stop / UserPromptSubmit hooks |
| `~/.zshrc` 或 `~/.bashrc` | `~/.zshrc.bak.setup.<timestamp>` | 新增 `alias claude='claude-jira'` |
| `/usr/local/bin/claude-jira` | 無（若衝突則跳過） | 安裝指令 symlink |

**衝突偵測：**

- 若 shell RC 已有 **非本工具** 的 `alias claude=`，setup 不會覆蓋，僅印出警告
- 若 `/usr/local/bin/claude-jira` 已指向其他工具，setup 不會覆蓋，僅印出警告

---

## 使用

什麼都不用做，照常用 `claude` 即可。

```bash
cd your-project
git checkout feature/B2CBE-2083-optimize-search
claude                  # 自動追蹤時間到 B2CBE-2083
```

每輪對話結束後，Jira worklog 會自動出現一筆記錄，描述為使用者 prompt 的前 150 字。

---

## Statusline

安裝後，Claude Code 底部狀態列會顯示當前追蹤的票號：

```
⏱ B2CBE-2083
```

若未偵測到票號（如手動跳過追蹤），狀態列不顯示任何內容。

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
JIRA_BASE_URL="https://kkday.atlassian.net"
JIRA_EMAIL="your.email@example.com"
JIRA_API_TOKEN="your-api-token"
```

檔案權限為 `600`（僅擁有者可讀），直接編輯即可更新設定，無需重新執行 setup。

---

## Uninstalling

執行 uninstall.sh 可完整移除所有安裝內容：

```bash
bash uninstall.sh
source ~/.zshrc   # 套用 alias 移除
```

移除項目：
- `~/.claude/settings.json` 中的 Stop / UserPromptSubmit hooks
- `~/.zshrc` / `~/.bashrc` 中的 alias 設定
- `/usr/local/bin/claude-jira` 或 `~/.local/bin/claude-jira` symlink
- `~/.claude/jira-tracker/` 目錄

uninstall 前同樣會備份修改的檔案。

---

## Backup & Recovery

### 備份位置

| 動作 | 備份檔案 |
|------|----------|
| setup | `~/.claude/settings.json.bak.setup.<timestamp>` |
| setup | `~/.zshrc.bak.setup.<timestamp>` |
| uninstall | `~/.claude/settings.json.bak.uninstall.<timestamp>` |
| uninstall | `~/.zshrc.bak.uninstall.<timestamp>` |

### 還原方式

```bash
# 還原 settings.json（以 setup 備份為例）
cp ~/.claude/settings.json.bak.setup.202501010000 ~/.claude/settings.json

# 還原 shell RC
cp ~/.zshrc.bak.setup.202501010000 ~/.zshrc
source ~/.zshrc
```

備份檔案不會自動刪除，可手動清除。

---

## 前置需求

- macOS
- [Claude Code](https://claude.ai/claude-code) 已安裝並登入（`claude.ai` 訂閱帳號）
- Python 3（macOS 內建）
- Git

---

## 檔案說明

```
setup.sh                       一次性安裝腳本
uninstall.sh                   移除腳本
scripts/
  claude-jira                  主指令（setup 後取代 claude）
  prompt-submit-hook.py        每次送出訊息時，記錄開始時間
  stop-hook.py                 每次 AI 回覆後，截取 prompt 前 150 字並寫 Jira worklog
  log-worklog.py               呼叫 Jira REST API
  statusline.sh                Claude Code statusline 腳本，顯示追蹤中的票號
config.example                 設定檔範本
```

安裝後，設定與 scripts 會複製到 `~/.claude/jira-tracker/`，hooks 會自動寫入 `~/.claude/settings.json`。

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
1. 確認使用的是 `claude-jira` 而非原始 `claude`（執行 `which claude` 確認）
2. 確認 `source ~/.zshrc` 已執行
3. 確認 `~/.claude/settings.json` 中有 Stop 和 UserPromptSubmit hooks：
   ```bash
   cat ~/.claude/settings.json | python3 -m json.tool | grep -A5 '"hooks"'
   ```
4. 若 hooks 不在，重新執行 `bash setup.sh`
