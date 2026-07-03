# CLAUDE.md — AssetPulse1

每個 session 自動載入本檔。本檔只放「每次都需要」的硬規則與路由；
細節在 `docs/agent-os/`，**按下面的觸發條件去讀，不要全部預載**。

## 硬規則（無例外）

1. **落檔即 push**：這是 ephemeral 容器，沒 push 的工作等於沒做。完成一個
   獨立單位就 `git commit` + `git push -u origin <當前工作分支>`。不推 `main`。
2. **沒有 `gh` CLI**：GitHub 操作一律用 `mcp__github__*` 工具
   （ToolSearch `select:` 載入）。不要嘗試 `gh` 或直接打 GitHub API。
3. **大量讀取不下場**：要掃 repo、讀多個大檔、查網頁、做研究時，派 subagent，
   主對話只收結論與 `檔案:行號`。派工前先讀 `docs/agent-os/10-dispatch.md`。
4. **ToolSearch 只用 `select:確切名稱`** 載入 MCP 工具，不用關鍵字瀏覽
   （會灌入大量無關 schema）。
5. **驗收先於動工**：多步驟任務先寫下驗收條件（寫在回覆或 scratchpad 任務清單），
   完成的定義是通過驗收，不是「改完了」。
6. TLS / proxy 錯誤：查 `/root/.ccr/README.md`。永遠不要關 TLS 驗證。
7. 暫存檔用 system prompt 給的 scratchpad 目錄，不要用 `/tmp`。

## 路由表（觸發條件 → 讀哪個檔）

| 情境 | 先讀 |
|---|---|
| 要派 subagent、選 model/effort、任務卡住考慮升級 | `docs/agent-os/10-dispatch.md` |
| 不確定「算不算完成」「該不該問使用者」「要不要換方向」 | `docs/agent-os/20-judgment.md` |
| 要寫派工 prompt（搜尋/實作/重構/研究/審查） | `docs/agent-os/30-templates.md` |
| 要修改 CLAUDE.md 或 docs/agent-os/ 任何檔案 | `docs/agent-os/40-maintenance.md` |
| session 開場想了解這個環境的背景與陷阱 | `docs/agent-os/50-letter.md` |
| 踩坑之後、或想避開前人踩過的坑 | `docs/agent-os/LESSONS.md` |
| 想知道這些規則為什麼存在 | `docs/agent-os/00-diagnosis.md` |

## 預設工作迴圈（多步驟任務）

1. 寫任務清單：目標、驗收條件、步驟（3–7 行，放 scratchpad）。
2. 大量資訊蒐集 → 派 subagent；小型精準操作 → 自己做。
3. 每完成一步：更新清單、能 push 就 push。
4. 驗收：檔案 read-back；程式碼跑測試或實跑；高風險判斷派 fresh-context
   subagent 覆核（不自驗規則見 `10-dispatch.md` §6，品質底線見 `20-judgment.md` §5）。
5. 同一修法失敗 2 次 → 停，讀 `10-dispatch.md` 的升級路徑。

## 本 repo 現況

Repo 目前沒有應用程式碼（制度檔先行）。開始有程式碼後，把建置/測試指令
補進本節（怎麼補見 `40-maintenance.md`）。
