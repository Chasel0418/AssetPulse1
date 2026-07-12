import PhotosUI
import SwiftData
import SwiftUI

/// 掃描流程：取得照片 → OCR 辨識 → 確認畫面 → 儲存 → 繼續掃下一張
struct CaptureFlowView: View {
    let event: Event

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var parsed: ParsedCard?
    @State private var isProcessing = false
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var savedCount = 0
    @State private var showContinueDialog = false

    var body: some View {
        NavigationStack {
            Group {
                if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("辨識名片中…")
                            .foregroundStyle(.secondary)
                    }
                } else if let image, let parsed {
                    ContactReviewView(image: image, parsed: parsed) { draft in
                        save(draft)
                    }
                } else {
                    sourcePicker
                }
            }
            .navigationTitle(savedCount > 0 ? "已存 \(savedCount) 張" : "掃描名片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { picked in
                showCamera = false
                if let picked {
                    process(picked)
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let picked = UIImage(data: data) {
                    process(picked)
                }
                photoItem = nil
            }
        }
        .confirmationDialog("已儲存！", isPresented: $showContinueDialog, titleVisibility: .visible) {
            Button("繼續掃下一張") { resetForNext() }
            Button("完成") { dismiss() }
        } message: {
            Text("繼續掃下一張，還是先告一段落？")
        }
    }

    private var sourcePicker: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.crop.rectangle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("拍下名片，10 秒完成一張")
                .font(.headline)
            Text("拍照 → 自動辨識 → 標熱度 → 錄備註")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()

            if CameraPicker.isAvailable {
                Button {
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("從相簿選取", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    private func process(_ picked: UIImage) {
        isProcessing = true
        Task {
            let lines = (try? await OCRService.recognizeText(in: picked)) ?? []
            await MainActor.run {
                image = picked
                parsed = CardFieldParser.parse(lines: lines)
                isProcessing = false
            }
        }
    }

    private func save(_ draft: ContactDraft) {
        let contact = Contact(
            name: draft.name,
            company: draft.company,
            title: draft.title,
            phone: draft.phone,
            email: draft.email,
            lineID: draft.lineID,
            heat: draft.heat,
            rawOCRText: draft.rawOCRText,
            memoTranscript: draft.memoTranscript,
            voiceMemoFileName: draft.voiceMemoFileName,
            cardImageData: image?.jpegData(compressionQuality: 0.6)
        )
        contact.event = event
        modelContext.insert(contact)

        NotificationService.scheduleFollowUp(for: contact)
        scheduleEveningDigest()

        savedCount += 1
        showContinueDialog = true
    }

    private func scheduleEveningDigest() {
        let todayStart = Calendar.current.startOfDay(for: .now)
        let todayContacts = event.contacts.filter { $0.createdAt >= todayStart }
        NotificationService.scheduleEveningDigest(
            totalToday: todayContacts.count,
            hotToday: todayContacts.filter { $0.heat == .hot }.count
        )
    }

    private func resetForNext() {
        image = nil
        parsed = nil
        if CameraPicker.isAvailable {
            showCamera = true
        }
    }
}
