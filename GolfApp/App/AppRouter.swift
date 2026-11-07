import Foundation
import GolfKit
import Observation

/// App-level navigation state: selected tab, showcase / onboarding presentation and incoming files.
@MainActor @Observable
final class AppRouter {
    enum Tab: Hashable {
        case home, courses, history, insights, settings
    }

    enum PendingImport: Identifiable {
        case course(CoursePackage)
        case round(RoundExport)
        case failure(String)

        var id: String {
            switch self {
            case .course(let p): "course-\(p.course.id)"
            case .round(let r): "round-\(r.roundId)"
            case .failure(let m): "error-\(m)"
            }
        }
    }

    var tab: Tab = .home
    var showShowcase = false
    var showOnboarding = false
    var pendingImport: PendingImport?
    /// Set to present the round screen from anywhere (e.g. after the showcase).
    var showRound = false

    /// Handles `.golfcourse` / `.golfround` files opened from other apps.
    func open(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            pendingImport = .failure(String(localized: "無法讀取檔案。"))
            return
        }
        switch url.pathExtension.lowercased() {
        case CoursePackage.fileExtension:
            do { pendingImport = .course(try CoursePackage.decode(data)) } catch {
                pendingImport = .failure(error.localizedDescription)
            }
        case RoundExport.fileExtension:
            do { pendingImport = .round(try RoundExport.decode(data)) } catch {
                pendingImport = .failure(error.localizedDescription)
            }
        default:
            pendingImport = .failure(String(localized: "不支援的檔案類型。"))
        }
    }
}
