// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "apple-translation-cli",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "translate", targets: ["AppleTranslate"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0")
    ],
    targets: [
        .executableTarget(
            name: "AppleTranslate",
            dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser")]
        )
    ]
)
