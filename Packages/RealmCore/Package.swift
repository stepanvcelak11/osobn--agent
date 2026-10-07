// swift-tools-version:6.0
// RealmCore = herní jádro Pocket Realm (pravidla, simulace, vypravěč přes lokální model). Bez UI, testuje se i na Linuxu.
import PackageDescription

let package = Package(
    name: "RealmCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RealmCore", targets: ["RealmCore"])],
    dependencies: [
        // Jen pro Linux (testy v CI) – na iOS se používá CryptoKit.
        .package(url: "https://github.com/apple/swift-crypto.git", "4.0.0"..<"5.0.0"),
    ],
    targets: [
        .target(
            name: "RealmCore",
            dependencies: [.product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))],
            path: "Sources/RealmCore"
        ),
        .testTarget(name: "RealmCoreTests", dependencies: ["RealmCore"], path: "Tests/RealmCoreTests"),
    ],
    swiftLanguageModes: [.v5]
)
