// swift-tools-version:6.0
// AgentCore = platformově nezávislé jádro aplikace (data, agent, čas, zálohy).
// Na iOS používá CryptoKit + CommonCrypto, na Linuxu (jen testy v CI) swift-crypto + OpenSSL.
import PackageDescription

let package = Package(
    name: "AgentCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AgentCore", targets: ["AgentCore"]),
    ],
    dependencies: [
        // Pouze pro Linux (testy jádra v CI). Do iOS aplikace se nelinkuje – tam je CryptoKit.
        .package(url: "https://github.com/apple/swift-crypto.git", "4.0.0"..<"5.0.0"),
    ],
    targets: [
        .target(
            name: "CSQLCipher",
            path: "Sources/CSQLCipher",
            exclude: ["LICENSE.md"],
            cSettings: [
                .define("SQLITE_HAS_CODEC"),
                .define("SQLITE_TEMP_STORE", to: "3"),          // dočasná data jen v RAM
                .define("SQLITE_EXTRA_INIT", to: "sqlcipher_extra_init"),
                .define("SQLITE_EXTRA_SHUTDOWN", to: "sqlcipher_extra_shutdown"),
                .define("SQLITE_THREADSAFE", to: "1"),
                .define("SQLITE_OMIT_LOAD_EXTENSION"),           // žádné načítání cizích rozšíření
                .define("SQLITE_SECURE_DELETE"),                 // přepis smazaných dat
                .define("SQLITE_DQS", to: "0"),
                .define("SQLITE_DEFAULT_MEMSTATUS", to: "0"),
                .define("SQLITE_ENABLE_FTS5"),
                .define("SQLCIPHER_CRYPTO_CC", .when(platforms: [.iOS, .macOS])),
                .define("SQLCIPHER_CRYPTO_OPENSSL", .when(platforms: [.linux])),
                .define("HAVE_USLEEP", to: "1"),
                .unsafeFlags(["-w"]),
            ],
            linkerSettings: [
                .linkedFramework("Security", .when(platforms: [.iOS, .macOS])),
                .linkedLibrary("crypto", .when(platforms: [.linux])),
            ]
        ),
        .target(
            name: "CArgon2",
            path: "Sources/CArgon2",
            exclude: ["LICENSE"],
            cSettings: [
                .define("ARGON2_NO_THREADS"),
                .unsafeFlags(["-w"]),
            ]
        ),
        .target(
            name: "AgentCore",
            dependencies: [
                "CSQLCipher",
                "CArgon2",
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
            ],
            path: "Sources/AgentCore"
        ),
        .testTarget(
            name: "AgentCoreTests",
            dependencies: ["AgentCore"],
            path: "Tests/AgentCoreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
