import AVFoundation
import Foundation
import Speech

// MARK: - 語音備註檔案管理

enum VoiceMemoStore {
    static var directory: URL {
        let dir = URL.documentsDirectory.appending(path: "VoiceMemos", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func newFileURL() -> URL {
        directory.appending(path: "\(UUID().uuidString).m4a")
    }

    static func url(for fileName: String) -> URL {
        directory.appending(path: fileName)
    }
}

// MARK: - 錄音（上限 15 秒，按住錄音）

final class VoiceMemoRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let maxDuration: TimeInterval = 15

    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var permissionDenied = false

    /// 錄音完成（手放開或滿 15 秒）時回呼
    var onFinish: ((URL) -> Void)?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentURL: URL?
    private var stopRequested = false

    func start() async {
        guard !isRecording, recorder == nil else { return }
        stopRequested = false

        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            await MainActor.run { self.permissionDenied = true }
            return
        }

        await MainActor.run {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true)

                let url = VoiceMemoStore.newFileURL()
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
                ]
                let recorder = try AVAudioRecorder(url: url, settings: settings)
                recorder.delegate = self
                recorder.record(forDuration: Self.maxDuration)

                self.recorder = recorder
                self.currentURL = url
                self.isRecording = true
                self.elapsed = 0
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self, let recorder = self.recorder else { return }
                    self.elapsed = recorder.currentTime
                }

                // 使用者在權限彈窗期間就放開了手指
                if self.stopRequested {
                    recorder.stop()
                }
            } catch {
                self.recorder = nil
                self.currentURL = nil
            }
        }
    }

    func stop() {
        stopRequested = true
        recorder?.stop()
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            self.isRecording = false
            self.recorder = nil
            let url = self.currentURL
            self.currentURL = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            if flag, let url {
                self.onFinish?(url)
            } else if let url {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

// MARK: - 語音轉文字（zh-TW）

enum SpeechTranscriber {
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    static func transcribe(url: URL) async -> String? {
        guard await requestAuthorization() else { return nil }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW")) ?? SFSpeechRecognizer(),
              recognizer.isAvailable else { return nil }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return await withCheckedContinuation { continuation in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !resumed else { return }
                if let result, result.isFinal {
                    resumed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if error != nil {
                    resumed = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - 播放

final class VoiceMemoPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    private var player: AVAudioPlayer?

    func togglePlay(url: URL) {
        if isPlaying {
            player?.stop()
            isPlaying = false
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}
