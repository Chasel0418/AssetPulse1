import SwiftData
import SwiftUI

struct ContactDetailView: View {
    @Bindable var contact: Contact
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \MessageTemplate.createdAt) private var templates: [MessageTemplate]
    @StateObject private var player = VoiceMemoPlayer()
    @State private var copiedTemplateName: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            if let data = contact.cardImageData, let uiImage = UIImage(data: data) {
                Section {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .listRowBackground(Color.clear)
                }
            }

            Section("聯絡資料") {
                LabeledContent("姓名") {
                    TextField("姓名", text: $contact.name).multilineTextAlignment(.trailing)
                }
                LabeledContent("公司") {
                    TextField("公司", text: $contact.company).multilineTextAlignment(.trailing)
                }
                LabeledContent("職稱") {
                    TextField("職稱", text: $contact.title).multilineTextAlignment(.trailing)
                }
                LabeledContent("電話") {
                    TextField("電話", text: $contact.phone)
                        .keyboardType(.phonePad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Email") {
                    TextField("Email", text: $contact.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("LINE ID") {
                    TextField("LINE ID", text: $contact.lineID)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("熱度與跟進") {
                Picker("熱度", selection: $contact.heat) {
                    ForEach(HeatLevel.allCases) { level in
                        Text("\(level.emoji) \(level.label)").tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: contact.heat) { _, _ in
                    contact.rescheduleFollowUp()
                    NotificationService.scheduleFollowUp(for: contact)
                }

                DatePicker("跟進日", selection: $contact.followUpDate)
                    .onChange(of: contact.followUpDate) { _, _ in
                        NotificationService.scheduleFollowUp(for: contact)
                    }
            }

            Section("狀態") {
                statusPipeline
            }

            if contact.voiceMemoFileName != nil || !contact.memoTranscript.isEmpty {
                Section("語音備註") {
                    if let fileName = contact.voiceMemoFileName {
                        Button {
                            player.togglePlay(url: VoiceMemoStore.url(for: fileName))
                        } label: {
                            Label(
                                player.isPlaying ? "停止播放" : "播放錄音",
                                systemImage: player.isPlaying ? "stop.circle.fill" : "play.circle.fill"
                            )
                        }
                    }
                    if !contact.memoTranscript.isEmpty {
                        TextField("備註", text: $contact.memoTranscript, axis: .vertical)
                            .lineLimit(2...6)
                    }
                }
            }

            Section("一鍵跟進") {
                if templates.isEmpty {
                    Text("先到「範本」頁建立訊息範本。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(templates) { template in
                        templateActionRow(template)
                    }
                }
            }

            Section {
                Button("刪除這張名片", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("確定要刪除嗎？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                NotificationService.cancelFollowUp(for: contact)
                if let fileName = contact.voiceMemoFileName {
                    try? FileManager.default.removeItem(at: VoiceMemoStore.url(for: fileName))
                }
                modelContext.delete(contact)
                dismiss()
            }
        }
    }

    // MARK: - 狀態管線

    private var statusPipeline: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FollowUpStatus.allCases) { status in
                    Button {
                        updateStatus(to: status)
                    } label: {
                        Label(status.label, systemImage: status.systemImage)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                contact.status == status ? Color.accentColor : Color(.secondarySystemBackground),
                                in: Capsule()
                            )
                            .foregroundStyle(contact.status == status ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func updateStatus(to status: FollowUpStatus) {
        contact.status = status
        if status.isActive {
            NotificationService.scheduleFollowUp(for: contact)
        } else {
            NotificationService.cancelFollowUp(for: contact)
        }
    }

    // MARK: - 一鍵動作

    private func templateActionRow(_ template: MessageTemplate) -> some View {
        Button {
            performAction(with: template)
        } label: {
            HStack {
                Image(systemName: template.channel.systemImage)
                    .foregroundStyle(template.channel == .line ? .green : .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name).foregroundStyle(.primary)
                    Text(copiedTemplateName == template.name
                        ? "已複製，正在開啟 \(template.channel.label)…"
                        : "複製訊息並開啟 \(template.channel.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func performAction(with template: MessageTemplate) {
        let message = TemplateEngine.render(template.body, contact: contact, event: contact.event)
        UIPasteboard.general.string = message
        copiedTemplateName = template.name

        switch template.channel {
        case .line:
            openLINE()
        case .email:
            openMail(subject: TemplateEngine.render(template.emailSubject, contact: contact, event: contact.event),
                     body: message)
        }

        // 開啟外部 App 即視為已聯繫
        if contact.status == .pending {
            updateStatus(to: .contacted)
        }
    }

    private func openLINE() {
        let url: URL?
        if !contact.lineID.isEmpty {
            url = URL(string: "https://line.me/R/ti/p/~\(contact.lineID)")
        } else {
            url = URL(string: "line://")
        }
        if let url {
            UIApplication.shared.open(url)
        }
    }

    private func openMail(subject: String, body: String) {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = contact.email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
}
