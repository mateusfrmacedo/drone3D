// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Drone3D",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Drone3D", targets: ["Drone3DApp"])
    ],
    targets: [
        .executableTarget(
            name: "Drone3DApp",
            path: "Sources/Drone3DApp"
        )
    ]
)
