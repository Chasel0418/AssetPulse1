import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [(icon: String, title: String, message: String)] = [
        (
            "camera.viewfinder",
            "展場上，10 秒收好一張名片",
            "拍照自動辨識 → 滑一下標熱度 🔥🌤❄️ → 按住錄 15 秒語音備註。太吵不能打字？用說的就好。"
        ),
        (
            "bell.badge.fill",
            "展後 72 小時，自動排好跟進",
            "熱名單隔天提醒、溫名單 3 天、冷名單 7 天。當晚 9 點還會提醒你：今天收了幾張、幾張是熱的。"
        ),
        (
            "message.badge.filled.fill",
            "一鍵開 LINE，不用打字",
            "範本自動帶入對方姓名、公司、展會名，複製後直接開 LINE 或 Email。最後匯出 CSV 給老闆看成果。"
        ),
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 20) {
                        Image(systemName: pages[index].icon)
                            .font(.system(size: 72))
                            .foregroundStyle(.tint)
                        Text(pages[index].title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[index].message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    Task {
                        _ = await NotificationService.requestAuthorization()
                        onFinish()
                    }
                }
            } label: {
                Text(page < pages.count - 1 ? "下一步" : "開始使用")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .padding(.top, 40)
    }
}

#Preview {
    OnboardingView {}
}
