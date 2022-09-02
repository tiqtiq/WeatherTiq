// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "WeatherTiq",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8)
    ],
    products: [ .library(name: "WeatherTiq", targets: ["WeatherTiq"]) ],
    targets: [
        .target(name: "WeatherTiq", resources: [.process("Resources")]),
        .testTarget(name: "WeatherTiqTests", dependencies: ["WeatherTiq"])
    ]
)
