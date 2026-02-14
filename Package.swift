// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FnKeyboard",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "FnKeyboard",
            path: "Sources"
        ),
    ]
)
