import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            EventListView()
                .tabItem { Label("展會", systemImage: "building.2") }

            FollowUpListView()
                .tabItem { Label("跟進", systemImage: "bell.badge") }

            TemplateListView()
                .tabItem { Label("範本", systemImage: "text.bubble") }

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .task {
            seedDefaultTemplatesIfNeeded()
            if !hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
            .interactiveDismissDisabled()
        }
    }

    private func seedDefaultTemplatesIfNeeded() {
        let descriptor = FetchDescriptor<MessageTemplate>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }
        for template in MessageTemplate.defaults {
            modelContext.insert(template)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Event.self, Contact.self, MessageTemplate.self], inMemory: true)
}
