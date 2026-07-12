import SwiftData
import SwiftUI

struct EventListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate, order: .reverse) private var events: [Event]
    @State private var showNewEvent = false

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView {
                        Label("還沒有展會", systemImage: "building.2")
                    } description: {
                        Text("建立一場展會，開始掃名片。\n每場展會一個資料夾，展後直接匯出成果報表。")
                    } actions: {
                        Button("建立展會") { showNewEvent = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(events) { event in
                            NavigationLink(value: event) {
                                EventRowView(event: event)
                            }
                        }
                        .onDelete(perform: deleteEvents)
                    }
                }
            }
            .navigationTitle("展會")
            .navigationDestination(for: Event.self) { event in
                EventDetailView(event: event)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewEvent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewEvent) {
                EventFormView()
            }
        }
    }

    private func deleteEvents(at offsets: IndexSet) {
        for index in offsets {
            let event = events[index]
            for contact in event.contacts {
                NotificationService.cancelFollowUp(for: contact)
            }
            modelContext.delete(event)
        }
    }
}

struct EventRowView: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.name)
                .font(.headline)
            HStack(spacing: 12) {
                Label(event.startDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                Label("\(event.contacts.count) 張", systemImage: "person.crop.rectangle.stack")
                if event.hotCount > 0 {
                    Text("🔥 \(event.hotCount)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
