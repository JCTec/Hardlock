// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Hardlock",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Hardlock",
            path: "Sources/Hardlock"
        )
    ]
)
