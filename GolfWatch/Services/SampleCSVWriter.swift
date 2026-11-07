import Foundation
import GolfKit

/// Thread-safe CSV writer for motion samples: `t,rx,ry,rz,ax,ay,az,label`.
final class SampleCSVWriter: @unchecked Sendable {
    static let header = "t,rx,ry,rz,ax,ay,az,label\n"
    private static let flushEvery = 200

    private let lock = NSLock()
    private let handle: FileHandle
    private var label: String
    private var buffer = ""
    private var pending = 0
    private var total = 0

    init(url: URL, label: String) throws {
        guard FileManager.default.createFile(atPath: url.path, contents: Data(Self.header.utf8)) else {
            throw CocoaError(.fileWriteUnknown)
        }
        handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        self.label = label
    }

    func setLabel(_ new: String) {
        lock.lock(); defer { lock.unlock() }
        label = new
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return total
    }

    func write(_ s: MotionSample) {
        lock.lock(); defer { lock.unlock() }
        buffer += String(
            format: "%.4f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%@\n",
            s.t, s.rotationRate.x, s.rotationRate.y, s.rotationRate.z,
            s.userAccel.x, s.userAccel.y, s.userAccel.z, label)
        pending += 1
        total += 1
        if pending >= Self.flushEvery { flushLocked() }
    }

    func close() {
        lock.lock(); defer { lock.unlock() }
        flushLocked()
        try? handle.close()
    }

    private func flushLocked() {
        if !buffer.isEmpty { try? handle.write(contentsOf: Data(buffer.utf8)) }
        buffer = ""
        pending = 0
    }
}
