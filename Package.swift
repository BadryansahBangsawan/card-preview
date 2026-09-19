// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CardPreview",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CardPreview", targets: ["CardPreview"])
    ],
    targets: [
        .executableTarget(name: "CardPreview", path: "Sources")
    ]
)
