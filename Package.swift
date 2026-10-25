// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeviceAudioSR",
    platforms: [
        // Minor versions like 15.6 have no `.vXX` constant; string spelling.
        .macOS("15.6"),
    ],
    targets: [
        // Sources are the same folder the Xcode target compiles:
        // main.swift + Domain/ Application/ Infrastructure/ Presentation/.
        // SwiftPM includes all .swift files under the path recursively.
        .executableTarget(
            // Lower-case product name to match the Homebrew formula's
            // install name: `brew install .../deviceaudiosr` puts exactly
            // this binary on PATH.
            name: "deviceaudiosr",
            path: "DeviceAudioSR"
        ),
    ]
)
