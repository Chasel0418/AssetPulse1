import SwiftData
import SwiftUI

/// 今日待辦：依跟進日分組（已逾期／今天／未來 7 天）。
struct FollowUpListView: View {
    @Query(sort: \Contact.followUpDate) private var allContacts: [Contact]

    private var activeContacts: [Contact] {
        allContacts.filter { $0.status.isActive }
    }

    private var overdue: [Contact] {
        let todayStart = Calendar.current.startOfDay(for: .now)
        return activeContacts.filter { $0.followUpDate < todayStart }
    }

    private var dueToday: [Contact] {
        let calendar = Calendar.current
        return activeContacts.filter { calendar.isDateInToday($0.followUpDate) }
    }

    private var upcoming: [Contact] {
        let calendar = Calendar.current
        let tomorrowStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let weekLater = calendar.date(byAdding: .day, value: 7, to: tomorrowStart) ?? tomorrowStart
        return activeContacts.filter { $0.followUpDate >= tomorrowStart && $0.followUpDate < weekLater }
    }

    var body: some View {
        NavigationStack {
            Group {
                if overdue.isEmpty && dueToday.isEmpty && upcoming.isEmpty {
                    ContentUnavailableView {
                        Label("目前沒有待跟進", systemImage: "checkmark.circle")
                    } description: {
                        Text("掃描名片並標好熱度後，跟進排程會自動出現在這裡。\n熱 D+1・溫 D+3・冷 D+7")
                    }
                } else {
                    List {
                        followUpSection(title: "⚠️ 已逾期", contacts: overdue)
                        followUpSection(title: "今天", contacts: dueToday)
                        followUpSection(title: "未來 7 天", contacts: upcoming)
                    }
                }
            }
            .navigationTitle("跟進")
            .navigationDestination(for: Contact.self) { contact in
                ContactDetailView(contact: contact)
            }
        }
    }

    @ViewBuilder
    private func followUpSection(title: String, contacts: [Contact]) -> some View {
        if !contacts.isEmpty {
            Section("\(title)（\(contacts.count)）") {
                ForEach(contacts) { contact in
                    NavigationLink(value: contact) {
                        ContactRowView(contact: contact, showEventName: true)
                    }
                }
            }
        }
    }
}
