// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GolfKit",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "GolfKit", targets: ["GolfKit"]),
        .executable(name: "osm-import", targets: ["osm-import"]),
        .executable(name: "course-audit", targets: ["course-audit"]),
        .executable(name: "osm-buildings", targets: ["osm-buildings"]),
    ],
    targets: [
        .target(name: "GolfKit"),
        .executableTarget(name: "osm-import", dependencies: ["GolfKit"]),
        .executableTarget(name: "course-audit", dependencies: ["GolfKit"]),
        .executableTarget(name: "osm-buildings", dependencies: ["GolfKit"]),
        .testTarget(
            name: "GolfKitTests",
            dependencies: ["GolfKit"],
            resources: [.copy("Fixtures/Data")]
        ),
    ]
)
