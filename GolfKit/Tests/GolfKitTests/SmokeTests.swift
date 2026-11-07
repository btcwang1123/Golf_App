import Testing
@testable import GolfKit

@Test func packageLoads() {
    #expect(!GolfKit.version.isEmpty)
}
