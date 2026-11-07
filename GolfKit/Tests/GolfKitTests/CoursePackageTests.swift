import Testing
import Foundation
@testable import GolfKit

struct CoursePackageTests {
    @Test func roundTrip() throws {
        let pkg = CoursePackage(course: V2.course(holes: 2), exportedAt: V2.t0)
        let back = try CoursePackage.decode(pkg.encode())
        #expect(back.course.holes.count == 2)
        #expect(back.version == CoursePackage.currentVersion)
        #expect(abs(back.exportedAt.timeIntervalSince(V2.t0)) < 1)
    }

    @Test func rejectsNewerVersionAndGarbage() {
        let newer = #"{"version":99,"course":{},"exportedAt":"2024-01-01T00:00:00Z"}"#
        #expect(throws: CoursePackage.PackageError.unsupportedVersion(99)) { try CoursePackage.decode(Data(newer.utf8)) }
        #expect(throws: CoursePackage.PackageError.corrupted) { try CoursePackage.decode(Data("nope".utf8)) }
        let broken = #"{"version":1,"course":{"id":1}}"#
        #expect(throws: CoursePackage.PackageError.corrupted) { try CoursePackage.decode(Data(broken.utf8)) }
    }

    @Test func fileName() {
        #expect(CoursePackage.fileName(for: Course(id: "x", name: "A/B 球場", center: V2.origin)) == "A_B 球場.golfcourse")
    }
}
