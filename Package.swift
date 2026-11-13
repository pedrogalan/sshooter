// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "sshooter",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "sshooter", targets: ["sshooter"])
    ],
    targets: [
        .executableTarget(name: "sshooter", path: "Sources/Sshotter")
    ]
)
