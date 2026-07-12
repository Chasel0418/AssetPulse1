import SwiftData
import SwiftUI

struct TemplateEditorView: View {
    let template: MessageTemplate?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var channel: TemplateChannel = .line
    @State private var emailSubject = ""
    @State private var body_ = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("範本") {
                    TextField("範本名稱", text: $name)
                    Picker("發送管道", selection: $channel) {
                        ForEach(TemplateChannel.allCases) { channel in
                            Text(channel.label).tag(channel)
                        }
                    }
                    .pickerStyle(.segmented)
                    if channel == .email {
                        TextField("Email 主旨", text: $emailSubject)
                    }
                }

                Section("內容") {
                    TextEditor(text: $body_)
                        .frame(minHeight: 140)
                }

                Section("插入變數") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TemplateEngine.availableVariables, id: \.self) { variable in
                                Button(variable) {
                                    body_ += variable
                                }
                                .font(.caption.bold())
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(template == nil ? "新增範本" : "編輯範本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                            || body_.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let template {
                    name = template.name
                    channel = template.channel
                    emailSubject = template.emailSubject
                    body_ = template.body
                }
            }
        }
    }

    private func save() {
        if let template {
            template.name = name
            template.channel = channel
            template.emailSubject = emailSubject
            template.body = body_
        } else {
            modelContext.insert(
                MessageTemplate(name: name, body: body_, channel: channel, emailSubject: emailSubject)
            )
        }
        dismiss()
    }
}
