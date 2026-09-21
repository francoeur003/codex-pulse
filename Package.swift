// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexPulse",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CodexPulse", targets: ["CodexPulse"])
    ],
    targets: [
        .executableTarget(
            name: "CodexPulse",
            resources: [.process("Resources")]
        )
    ]
)
