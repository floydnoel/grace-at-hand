// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GraceCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "GraceCore", targets: ["GraceCore"])],
    targets: [
        .target(name: "GraceCore"),
        .testTarget(name: "GraceCoreTests", dependencies: ["GraceCore"])
    ]
)
