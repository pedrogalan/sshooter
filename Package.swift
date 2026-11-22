// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "sshooter",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "sshooter", targets: ["sshooter"])
    ],
    targets: [
        .executableTarget(
            name: "sshooter",
            path: "Sources/Sshotter",
            resources: [
                .copy("Resources/BlurToolIcon.png"),
                .copy("Resources/DueDate.ttf"),
                .copy("Resources/DueDate-LICENSE.txt")
            ],
            swiftSettings: [
                // Development-only affordances, such as the blank-canvas menu
                // item, are compiled only into debug builds. Release builds
                // produced by Scripts/build-app.sh never define this flag.
                .define("SSHOOTER_DEBUG_MENU", .when(configuration: .debug))
            ]
        )
    ]
)
