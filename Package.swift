// swift-tools-version: 6.0
import PackageDescription
import Foundation

let helperInfo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Resources/Helpers/MacventoryPrivilegedHelper-Info.plist").path

let package = Package(
    name: "Macventory",
    platforms: [.macOS(.v13)],
    products: [.library(name: "MacventoryCore", targets: ["MacventoryCore"]),
               .executable(name: "Macventory", targets: ["Macventory"]),
               .executable(name: "InventoryVerify", targets: ["InventoryVerify"]),
               .executable(name: "MacventoryPrivilegedHelper", targets: ["MacventoryPrivilegedHelper"])],
    targets: [
        .target(name: "MacventoryCore"),
        .executableTarget(name: "Macventory", dependencies: ["MacventoryCore"]),
        .executableTarget(name: "MacventoryPrivilegedHelper", dependencies: ["MacventoryCore"], linkerSettings: [.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", helperInfo])]),
        .executableTarget(name: "InventoryVerify", dependencies: ["MacventoryCore"]),
        .testTarget(name: "MacventoryCoreTests", dependencies: ["MacventoryCore"])
    ]
)
