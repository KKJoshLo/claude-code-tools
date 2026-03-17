# Claude Code 工具箱

這是一個專為 [Claude Code](https://claude.ai/claude-code) 打造的小工具集合，目標是讓日常開發流程更順暢。

---

## 工具列表

### [jira-time-tracker](./jira-time-tracker)

在 Claude Code 對話時，自動將工作時間記錄到對應的 Jira ticket worklog。

**功能亮點：**
- 每輪對話自動計時，結束後呼叫 AI 生成 ≤100 字繁體中文摘要寫入 Jira
- 從 git branch 名稱自動偵測 Jira ticket ID（如 `feature/B2CBE-2083-xxx` → `B2CBE-2083`）
- 短回覆（`ok`、`yes` 等）不單獨記錄，時間自動合併到下一輪
- 一鍵安裝：透過 Claude Code plugin 系統安裝，`/jira-setup` 完成設定即可使用

**前置需求：** macOS、Claude Code、Python 3、Git

---

## 前置需求（共用）

- macOS
- [Claude Code](https://claude.ai/claude-code) 已安裝並登入

---

## 目錄結構

```
claude/
└── jira-time-tracker/   # Jira worklog 自動記錄工具
```

---

## 貢獻 / 新增工具

如需新增工具，在此目錄下建立對應子目錄，並附上自己的 `README.md` 說明安裝與使用方式即可。
