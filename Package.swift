// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesktopPets",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DesktopPets", targets: ["DesktopPets"])],
    targets: [
        .executableTarget(name: "DesktopPets", path: "Sources/DesktopPets"),
        .testTarget(name: "DesktopPetsTests", dependencies: ["DesktopPets"], path: "Tests/DesktopPetsTests")
    ]
)
