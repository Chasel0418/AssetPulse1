import SwiftData
import SwiftUI

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MessageTemplate.createdAt) private var templates: [MessageTemplate]
    @State private var editingTemplate: MessageTemplate?
    @State private var showNewTemplate = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(templates) { template in
                        Button {
                            editingTemplate = template
                        } label: {
                            HStack {
                                Image(systemName: template.channel.systemImage)
                                    .foregroundStyle(template.channel == .line ? .green : .blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name).foregroundStyle(.primary)
                                    Text(template.body)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(templates[index])
                        }
                    }
                } footer: {
                    Text("範本支援變數：\(TemplateEngine.availableVariables.joined(separator: " "))，發送時自動帶入。")
                }
            }
            .navigationTitle("訊息範本")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewTemplate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorView(template: template)
            }
            .sheet(isPresented: $showNewTemplate) {
                TemplateEditorView(template: nil)
            }
        }
    }
}
