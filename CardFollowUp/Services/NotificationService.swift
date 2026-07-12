import Foundation
import UserNotifications

/// 本地推播：跟進提醒（依熱度 D+1／D+3／D+7）與展會當晚 21:00 的整理提醒。
enum NotificationService {

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: - 跟進提醒

    static func scheduleFollowUp(for contact: Contact) {
        cancelFollowUp(for: contact)
        guard contact.status.isActive, contact.followUpDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(contact.heat.emoji) 該跟進了：\(contact.displayName)"
        var bodyParts: [String] = []
        if !contact.company.isEmpty { bodyParts.append(contact.company) }
        if !contact.memoTranscript.isEmpty {
            bodyParts.append("備註：\(contact.memoTranscript.prefix(50))")
        } else if let eventName = contact.event?.name {
            bodyParts.append("來自「\(eventName)」")
        }
        content.body = bodyParts.isEmpty ? "點開查看聯絡資料，一鍵傳 LINE 或 Email。" : bodyParts.joined(separator: "｜")
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: contact.followUpDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "followup-\(contact.notificationKey)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelFollowUp(for contact: Contact) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["followup-\(contact.notificationKey)"])
    }

    // MARK: - 展會當晚整理提醒

    /// 每掃一張名片就更新一次當晚 21:00 的摘要推播。
    static func scheduleEveningDigest(totalToday: Int, hotToday: Int) {
        let identifier = "evening-digest"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard totalToday > 0 else { return }
        let calendar = Calendar.current
        guard let ninePM = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: .now),
              ninePM > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "今天收了 \(totalToday) 張名片"
        content.body = hotToday > 0
            ? "\(hotToday) 張標記為熱 🔥，要現在排跟進嗎？"
            : "趁記憶還新鮮，現在花 3 分鐘排好跟進吧。"
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: ninePM)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
