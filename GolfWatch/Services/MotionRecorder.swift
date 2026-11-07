import Foundation
import GolfKit

/// Records labelled motion samples to CSV and shows live detector hits (calibration mode).
@MainActor @Observable
final class MotionRecorder {
    enum Label: String, CaseIterable, Sendable {
        case real, practice, walk
    }

    struct Config: Sendable {
        var detectedIndicatorSeconds: Double = 2
        var countRefreshSeconds: Double = 1
    }

    private(set) var isRecording = false
    private(set) var swingDetected = false
    private(set) var sampleCount = 0
    private(set) var lastFileURL: URL?
    private(set) var errorMessage: String?
    var label: Label = .real {
        didSet { writer?.setLabel(label.rawValue) }
    }
    /// Called with the finished CSV file (to transfer to the phone).
    @ObservationIgnored var onFinished: (@MainActor (URL) -> Void)?

    @ObservationIgnored private let motion = MotionService()
    @ObservationIgnored private let settings: WatchSettingsService
    @ObservationIgnored private let pipeline = SwingDetectionPipeline()
    @ObservationIgnored private let config: Config
    @ObservationIgnored private var writer: SampleCSVWriter?
    @ObservationIgnored private var indicatorTask: Task<Void, Never>?
    @ObservationIgnored private var countTask: Task<Void, Never>?

    init(settings: WatchSettingsService, config: Config = Config()) {
        self.settings = settings
        self.config = config
    }

    func start() {
        guard !isRecording else { return }
        errorMessage = nil
        guard motion.isAvailable else {
            errorMessage = "此裝置沒有動作感測器"
            return
        }
        let url = Self.makeURL()
        let writer: SampleCSVWriter
        do {
            writer = try SampleCSVWriter(url: url, label: label.rawValue)
        } catch {
            errorMessage = "無法建立檔案"
            return
        }
        self.writer = writer
        lastFileURL = url
        sampleCount = 0
        pipeline.configure(sensitivity: settings.settings.swingSensitivity)
        pipeline.reset()
        let pipeline = pipeline
        motion.start(wrist: settings.settings.wrist) { [weak self] sample in
            writer.write(sample)
            if pipeline.ingest(sample) != nil {
                Task { @MainActor in self?.flashDetected() }
            }
        }
        isRecording = true
        countTask = Task { [weak self, interval = config.countRefreshSeconds] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                self?.sampleCount = writer.count
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        motion.stop()
        countTask?.cancel()
        indicatorTask?.cancel()
        swingDetected = false
        isRecording = false
        writer?.close()
        sampleCount = writer?.count ?? sampleCount
        writer = nil
        if let url = lastFileURL { onFinished?(url) }
    }

    private func flashDetected() {
        swingDetected = true
        indicatorTask?.cancel()
        indicatorTask = Task { [weak self, seconds = config.detectedIndicatorSeconds] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.swingDetected = false
        }
    }

    private static func makeURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return docs.appendingPathComponent("swing_\(f.string(from: Date())).csv")
    }
}
