// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HiddenBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "HiddenBar", path: "Sources/HiddenBar")
    ]
)
