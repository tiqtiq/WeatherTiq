// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "WeatherTiq",
    defaultLocalization: "en",
    products: [ .library(name: "WeatherTiq", targets: ["WeatherTiq"]) ],
    targets: [
        .target(name: "WeatherTiq", resources: [.process("Resources")]),
        .testTarget(name: "WeatherTiqTests", dependencies: ["WeatherTiq"])
    ]
)
