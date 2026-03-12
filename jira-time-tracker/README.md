# Claude Code Jira Time Tracker

在 Claude Code 對話時，自動將工作時間記錄到對應的 Jira ticket worklog。

---

## 運作方式

- 每次你送出訊息，開始計時
- Claude 回答完畢，呼叫 AI 生成 ≤20 字的繁體中文摘要，寫入 Jira worklog
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
  Base URL [https://kkday.atlassian.net]:   ← 直接 Enter 使用預設
  Email: your.email@kkday.com
  API Token: <貼上剛才複製的 token>
```

### 3. 套用 alias

```bash
source ~/.zshrc
```

完成。

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

## 前置需求

- macOS
- [Claude Code](https://claude.ai/claude-code) 已安裝並登入（`claude.ai` 訂閱帳號）
- Python 3（macOS 內建）
- Git

---

## 檔案說明

```
setup.sh                       一次性安裝腳本
scripts/
  claude-jira                  主指令（setup 後取代 claude）
  prompt-submit-hook.py        每次送出訊息時，記錄開始時間
  stop-hook.py                 每次 AI 回覆後，生成摘要並寫 Jira worklog
  log-worklog.py               呼叫 Jira REST API
config.example                 設定檔範本
```

安裝後，設定與 scripts 會複製到 `~/.claude/jira-tracker/`，hooks 會自動寫入 `~/.claude/settings.json`。
