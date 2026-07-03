# LESSONS — 踩坑紀錄（append-only）

寫法與精簡規則見 `40-maintenance.md` §3–§4。新條目加在檔尾。

## 2026-07-03 沒有 gh CLI，GitHub 一律走 MCP
情境：本環境（Claude Code on the web remote container）做 GitHub 操作。
坑：`gh` 不存在；直接 curl GitHub API 也不可靠（proxy + 認證）。
解法/繞法：ToolSearch `select:` 載入 `mcp__github__*` 工具使用。
建議：已寫入 CLAUDE.md 硬規則 2。

## 2026-07-03 effort 只能在 agent 定義檔設定
情境：想派 subagent 並指定 reasoning effort。
坑：Agent tool 呼叫參數只有 `model`，沒有 effort。
解法/繞法：effort 寫在 `.claude/agents/<名>.md` frontmatter
（`effort: low|medium|high|xhigh|max`）；已建 `verifier`（sonnet, high）。
主對話自己的 effort 用 `/effort` 或 settings 的 `effortLevel`。
（來源：code.claude.com/docs/en/sub-agents.md，2026-07-03 由 claude-code-guide 確認）
