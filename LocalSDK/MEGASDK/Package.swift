// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MEGASDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "MEGASdkCpp",
            targets: ["MEGASdkCpp"]),
        .library(
            name: "MEGASdk",
            targets: ["MEGASdk"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "MEGASdkCpp",
            dependencies: ["libcryptopp",
                           "libmediainfo",
                           "libuv",
                           "libcurl",
                           "libsodium",
                           "libzen"],
            path: "./",
            exclude: [
                "bindings",
                "cmake",
                "contrib",
                "examples",
                "src/android",
                "src/common/client_adapter_with_sync.cpp",
                "src/common/platform/windows",
                "src/file_service/documentation",
                "src/fuse/supported",
                // Apple curl uses the system TLS backend (USE_OPENSSL is off).
                "third_party/evt-tls",
                "third_party/utf8proc/utf8proc_data.c",
                "src/win32",
                "tests",
                "tools"
            ],
            cxxSettings: [
                .headerSearchPath("bindings/ios"),
                .headerSearchPath("include/mega/osx"),
                .headerSearchPath("include/mega/posix"),
                .headerSearchPath("src/common/platform/posix"),
                .headerSearchPath("src/file_service"),
                .headerSearchPath("src/fuse/unsupported"),
                .headerSearchPath("third_party"),
                .define("ENABLE_CHAT"),
                .define("HAVE_LIBUV"),
                .define("NDEBUG", .when(configuration: .release))
            ],
            linkerSettings: [
                // Frameworks
                .linkedFramework("QuickLookThumbnailing"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Foundation"),
                .linkedFramework("ImageIO"),
                .linkedFramework("Security"),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .macCatalyst])),
                .linkedFramework("UniformTypeIdentifiers"),
                .linkedFramework("SystemConfiguration", .when(platforms: [.macOS])),
                // Libraries
                .linkedLibrary("z"),
                .linkedLibrary("sqlite3"),
                .linkedLibrary("icucore")
            ]
        ),
        .target(
            name: "MEGASdk",
            dependencies: ["MEGASdkCpp"],
            path: "bindings/ios",
            cxxSettings: [
                .headerSearchPath("../../include"),
                .define("ENABLE_CHAT"),
                .define("HAVE_LIBUV"),
                .headerSearchPath("Private")
            ]
        ),
        .binaryTarget(
            name: "libcryptopp",
            path: ".artifacts/libcryptopp.xcframework"
        ),
        .binaryTarget(
            name: "libcurl",
            path: ".artifacts/libcurl.xcframework"
        ),
        .binaryTarget(
            name: "libsodium",
            path: ".artifacts/libsodium.xcframework"
        ),
        .binaryTarget(
            name: "libuv",
            path: ".artifacts/libuv.xcframework"
        ),
        .binaryTarget(
            name: "libmediainfo",
            path: ".artifacts/libmediainfo.xcframework"
        ),
        .binaryTarget(
            name: "libzen",
            path: ".artifacts/libzen.xcframework"
        )
    ],
    cxxLanguageStandard: .cxx17
)
