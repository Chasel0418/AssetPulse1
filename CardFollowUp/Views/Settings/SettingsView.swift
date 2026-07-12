import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section("通知") {
                    LabeledContent("推播權限", value: notificationStatusLabel)
                    if notificationStatus == .denied {
                        Button("前往系統設定開啟") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    } else if notificationStatus == .notDetermined {
                        Button("開啟跟進提醒") {
                            Task {
                                _ = await NotificationService.requestAuthorization()
                                await refreshStatus()
                            }
                        }
                    }
                }

                Section("跟進規則") {
                    LabeledContent("🔥 熱", value: "隔天（D+1）早上 9:00 提醒")
                    LabeledContent("🌤 溫", value: "3 天後（D+3）早上 9:00 提醒")
                    LabeledContent("❄️ 冷", value: "7 天後（D+7）早上 9:00 提醒")
                    LabeledContent("展會當晚", value: "21:00 提醒整理今日名片")
                }

                Section("關於") {
                    LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                    LabeledContent("資料儲存", value: "全部存在本機，不上傳雲端")
                    LabeledContent("OCR 引擎", value: "Apple Vision（離線）")
                }
            }
            .navigationTitle("設定")
            .task { await refreshStatus() }
        }
    }

    private var notificationStatusLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "已開啟"
        case .denied: return "已關閉"
        case .notDetermined: return "尚未設定"
        @unknown default: return "未知"
        }
    }

    private func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }
}
