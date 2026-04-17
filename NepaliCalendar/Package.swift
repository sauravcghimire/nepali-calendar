// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NepaliCalendar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NepaliCalendar", targets: ["NepaliCalendar"])
    ],
    targets: [
        .executableTarget(
            name: "NepaliCalendar",
            path: "Sources/NepaliCalendar",
            resources: [
                .copy("Resources/calendar"),
                .copy("Resources/rashifal")
            ]
        )
    ]
)
