import Foundation
import MetricKit
import Observation
import OSLog

/// Collects MetricKit crash / hang / energy payloads into Documents/Diagnostics so they can be exported.
@MainActor @Observable
final class DiagnosticsService: NSObject, MXMetricManagerSubscriber {
    private(set) var files: [URL] = []
    /// Launch → first interactive frame, seconds (this session).
    private(set) var launchToInteractive: Double?

    @ObservationIgnored private let launchedAt = Date()
    nonisolated private static let log = Logger(subsystem: "GolfApp", category: "Diagnostics")
    nonisolated private static let timingsKey = "diagnostics.timings.v1"

    nonisolated static var directory: URL {
        URL.documentsDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
    }

    override init() {
        super.init()
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        MXMetricManager.shared.add(self)
        refresh()
    }

    /// Call once the first screen is interactive.
    func markInteractive() {
        guard launchToInteractive == nil else { return }
        let s = Date().timeIntervalSince(launchedAt)
        launchToInteractive = s
        Self.recordTiming("launch.interactive", seconds: s)
    }

    func refresh() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: nil)) ?? []
        files = urls.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        refresh()
    }

    /// Recent timings, newest first.
    nonisolated static func timings() -> [String: Double] {
        (UserDefaults.standard.dictionary(forKey: timingsKey) as? [String: Double]) ?? [:]
    }

    nonisolated static func recordTiming(_ name: String, seconds: Double) {
        var all = timings()
        all[name] = seconds
        UserDefaults.standard.set(all, forKey: timingsKey)
        log.info("\(name, privacy: .public): \(seconds, format: .fixed(precision: 3))s")
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        for p in payloads { Self.write(p.jsonRepresentation(), prefix: "metrics") }
        Task { @MainActor in self.refresh() }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for p in payloads { Self.write(p.jsonRepresentation(), prefix: "diagnostics") }
        Task { @MainActor in self.refresh() }
    }

    nonisolated private static func write(_ data: Data, prefix: String) {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = directory.appending(path: "\(prefix)-\(stamp).json")
        try? data.write(to: url, options: .atomic)
    }
}
