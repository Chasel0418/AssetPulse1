# 名片跟進（CardFollowUp）— iOS MVP

幫台灣中小企業的參展人員，在展會結束後 72 小時內，把一疊名片變成「已分級、已行動」的跟進清單——透過 LINE 和 Email，而不是 Salesforce。

**策略：不跟 CamCard 拚掃描，拚「掃描之後的 72 小時」。**

## 開發環境需求

- Xcode 16 以上
- iOS 17.0 以上（實機測試建議，模擬器沒有相機，可改用相簿匯入）
- 免 Apple Developer 付費帳號即可跑實機（個人簽章）

開啟方式：用 Xcode 打開 `CardFollowUp.xcodeproj`，在 Signing & Capabilities 選自己的 Team，直接跑。

## MVP 功能對照

| # | 規格功能 | 實作位置 |
|---|---------|---------|
| 1 | 名片拍照＋OCR（中日英、離線、零 API 成本） | `Services/OCRService.swift`（Apple Vision）＋ `Services/CardFieldParser.swift`（欄位解析：姓名／公司／職稱／電話／Email／LINE ID） |
| 2 | 快速確認畫面（預設 OCR 會有錯） | `Views/Capture/ContactReviewView.swift`，每欄位可即時修正，可展開對照辨識原文 |
| 3 | 三級熱度標籤 🔥🌤❄️ | 確認畫面一次點選完成，直接決定跟進排程 |
| 4 | 語音備註（15 秒）＋轉文字 | `Services/SpeechService.swift`（AVAudioRecorder + SFSpeechRecognizer zh-TW），按住錄音、放開結束 |
| 5 | 展會分組（日期／攤位成本） | `Models/Models.swift` 的 `Event`，詳情頁自動算「每張名片取得成本」 |
| 6 | 自動跟進排程（熱 D+1／溫 D+3／冷 D+7） | `Services/NotificationService.swift` 本地推播，早上 9:00 提醒；展會當晚 21:00 推「今天收了 N 張名片」 |
| 7 | 訊息範本＋變數 {姓名}{公司}{職稱}{展會名} | `Services/TemplateEngine.swift`＋範本管理頁；一鍵複製並開 LINE（有 LINE ID 直接開加好友頁）或 Email 草稿 |
| 8 | 狀態管線 | 待跟進→已聯繫→已回覆→約訪→成交／流失；點範本動作自動標「已聯繫」 |
| 9 | CSV 匯出 | `Services/CSVExporter.swift`，含 BOM（Excel 中文不亂碼），從展會詳情頁分享 |

另含三頁 onboarding（`Views/Onboarding/`），首次啟動介紹核心流程並請求推播權限。

## 架構

- **SwiftUI + SwiftData**（iOS 17），純本機儲存，無後端、無帳號系統
- 名片照片以 `externalStorage` 存放；語音檔存 `Documents/VoiceMemos/`
- 分頁：展會／跟進（逾期・今天・未來 7 天）／範本／設定

```
CardFollowUp/
├── CardFollowUpApp.swift        # App 進入點
├── Models/Models.swift          # Event, Contact, MessageTemplate + 熱度/狀態 enum
├── Services/                    # OCR、欄位解析、語音、推播、範本、CSV
└── Views/                       # 依功能分資料夾（Events/Capture/Contacts/FollowUp/Templates/Settings/Onboarding）
```

## 明確不做（V1 範圍外）

CRM 整合、團隊協作、NFC 名片、自建 OCR、Android、LINE 官方 API 自動發送（V1 用「複製＋開啟 LINE」規避法規與帳號風險）。

## 下一步（尚未實作）

- 免費版限制（每場展會 20 張）＋ StoreKit 2 訂閱（Pro NT$1,690/年，14 天試用）
- ROI 報表視覺化（攤位成本 vs 成交）
- ASO 素材與 App Store 上架流程
