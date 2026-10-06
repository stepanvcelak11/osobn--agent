// swift-tools-version:6.0
// Obal nad whisper.cpp (předsestavený XCFramework z oficiálního vydání, ověřený kontrolním součtem SwiftPM).
// Samostatný balíček, aby se hlavičky ggml z llama.cpp a whisper.cpp nepotkaly v jedné kompilaci.
import PackageDescription

let package = Package(
    name: "WhisperBridge",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "WhisperBridge", targets: ["WhisperBridge"])],
    targets: [
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.2/whisper-v1.9.2-xcframework.zip",
            checksum: "af74fed13ea7f2d5ca2a39d9f58ec177713fafd7cab63aef4e27b79f3ceca80b"
        ),
        .target(name: "WhisperBridge", dependencies: ["whisper"], path: "Sources/WhisperBridge"),
    ],
    swiftLanguageModes: [.v5]
)
