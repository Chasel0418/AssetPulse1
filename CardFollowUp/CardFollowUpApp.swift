import SwiftData
import SwiftUI

@main
struct CardFollowUpApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Event.self, Contact.self, MessageTemplate.self])
    }
}
