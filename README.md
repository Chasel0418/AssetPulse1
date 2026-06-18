# AssetPulse — 信用卡花費整理與發票核銷

每個月自動從 **Gmail** 抓信用卡刷卡通知與電子發票，做**金額＋日期＋商家**比對核銷，
再把結果整理進 **Notion**。設計成跑在你自己的 Mac 上，憑證與財務資料都留在本機。

```
Gmail（刷卡通知 + 電子發票）
        │  抓信
        ▼
   解析器 parsers/  ──►  Transaction（交易） / Invoice（發票）
        │  核銷（金額＋日期區間＋商家相似度）
        ▼
   reconciler  ──►  ✅ 已核銷 / ⚠️ 待確認 / ❌ 缺發票
        │  輸出
        ▼
      Notion Database
```

## 先看這個：可行性與限制

- **信用卡花費**靠 Gmail 抓「刷卡即時通知」或電子帳單。各家銀行信件格式不同，
  內建的 `generic` 解析器是**起點**，第一次使用請拿你自己的信件樣本調整正則
  （見 `assetpulse/parsers/generic.py`）。
- **發票**這裡走 **email 電子發票**（電商、店家寄來的）。
  > 補充：台灣財政部的「手機條碼載具」**沒有對個人開放的官方 API**。
  > 若要納入載具消費，目前最穩的方式是從財政部平台手動匯出 CSV 再餵進來；
  > 用爬蟲登入抓取有違反服務條款與帳號風險，不建議。
- **隱私**：`.env`、`credentials.json`、`token.json`、`data/` 都已被 `.gitignore` 排除，
  不會進版控。請務必在自己的 Mac 上跑，不要把真實憑證放到雲端。

## 在 Mac 上安裝

```bash
git clone <你的 repo 網址>
cd AssetPulse1

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cp config.example.yaml config.yaml
cp .env.example .env
```

### 1. 開通 Gmail API（唯讀）

1. 到 [Google Cloud Console](https://console.cloud.google.com/) 建一個專案。
2. 啟用 **Gmail API**。
3. 「API 和服務 → 憑證 → 建立憑證 → OAuth 用戶端 ID → 桌面應用程式」。
4. 下載 JSON，存成專案根目錄的 `credentials.json`。
5. 第一次授權：

   ```bash
   python -m assetpulse auth
   ```

   會開瀏覽器要你登入授權，成功後 token 存進 `token.json`，之後不用再登入。

### 2. 設定 Notion

1. 到 [My integrations](https://www.notion.so/my-integrations) 建一個 integration，複製 token。
2. 在 Notion 建一個 Database，欄位建議：
   `商家`(Title)、`日期`(Date)、`金額`(Number)、`末四碼`(Text)、
   `狀態`(Select：matched/ambiguous/unmatched)、`發票號碼`(Text)、`發票賣方`(Text)。
3. 在該 Database 右上「⋯ → Connections」把剛建的 integration 加進去（分享權限）。
4. 把 token 和 Database ID 填進 `.env`（Database ID 是網址裡那段 32 碼）。

### 3. 設定抓信規則

編輯 `config.yaml` 的 `sources`，把 `query` 改成你的銀行寄件地址與發票關鍵字。
`query` 用的是 [Gmail 搜尋語法](https://support.google.com/mail/answer/7190)，
例如 `from:ecard@cathaybk.com.tw newer_than:35d`。

## 使用

```bash
# 不用憑證，用內建假資料跑通整條流程（先確認環境 OK）
python -m assetpulse run --sample

# 真的抓信、核銷，結果印在終端機（還不寫 Notion）
python -m assetpulse run

# 抓信、核銷，並寫進 Notion
python -m assetpulse run --notion
```

`--sample` 的輸出範例：

```
狀態    日期                  金額  商家 → 發票
----------------------------------------------------------------
✅  2026-06-03        1280  星巴克 統一星巴克 → 統一星巴克股份有限公司
✅  2026-06-07         599  Netflix → Netflix
⚠️   2026-06-15          88  7-ELEVEN → —     （金額日期吻合但店名差太多，待人工確認）
❌  2026-06-18       12000  蝦皮購物 → —     （找不到對應發票）
```

### 每月自動執行（選用）

用 macOS 的 `launchd` 或 `cron` 每月排程：

```bash
# 每月 5 號早上 9 點跑（crontab -e）
0 9 5 * * cd /path/to/AssetPulse1 && .venv/bin/python -m assetpulse run --notion
```

## 專案結構

```
assetpulse/
  cli.py            命令列入口（auth / run）
  pipeline.py       串接：抓信 → 解析 → 核銷
  config.py         讀 config.yaml 與 .env
  gmail_client.py   Gmail OAuth 與抓信、抽 PDF
  models.py         Transaction / Invoice / MatchResult
  reconciler.py     核銷引擎（金額＋日期＋商家比對）
  notion_writer.py  寫入 Notion Database
  parsers/          可插拔解析器（generic + 註冊表）
tests/              核銷邏輯單元測試（純標準函式庫，免憑證）
samples/fixtures/   假資料，給 --sample 用
```

## 測試

```bash
pip install pytest
python -m pytest -q
```

## 之後可以延伸

- 為你的銀行寫專屬解析器（`parsers/` 新增後在 `registry.py` 註冊）。
- 加入載具 CSV 匯入來源。
- 把每月摘要也寫成 Notion 頁面，或同步一份到 Google Sheets。
- 重複核銷防呆：記住已處理過的 Gmail message id，避免下個月重複匯入。
