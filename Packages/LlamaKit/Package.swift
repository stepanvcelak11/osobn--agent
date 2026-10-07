// swift-tools-version:6.0
// Obal nad llama.cpp (předsestavený XCFramework z oficiálního vydání, ověřený kontrolním součtem SwiftPM).
import PackageDescription

let package = Package(
    name: "LlamaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "LlamaKit", targets: ["LlamaKit"])],
    dependencies: [.package(path: "../RealmCore")],
    targets: [
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b11440/llama-b11440-xcframework.zip",
            checksum: "788c437bbea4322ebd6cb94e50e5e6e54dd899d6ed63802a192a95bdb5e55b23"
        ),
        .target(
            name: "LlamaKit",
            dependencies: ["llama", .product(name: "RealmCore", package: "RealmCore")],
            path: "Sources/LlamaKit"
        ),
    ],
    swiftLanguageModes: [.v5]
)
