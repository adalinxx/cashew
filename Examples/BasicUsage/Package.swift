// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BasicUsage",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "BasicUsage",
            dependencies: [
                .product(name: "cashew", package: "cashew"),
            ]
        ),
    ]
)
