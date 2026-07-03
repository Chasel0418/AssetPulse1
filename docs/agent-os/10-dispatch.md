# 10 — 模型調度守則

觸發：要派 subagent、選 model/effort、或任務卡住考慮升級時讀本檔。
依據：`00-diagnosis.md` 問題 1 與 3。

## 1. 指揮官不下場

主對話（你）是指揮官。**指揮官的 context 是全 session 最貴的資源**，
只放決策需要的資訊。

必須派 subagent 的工作（不是建議，是規則）：
- 掃 repo / 找「某東西在哪」而目標檔未知 → `Explore`
- 讀 3 個以上檔案、或任何單檔 >500 行且只需要其中一部分 → `Explore` 或 `general-purpose`
- 查網頁、讀外部文件、做研究 → `general-purpose`
- 批次改檔（同型修改套用到多處） → `general-purpose`
- 查 Claude Code / Claude API 的功能與語法 → `claude-code-guide`（不要憑記憶答）
- 驗收覆核 → `verifier`（見 §6）

主對話親手做的工作：
- 讀 ≤3 個**已知路徑**的目標檔（且只讀需要的行段，用 offset/limit）
- 單點編輯、跑指令、git 操作
- 做決策、跟使用者對話

判準一句話：**「讀完才知道有沒有用」的讀取 → 派出去；「已知要什麼」的操作 → 自己做。**

## 2. 派工三件套

每個派工 prompt 必含三段，缺一段就先補再派（模板見 `30-templates.md`）：

1. **目標與動機**：要達成什麼、為什麼（動機讓 subagent 在邊界情況做對取捨）。
2. **驗收條件**：可核對的具體條件（「找到定義位置並給出行號」而非「幫我看看」）。
3. **回報格式**：明確規定回什麼、多長、什麼形式（見 §4 回報合約）。

另外必給：**範圍邊界**（哪些目錄/檔案在範圍內、什麼不要動）。subagent 是
冷啟動，你沒說的它一律不知道——不要假設它知道對話裡談過的任何事。

## 3. 顯式指定 model 與 effort

本環境實際可用（以你的 Agent tool schema 為準；以下是 2026-07 確認的狀態）：

- Agent tool 的 `model` 參數：`haiku` / `sonnet` / `opus`（可能還有其他，
  以 schema enum 為準）。不指定則用 agent 定義的預設或繼承主對話。
- **effort 無法在 Agent tool 呼叫時指定**，只能寫在 `.claude/agents/<名>.md`
  frontmatter（`effort: low|medium|high|xhigh|max`）。需要特定 effort 的
  常用角色，就建一個 agent 定義檔（本 repo 已有 `.claude/agents/verifier.md`）。
- 主對話自己的 effort：`/effort <level>` 指令，或 `.claude/settings.json` 的
  `"effortLevel"`（low–xhigh）。

選型預設表：

| 任務 | model | 理由 |
|---|---|---|
| 機械式搜尋、glob/grep 彙整、格式轉換 | `haiku` | 便宜，錯了也容易發現 |
| 一般探索、實作、研究、批次改檔 | `sonnet` | 預設主力 |
| 跨模組設計、難 bug 診斷、驗收覆核、第二意見 | `opus` | 只在判斷品質值錢時用 |

## 4. 回報合約

寫進每個派工 prompt 的固定文字（可直接抄）：

> 回報只包含：(1) 結論（≤10 行）；(2) 關鍵證據，用 `檔案路徑:行號` 引用，
> 不要貼大段原文；(3) 你不確定的點，標 UNCONFIRMED。
> 長產物（報告、diff、清單）寫到指定路徑的檔案，回報只給路徑。
> 不要回報你的探索過程。

主對話收到回報後：只把**結論**帶進後續推理；需要細節再去讀它落的檔。

## 5. 升降級路徑

- **haiku 錯一次**：不重試，直接升 `sonnet` 重派。
- **sonnet 同一子任務連錯兩次**：升 `opus` 重派，且 prompt 必須附
  **完整失敗軌跡**：兩次分別嘗試了什麼、觀察到什麼錯誤輸出（原文）、
  你目前的假設。不附軌跡的升級會重蹈覆轍。
- **opus 也連錯兩次**：停。這超出本環境能力，向使用者報告卡點與已試路徑，
  附上你建議的下一步。不要第三輪。
- **降級**：一旦某類問題被解出（模式確立），把解法寫成明確步驟，
  降回 `haiku`/`sonnet` 批次套用剩餘實例。
- **重試上限**：同一件事（同一假設、同一修法）最多兩輪。第三次嘗試前必須
  換假設、換方法、或換模型——三者至少改一個。

## 6. 驗證不自驗

做的人不當驗的人。驗收一律派 **fresh-context** agent（新派一個，不是續用
做事的那個），而且**只給驗收條件，不給實作者的推理過程**——給了推理它就會
順著推理點頭。

- 檔案/文件產出：驗收 agent read-back 關鍵段落，逐條核對驗收條件。
- 程式碼：跑測試或實跑（用 `verify` skill 的精神：驅動受影響的流程，
  不是只跑 typecheck）。
- 高風險判斷（架構選擇、對外行為、不可逆操作）：加第二意見——派 `opus`
  verifier 獨立評估；或讓兩個 subagent 各給一個答案，主對話當評審選優。
- 本 repo 備有 `.claude/agents/verifier.md`（sonnet, effort high），
  派法：`Agent(subagent_type: "verifier", prompt: <驗收條件+檢查對象路徑>)`。
  高風險時呼叫時覆寫 `model: "opus"`。

## 7. MCP 工具速查（用 `select:` 精準載入）

| 要做什麼 | ToolSearch query |
|---|---|
| 看 PR / 讀 PR diff、留言、CI 狀態 | `select:pull_request_read` |
| 開 PR | `select:create_pull_request` |
| 讀/開/改 issue | `select:issue_read,issue_write` |
| 查 CI job log | `select:get_job_logs,get_check_run` |
| 訂閱 PR 事件（babysit PR） | `select:subscribe_pr_activity` |
| 排程/提醒自己 | ToolSearch `select:` Claude_Code_Remote 的 `send_later` |
| 網頁抓取/搜尋 | `select:WebFetch,WebSearch`（但研究類請派 subagent 去做） |

Adobe / Higgsfield / Google Drive / Spotify 的工具只在使用者明確要求
相應功能時才載入，平常完全不要碰。
