import SwiftData
import SwiftUI

struct EventFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var event: Event?

    @State private var name = ""
    @State private var startDate = Date.now
    @State private var venue = ""
    @State private var boothCostText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("展會資訊") {
                    TextField("展會名稱（例：2026 台北國際食品展）", text: $name)
                    DatePicker("開始日期", selection: $startDate, displayedComponents: .date)
                    TextField("地點／攤位號（選填）", text: $venue)
                }
                Section {
                    TextField("攤位成本（NT$，選填）", text: $boothCostText)
                        .keyboardType(.numberPad)
                } footer: {
                    Text("填了攤位成本，展後報表會自動算出每張名片的取得成本。")
                }
            }
            .navigationTitle(event == nil ? "新增展會" : "編輯展會")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let event {
                    name = event.name
                    startDate = event.startDate
                    venue = event.venue
                    boothCostText = event.boothCost > 0 ? String(Int(event.boothCost)) : ""
                }
            }
        }
    }

    private func save() {
        let cost = Double(boothCostText.filter(\.isNumber)) ?? 0
        if let event {
            event.name = name
            event.startDate = startDate
            event.venue = venue
            event.boothCost = cost
        } else {
            let newEvent = Event(name: name, startDate: startDate, venue: venue, boothCost: cost)
            modelContext.insert(newEvent)
        }
        dismiss()
    }
}
