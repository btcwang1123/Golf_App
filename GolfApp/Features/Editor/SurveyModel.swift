import Foundation
import GolfKit
import Observation

/// On-course surveying: averages GPS fixes to mark tee / green points and records a walk around the green.
@MainActor @Observable
final class SurveyModel {
    enum Mark: String, CaseIterable, Identifiable {
        case tee, greenFront, greenCenter, greenBack
        var id: String { rawValue }

        var title: String {
            switch self {
            case .tee: "標記發球台"
            case .greenFront: "果嶺前緣"
            case .greenCenter: "果嶺中心"
            case .greenBack: "果嶺後緣"
            }
        }
    }

    enum Phase: Equatable {
        case idle
        case sampling(Mark, secondsLeft: Int)
        case result(Mark, GeoPoint, error: Double, needsRetry: Bool)
        case walking(points: Int)
    }

    static let sampleSeconds = 8
    static let tickSeconds = 0.25
    /// Walk points closer than this to the previous one are dropped.
    static let walkMinStep = 0.5

    private(set) var phase: Phase = .idle
    private(set) var averager = PointAverager()
    private(set) var walkTrack: [GeoPoint] = []
    private(set) var lastMessage: String?
    private var front: GeoPoint?
    private var back: GeoPoint?

    @ObservationIgnored private let editor: EditorModel
    @ObservationIgnored private let location: LocationService
    @ObservationIgnored private var task: Task<Void, Never>?

    init(editor: EditorModel, location: LocationService) {
        self.editor = editor
        self.location = location
    }

    var currentHole: Int { editor.currentHoleNumber }
    var accuracy: Double? { location.accuracy }
    var isBusy: Bool {
        switch phase {
        case .sampling, .walking: true
        default: false
        }
    }

    func activate() {
        location.setPrecise(true)
        location.start()
    }

    func deactivate() {
        task?.cancel()
        location.setPrecise(false)
    }

    func mark(_ m: Mark) {
        task?.cancel()
        averager.reset()
        lastMessage = nil
        phase = .sampling(m, secondsLeft: Self.sampleSeconds)
        task = Task { [weak self] in
            guard let self else { return }
            let start = Date()
            var seen = -1
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                if location.fixSerial != seen, let p = location.current, let acc = location.accuracy {
                    seen = location.fixSerial
                    averager.add(p, accuracy: acc)
                }
                let left = Self.sampleSeconds - Int(elapsed)
                if left <= 0 { break }
                phase = .sampling(m, secondsLeft: left)
                try? await Task.sleep(for: .seconds(Self.tickSeconds))
            }
            guard !Task.isCancelled else { return }
            finish(m)
        }
    }

    private func finish(_ m: Mark) {
        guard let p = averager.result, let err = averager.estimatedError else {
            phase = .idle
            lastMessage = String(localized: "沒有收到足夠精準的定位（需 ≤ 10 m），請到空曠處重試。")
            Haptics.play(.warning)
            return
        }
        let retry = averager.needsRetry
        phase = .result(m, p, error: err, needsRetry: retry)
        Haptics.play(retry ? .warning : .stroke)
    }

    /// Writes the measured point into the current hole.
    func accept() {
        guard case .result(let m, let p, _, _) = phase else { return }
        switch m {
        case .tee: editor.applySurveyTee(p)
        case .greenCenter: editor.applySurveyGreenCenter(p)
        case .greenFront: front = p
        case .greenBack: back = p
        }
        if m == .greenFront || m == .greenBack {
            editor.applySurveyGreenFrontBack(front: front, back: back)
        }
        phase = .idle
    }

    func retry() {
        guard case .result(let m, _, _, _) = phase else { return }
        mark(m)
    }

    func startWalk() {
        task?.cancel()
        walkTrack = []
        phase = .walking(points: 0)
        task = Task { [weak self] in
            guard let self else { return }
            var seen = -1
            while !Task.isCancelled {
                if location.fixSerial != seen, let p = location.current, let acc = location.accuracy {
                    seen = location.fixSerial
                    if acc <= PointAverager.maxSampleAccuracy,
                       walkTrack.last.map({ Geo.distance($0, p) >= Self.walkMinStep }) ?? true {
                        walkTrack.append(p)
                        phase = .walking(points: walkTrack.count)
                    }
                }
                try? await Task.sleep(for: .seconds(Self.tickSeconds))
            }
        }
    }

    func endWalk() {
        task?.cancel()
        if let poly = TrackPolygon.close(walkTrack) {
            editor.applySurveyGreen(poly)
            lastMessage = String(localized: "果嶺邊界已建立（\(poly.count) 點）")
            Haptics.play(.birdie)
        } else {
            lastMessage = String(localized: "軌跡太短，請沿果嶺邊緣完整走一圈。")
            Haptics.play(.warning)
        }
        phase = .idle
    }

    func cancel() {
        task?.cancel()
        phase = .idle
    }

    /// New hole: forget front/back of the previous one.
    func holeChanged() {
        cancel()
        front = nil
        back = nil
    }
}
