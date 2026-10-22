// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RouteBuilderKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RouteBuilderKit", targets: ["RouteBuilderKit"])],
    targets: [
        .target(name: "RouteBuilderKit"),
        .testTarget(name: "RouteBuilderKitTests", dependencies: ["RouteBuilderKit"])
    ],
    swiftLanguageModes: [.v5]
)
