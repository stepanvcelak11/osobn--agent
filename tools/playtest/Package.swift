// swift-tools-version:6.0
// Zkušební hraní se skutečným modelem (macOS, CI): ověří celý řetězec interpret → hod → vypravěč.
import PackageDescription

let package = Package(
    name: "playtest",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/RealmCore"),
        .package(path: "../../Packages/LlamaKit"),
    ],
    targets: [
        .executableTarget(
            name: "playtest",
            dependencies: [.product(name: "RealmCore", package: "RealmCore"), .product(name: "LlamaKit", package: "LlamaKit")],
            path: "Sources/playtest"
        ),
    ],
    swiftLanguageModes: [.v5]
)
