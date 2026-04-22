// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "apfel-quick",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0"),
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.5.0"),
        .package(url: "https://github.com/Arthur-Ficial/apfel-server-kit.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "apfel-quick",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "ApfelServerKit", package: "apfel-server-kit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("ServiceManagement"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "./Info.plist",
                ])
            ]
        ),
        .testTarget(
            name: "ApfelQuickTests",
            dependencies: [
                "apfel-quick",
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "ApfelServerKit", package: "apfel-server-kit"),
            ],
            path: "Tests"
        ),
    ]
)
