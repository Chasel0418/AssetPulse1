# 00 — Harness 快速診斷（2026-07-03，由 Fable 5 session 撰寫）

本檔是整套 agent-os 制度的依據。後面每份檔案的規則，都對應這裡的某個問題。
讀者：未來在此環境運作的任何 Claude session（預設假設是 Sonnet 等級）。

## 環境事實（先確認，不要憑印象）

- 這是 **remote ephemeral container**（Claude Code on the web）。容器閒置就回收，
  **沒有 commit + push 的東西一律消失**。沒有跨 session 的隱藏記憶。
- Repo：`Chasel0418/AssetPulse1`（GitHub 上的實際大小寫，傳給 MCP 工具照這個寫）。
  工作分支由每個 session 的 system prompt 指定
  （`claude/...` 開頭），不要直接推 `main`。
- **沒有 `gh` CLI**。所有 GitHub 操作走 `mcp__github__*` 工具（用 ToolSearch 載入）。
  弱模型最常犯的錯之一就是打 `gh pr create` 然後對錯誤訊息瞎猜——直接禁用。
- 對外 HTTPS 走 agent proxy（CA bundle：`/root/.ccr/ca-bundle.crt`）。TLS 錯誤或
  403/407 時查 `/root/.ccr/README.md`，**永遠不要**關 TLS 驗證或 unset HTTPS_PROXY。
- 掛了大量 MCP server：github（~60 工具）、Adobe（~80）、Higgsfield（~70）、
  Google Drive、Spotify、Claude_Code_Remote。全部是 deferred tools，
  schema 要用 ToolSearch 載入後才能呼叫。
- Agent tool 可用的 subagent 類型：`Explore`（唯讀搜尋）、`Plan`（規劃）、
  `general-purpose`（全工具）、`claude-code-guide`（查 Claude Code/API 文件）、
  `claude`（泛用）。model 可覆寫為 `haiku` / `sonnet` / `opus`
  （本 session 另有 `fable`，未來不保證存在——用你的 Agent tool schema 實際列的值為準）。
- 主觀察：暫存檔一律用 system prompt 給的 scratchpad 目錄，不要用 `/tmp`。

## 前三名問題與修法

### 1. Token 最大漏洞：主對話自己下場做大量讀取

**症狀**：主對話直接 Read 整個大檔、連續 Grep 掃 repo、WebFetch 長網頁、
ToolSearch 用關鍵字瀏覽出一大串 MCP schema。幾輪之後 context 被原始資料塞滿，
觸發 summarization，早期指令細節丟失，模型開始重複已做過的事或忘記驗收條件。

**修法**（詳見 `10-dispatch.md`）：
- 凡是「讀完才知道有沒有用」的大量讀取——掃 repo、查文件、讀多個大檔、網頁研究——
  一律派 subagent（Explore 或 general-purpose），主對話只收結論 + `檔案:行號`。
- 主對話只親手做：≤3 個已知目標檔的精準讀取、小型編輯、跑指令、做決策。
- ToolSearch 只用 `select:確切工具名`，不用關鍵字瀏覽。需要哪個工具查
  `10-dispatch.md` 的對照表。

### 2. 最容易失焦：ephemeral 環境 + 無落檔紀律 = 每個 session 從零開始

**症狀**：工作做到一半 session 中斷，成果沒 push，下個 session 整個重來；
或者做了 A 又去做 B，回頭時忘了 A 的驗收條件；或者跨 session 的教訓
（例如「這個 proxy 要這樣設」）每次重新踩一遍。

**修法**：
- **完成一個可獨立成立的單位就立刻 commit + push**（`git push -u origin <分支>`，
  網路錯誤按 2s/4s/8s/16s 退避重試最多 4 次）。不要攢一大包。
- 多步驟任務開始前，先在 scratchpad 寫一份 3–7 行的任務清單（目標、驗收條件、
  目前進度），每完成一步更新。context 被 summarize 後這份清單就是你的錨。
- 踩到環境坑（工具名錯、proxy、權限）就把教訓寫進 `docs/agent-os/LESSONS.md`
  並隨當次工作一起 push（格式見 `40-maintenance.md`）。

### 3. 最容易出錯：自己寫、自己驗、自己宣布完成

**症狀**：模型改完程式碼跑一下 typecheck 就說「完成」；寫完檔案不 read-back；
測試失敗時把失敗解讀成「環境問題」繼續前進；同一個錯誤修法重試三四次不換路。

**修法**（詳見 `20-judgment.md`）：
- 「完成」的定義是**通過驗收條件**，不是「我改完了」。每個任務開工前先寫下
  驗收條件；沒有驗收條件的任務先補條件再動手。
- 驗證用**新視角**：寫入的檔案用 read-back（重新 Read 關鍵段落比對意圖）；
  程式碼用測試或實跑；重要判斷派一個 fresh-context subagent 帶著驗收條件
  獨立檢查，**不要把你的推理過程餵給它**，只給它「檢查什麼、標準是什麼」。
- 同一修法失敗 2 次 = 假設方向錯了，停下來換診斷路徑或升級模型
  （升降級規則見 `10-dispatch.md`）。

## 誠實條款：這套制度補不了的東西

拆解、驗證、多樣本評審能把**執行品質**拉到接近強模型，但兩類問題補不了：

1. **模糊題**（需求本身不清楚、目標互相衝突）：制度只能幫你「發現它是模糊題」
   （判準見 `20-judgment.md` 的停下來問使用者一節），解法是問使用者，不是硬做。
2. **品味判斷**（架構取捨、命名、寫作語感、設計美感）：checklist 只能守底線。
   遇到高風險品味題：(a) 產 2–3 個候選讓使用者選，或 (b) 明說「這題我的等級
   給不出可靠判斷」，不要假裝有把握。

不確定的事實：查（claude-code-guide agent、官方文件）。查不到：寫 UNCONFIRMED，
不要編。
