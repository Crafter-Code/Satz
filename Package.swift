// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Satz",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Satz", targets: ["Satz"])],
    targets: [
        .target(name: "SatzCore"),
        .executableTarget(name: "Satz", dependencies: ["SatzCore"]),
        .testTarget(name: "SatzCoreTests", dependencies: ["SatzCore"])
    ]
)
