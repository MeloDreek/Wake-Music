// swift-tools-version: 5.9
import PackageDescription

// TagLib uses basename includes across its format directories. Keep those
// headers private to the C++ target and the Objective-C++ implementation.
let tagLibDirectories = [
    "", "ape", "asf", "dsdiff", "dsf", "flac", "it", "matroska", "matroska/ebml", "mod", "mp4", "mpc",
    "mpeg", "mpeg/id3v1", "mpeg/id3v2", "mpeg/id3v2/frames", "ogg", "ogg/flac",
    "ogg/opus", "ogg/speex", "ogg/vorbis", "riff", "riff/aiff", "riff/wav",
    "s3m", "shorten", "thirdSDK", "toolkit", "trueaudio", "wavpack", "xm"
]

let package = Package(
    name: "WaketagLibKit",
    platforms: [
        .iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .macCatalyst(.v15)
    ],
    products: [
        .library(name: "WaketagLibKit", targets: ["WaketagLibKit"])
    ],
    targets: [
        .target(
            name: "WaketagLibCore",
            path: ".",
            exclude: [
                "Classes/TagLibHeader",
                "Classes/TagLib/ape/ape-tag-format.txt",
                "Classes/TagLib/mpeg/id3v2/id3v2.2.0.txt",
                "Classes/TagLib/mpeg/id3v2/id3v2.3.0.txt",
                "Classes/TagLib/mpeg/id3v2/id3v2.4.0-frames.txt",
                "Classes/TagLib/mpeg/id3v2/id3v2.4.0-structure.txt",
                "Classes/TagLib/toolkit/tlist.tcc",
                "Classes/TagLib/toolkit/tmap.tcc"
            ],
            sources: ["Classes/TagLib"],
            publicHeadersPath: "Support/TagLibCore/include",
            cxxSettings: tagLibDirectories.map {
                .headerSearchPath("Classes/TagLib/" + $0)
            } + [
                .define("TAGLIB_STATIC", to: "1"),
                .define("HAVE_ZLIB", to: "1")
            ],
            linkerSettings: [.linkedLibrary("c++"), .linkedLibrary("z")]
        ),
        .target(
            name: "WaketagLibKit",
            dependencies: ["WaketagLibCore"],
            path: "Classes/TagLibHeader",
            publicHeadersPath: ".",
            cxxSettings: tagLibDirectories.map {
                .headerSearchPath("../TagLib/" + $0)
            } + [.define("TAGLIB_STATIC", to: "1")],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("ImageIO"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .watchOS, .macCatalyst]))
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
