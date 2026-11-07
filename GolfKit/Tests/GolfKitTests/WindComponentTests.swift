import Testing
import Foundation
@testable import GolfKit

struct WindComponentTests {
    @Test func components() {
        let head = WindComponent.relative(windFromDeg: 0, speed: 4, holeBearing: 0)
        #expect(abs(head.head - 4) < 1e-9 && abs(head.cross) < 1e-9)
        let tail = WindComponent.relative(windFromDeg: 180, speed: 4, holeBearing: 0)
        #expect(abs(tail.head + 4) < 1e-9)
        // Playing north, wind from the west blows left → right.
        let cross = WindComponent.relative(windFromDeg: 270, speed: 3, holeBearing: 0)
        #expect(abs(cross.cross - 3) < 1e-9 && abs(cross.head) < 1e-9)
    }

    @Test func text() {
        #expect(WindComponent.describe(head: 4.2, cross: 0) == "逆風 4 m/s")
        #expect(WindComponent.describe(head: -2, cross: -3) == "順風 2 m/s · 右往左側風")
        #expect(WindComponent.describe(head: 0.2, cross: 0.4) == "無風")
        #expect(WindComponent.arrowRotation(windFromDeg: 0, holeBearing: 0) == 180)
    }
}
