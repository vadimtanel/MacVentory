// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Macventory",
    platforms: [.macOS(.v13)],
    products: [.library(name: "MacventoryCore", targets: ["MacventoryCore"]),
               .executable(name: "Macventory", targets: ["Macventory"]),
               .executable(name: "InventoryVerify", targets: ["InventoryVerify"])],
    targets: [
        .target(name: "MacventoryCore"),
        .executableTarget(name: "Macventory", dependencies: ["MacventoryCore"]),
        .executableTarget(name: "InventoryVerify", dependencies: ["MacventoryCore"]),
        .testTarget(name: "MacventoryCoreTests", dependencies: ["MacventoryCore"])
    ]
)
