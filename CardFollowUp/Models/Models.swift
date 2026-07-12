import Foundation
import SwiftData

// MARK: - 熱度分級

enum HeatLevel: String, CaseIterable, Identifiable, Codable {
    case hot
    case warm
    case cold

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .hot: return "🔥"
        case .warm: return "🌤"
        case .cold: return "❄️"
        }
    }

    var label: String {
        switch self {
        case .hot: return "熱"
        case .warm: return "溫"
        case .cold: return "冷"
        }
    }

    /// 熱=D+1、溫=D+3、冷=D+7
    var followUpOffsetDays: Int {
        switch self {
        case .hot: return 1
        case .warm: return 3
        case .cold: return 7
        }
    }
}

// MARK: - 跟進狀態管線

enum FollowUpStatus: String, CaseIterable, Identifiable, Codable {
    case pending
    case contacted
    case replied
    case meeting
    case won
    case lost

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: return "待跟進"
        case .contacted: return "已聯繫"
        case .replied: return "已回覆"
        case .meeting: return "約訪"
        case .won: return "成交"
        case .lost: return "流失"
        }
    }

    var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .contacted: return "paperplane"
        case .replied: return "bubble.left.and.bubble.right"
        case .meeting: return "calendar"
        case .won: return "checkmark.seal.fill"
        case .lost: return "xmark.circle"
        }
    }

    /// 仍需要跟進動作的狀態
    var isActive: Bool {
        switch self {
        case .pending, .contacted, .replied, .meeting: return true
        case .won, .lost: return false
        }
    }
}

// MARK: - 展會

@Model
final class Event {
    var name: String
    var startDate: Date
    var venue: String
    /// 攤位成本（新台幣），為 ROI 報表鋪路
    var boothCost: Double
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Contact.event)
    var contacts: [Contact] = []

    init(name: String, startDate: Date = .now, venue: String = "", boothCost: Double = 0) {
        self.name = name
        self.startDate = startDate
        self.venue = venue
        self.boothCost = boothCost
        self.createdAt = .now
    }

    var hotCount: Int { contacts.filter { $0.heat == .hot }.count }

    var contactedCount: Int { contacts.filter { $0.status != .pending }.count }

    var costPerCard: Double? {
        guard boothCost > 0, !contacts.isEmpty else { return nil }
        return boothCost / Double(contacts.count)
    }
}

// MARK: - 名片聯絡人

@Model
final class Contact {
    var name: String
    var company: String
    var title: String
    var phone: String
    var email: String
    var lineID: String

    var heatRaw: String
    var statusRaw: String

    /// OCR 原始辨識文字，供事後對照
    var rawOCRText: String
    /// 語音備註轉出的文字
    var memoTranscript: String
    /// 語音備註檔名（存於 Documents/VoiceMemos）
    var voiceMemoFileName: String?

    @Attribute(.externalStorage)
    var cardImageData: Data?

    var createdAt: Date
    var followUpDate: Date
    /// 本地推播識別碼
    var notificationKey: String

    var event: Event?

    init(
        name: String = "",
        company: String = "",
        title: String = "",
        phone: String = "",
        email: String = "",
        lineID: String = "",
        heat: HeatLevel = .warm,
        rawOCRText: String = "",
        memoTranscript: String = "",
        voiceMemoFileName: String? = nil,
        cardImageData: Data? = nil
    ) {
        self.name = name
        self.company = company
        self.title = title
        self.phone = phone
        self.email = email
        self.lineID = lineID
        self.heatRaw = heat.rawValue
        self.statusRaw = FollowUpStatus.pending.rawValue
        self.rawOCRText = rawOCRText
        self.memoTranscript = memoTranscript
        self.voiceMemoFileName = voiceMemoFileName
        self.cardImageData = cardImageData
        self.createdAt = .now
        self.followUpDate = Contact.computeFollowUpDate(heat: heat, from: .now)
        self.notificationKey = UUID().uuidString
    }

    var heat: HeatLevel {
        get { HeatLevel(rawValue: heatRaw) ?? .warm }
        set { heatRaw = newValue.rawValue }
    }

    var status: FollowUpStatus {
        get { FollowUpStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var displayName: String { name.isEmpty ? "（未命名）" : name }

    /// 依熱度計算跟進日：D+n 當天早上 9:00
    static func computeFollowUpDate(heat: HeatLevel, from date: Date = .now) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: heat.followUpOffsetDays, to: date) ?? date
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }

    func rescheduleFollowUp() {
        followUpDate = Contact.computeFollowUpDate(heat: heat, from: createdAt)
    }
}

// MARK: - 訊息範本

enum TemplateChannel: String, CaseIterable, Identifiable, Codable {
    case line
    case email

    var id: String { rawValue }

    var label: String {
        switch self {
        case .line: return "LINE"
        case .email: return "Email"
        }
    }

    var systemImage: String {
        switch self {
        case .line: return "message.fill"
        case .email: return "envelope.fill"
        }
    }
}

@Model
final class MessageTemplate {
    var name: String
    var body: String
    var channelRaw: String
    var emailSubject: String
    var createdAt: Date

    init(name: String, body: String, channel: TemplateChannel, emailSubject: String = "") {
        self.name = name
        self.body = body
        self.channelRaw = channel.rawValue
        self.emailSubject = emailSubject
        self.createdAt = .now
    }

    var channel: TemplateChannel {
        get { TemplateChannel(rawValue: channelRaw) ?? .line }
        set { channelRaw = newValue.rawValue }
    }

    static var defaults: [MessageTemplate] {
        [
            MessageTemplate(
                name: "展後致意（熱）",
                body: "{姓名}您好，我是今天在{展會名}與您交流的業務。很高興認識您！關於您有興趣的產品，我明天整理好資料寄給您，方便的話下週約個時間詳談？",
                channel: .line
            ),
            MessageTemplate(
                name: "輕觸跟進（溫／冷）",
                body: "{姓名}您好，我是{展會名}上跟您換過名片的業務。附上我們的產品型錄，若{公司}近期有相關需求，隨時歡迎聯繫我！",
                channel: .line
            ),
            MessageTemplate(
                name: "展後資料奉上",
                body: "{姓名}您好：\n\n感謝您日前蒞臨{展會名}我們的攤位。附上您索取的產品資料與報價說明，若有任何問題歡迎隨時回信或來電。\n\n期待有機會與{公司}合作！",
                channel: .email,
                emailSubject: "感謝您蒞臨{展會名}——後續資料奉上"
            ),
        ]
    }
}
