// swift-tools-version: 5.5
import PackageDescription

let package = Package(
    name: "WeatherTiq",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8)
    ],
    products: [ .library(name: "WeatherTiq", targets: ["WeatherTiq"]) ],
    dependencies: [ .package(name: "swift-docc-plugin", url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"), 
        .package(url: "https://github.com/tiqtiq/LocationTiq", from: "0.0.1"),
    ],
    targets: [
        .target(name: "WeatherTiq", dependencies: ["LocationTiq"], resources: [.process("Resources")]),
        .testTarget(name: "WeatherTiqTests", dependencies: ["WeatherTiq"])
    ]
)
