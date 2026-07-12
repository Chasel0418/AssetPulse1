import SwiftUI

struct ContactDraft {
    var name: String
    var company: String
    var title: String
    var phone: String
    var email: String
    var lineID: String
    var heat: HeatLevel
    var rawOCRText: String
    var memoTranscript: String
    var voiceMemoFileName: String?
}

/// OCR 快速確認畫面：設計預設「會有錯」，每個欄位都能立即修正。
struct ContactReviewView: View {
    let image: UIImage
    let onSave: (ContactDraft) -> Void

    @State private var name: String
    @State private var company: String
    @State private var title: String
    @State private var phone: String
    @State private var email: String
    @State private var lineID: String
    @State private var heat: HeatLevel = .warm
    @State private var rawOCRText: String

    @State private var memoFileName: String?
    @State private var memoTranscript = ""
    @State private var isTranscribing = false
    @State private var showRawText = false

    @StateObject private var recorder = VoiceMemoRecorder()

    init(image: UIImage, parsed: ParsedCard, onSave: @escaping (ContactDraft) -> Void) {
        self.image = image
        self.onSave = onSave
        _name = State(initialValue: parsed.name)
        _company = State(initialValue: parsed.company)
        _title = State(initialValue: parsed.title)
        _phone = State(initialValue: parsed.phone)
        _email = State(initialValue: parsed.email)
        _lineID = State(initialValue: parsed.lineID)
        _rawOCRText = State(initialValue: parsed.rawText)
    }

    var body: some View {
        Form {
            Section {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .listRowBackground(Color.clear)
            }

            Section("聯絡資料（點擊修正）") {
                LabeledContent("姓名") {
                    TextField("姓名", text: $name).multilineTextAlignment(.trailing)
                }
                LabeledContent("公司") {
                    TextField("公司", text: $company).multilineTextAlignment(.trailing)
                }
                LabeledContent("職稱") {
                    TextField("職稱", text: $title).multilineTextAlignment(.trailing)
                }
                LabeledContent("電話") {
                    TextField("電話", text: $phone)
                        .keyboardType(.phonePad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Email") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("LINE ID") {
                    TextField("LINE ID", text: $lineID)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }
                if !rawOCRText.isEmpty {
                    DisclosureGroup("查看辨識原文", isExpanded: $showRawText) {
                        Text(rawOCRText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("熱度（決定跟進時間）") {
                HStack(spacing: 12) {
                    ForEach(HeatLevel.allCases) { level in
                        Button {
                            heat = level
                        } label: {
                            VStack(spacing: 4) {
                                Text(level.emoji).font(.title)
                                Text("\(level.label)・D+\(level.followUpOffsetDays)")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                heat == level ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(heat == level ? Color.accentColor : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("語音備註（最長 15 秒）") {
                recordButton
                if isTranscribing {
                    HStack {
                        ProgressView()
                        Text("轉文字中…").foregroundStyle(.secondary)
                    }
                }
                if !memoTranscript.isEmpty {
                    TextField("備註內容", text: $memoTranscript, axis: .vertical)
                        .lineLimit(2...5)
                }
                if recorder.permissionDenied {
                    Text("未取得麥克風權限，請到「設定」開啟。")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                onSave(buildDraft())
            } label: {
                Text("儲存名片")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .onAppear {
            recorder.onFinish = { url in
                memoFileName = url.lastPathComponent
                isTranscribing = true
                Task {
                    let text = await SpeechTranscriber.transcribe(url: url)
                    await MainActor.run {
                        if let text, !text.isEmpty {
                            memoTranscript = text
                        }
                        isTranscribing = false
                    }
                }
            }
        }
    }

    private var recordButton: some View {
        HStack {
            Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                .foregroundStyle(recorder.isRecording ? .red : Color.accentColor)
                .symbolEffect(.pulse, isActive: recorder.isRecording)
            Text(recorder.isRecording
                ? "錄音中… \(String(format: "%.0f", recorder.elapsed)) 秒（放開結束）"
                : (memoFileName == nil ? "按住錄音" : "按住重錄"))
            Spacer()
            if memoFileName != nil, !recorder.isRecording {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !recorder.isRecording {
                        Task { await recorder.start() }
                    }
                }
                .onEnded { _ in
                    recorder.stop()
                }
        )
    }

    private func buildDraft() -> ContactDraft {
        ContactDraft(
            name: name.trimmingCharacters(in: .whitespaces),
            company: company.trimmingCharacters(in: .whitespaces),
            title: title.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            lineID: lineID.trimmingCharacters(in: .whitespaces),
            heat: heat,
            rawOCRText: rawOCRText,
            memoTranscript: memoTranscript,
            voiceMemoFileName: memoFileName
        )
    }
}
