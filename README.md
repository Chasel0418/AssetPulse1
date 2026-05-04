# 資產脈動 AssetPulse

跨市場（美股/台股/日股/港股）與多幣別（TWD/USD/JPY）資產追蹤 App，支援券商持倉截圖匯入、即時報價與淨值整合。

## 功能亮點

- 整合資產：股票、現金、貸款，計算總資產、總負債與淨值。
- 即時行情：跨市場股票即時/延遲報價（依資料源授權）。
- 匯率換算：以基準幣別換算全部資產價值。
- 券商匯入：上傳截圖（Firstrade、IB、國泰等）以 OCR + 模板解析持倉。
- 手機優先：以 React Native + Expo 建置，流暢運行於 iOS/Android。

## 技術架構（MVP）

- App：Expo + React Native + TypeScript
- 狀態管理：Zustand
- 導航：React Navigation
- API：Node.js/Express（建議另建 repo）
- 資料來源：
  - 行情：IEX/Polygon/Alpha Vantage（美股），台股/日股/港股可串接授權供應商
  - 匯率：exchangerate.host 或銀行牌告 API
- OCR：Google Vision / AWS Textract / Apple Vision（端上）

## 快速開始

```bash
npm install
npm run start
```

> 本 repo 目前提供前端 MVP 骨架與資料模型，方便快速延伸。
