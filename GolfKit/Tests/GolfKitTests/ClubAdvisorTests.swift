import Testing
import Foundation
@testable import GolfKit

struct ClubAdvisorTests {
    func stats(_ m: Double, n: Int = 5) -> ClubProfile.Stats {
        ClubProfile.Stats(count: n, median: m, p25: m - 5, p75: m + 5, longest: m + 10)
    }

    var profile: ClubProfile {
        ClubProfile(clubs: [.i7: stats(130), .i8: stats(120), .i6: stats(140), .driver: stats(210), .pw: stats(100, n: 2)])
    }

    @Test func picksClosestReachingClub() throws {
        let s = try #require(ClubAdvisor.suggest(distance: 128, profile: profile, headwind: nil))
        #expect(s.club == .i7)
        // 125 * 0.95 = 118.75 → 8I (120) qualifies and is closest.
        #expect(try #require(ClubAdvisor.suggest(distance: 125, profile: profile, headwind: nil)).club == .i8)
    }

    @Test func windAdjusts() throws {
        #expect(abs(ClubAdvisor.playsLike(distance: 100, headwind: 5) - 105) < 1e-9)
        #expect(abs(ClubAdvisor.playsLike(distance: 100, headwind: -4) - 98) < 1e-9)
        let s = try #require(ClubAdvisor.suggest(distance: 128, profile: profile, headwind: 10))
        #expect(s.club == .i6)
    }

    @Test func ignoresThinDataAndReportsNone() {
        // PW has only 2 samples.
        #expect(ClubAdvisor.suggest(distance: 95, profile: profile, headwind: nil)?.club == .i8)
        #expect(ClubAdvisor.suggest(distance: 100, profile: ClubProfile(clubs: [.pw: stats(100, n: 2)]), headwind: nil) == nil)
        #expect(!ClubAdvisor.hasEnoughData(ClubProfile()))
    }
}
