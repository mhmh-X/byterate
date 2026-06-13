// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ByteRate",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ByteRate",
            path: "Sources/ByteRate"
        )
    ]
)
