import Foundation

public enum InventoryRunMode: Sendable {
    case normal, safeQA, uiTesting, demo
    public init(arguments: [String], qaBundle: Bool = false) {
        if arguments.contains("--demo") { self = .demo }
        else if qaBundle { self = .uiTesting }
        else if arguments.contains("--ui-testing") { self = .uiTesting }
        else if arguments.contains("--safe-qa") { self = .safeQA }
        else { self = .normal }
    }
    public var isolated: Bool { self == .demo || self == .uiTesting }
    public var allowsLiveRemoval: Bool { self == .normal }
}
public enum DemoInventory {
    /// Fictional records only. No filesystem enumeration, bundle creation or manager queries.
    public static func items(now: Date = Date(timeIntervalSince1970: 1_792_699_200)) -> [SoftwareItem] {
        let rows: [(String, String, InstallSource, Int64, Int?, Int?, String, SoftwareKind)] = [
            ("Atlas Notes", "3.4.1", .appStore, 185_000_000, 12, 1, "doc.richtext", .app),
            ("Aurora Studio", "2.8.0", .homebrewCask, 1_240_000_000, 54, 3, "paintpalette", .app),
            ("Beacon Browser", "7.2.0", .unmanaged, 420_000_000, nil, 0, "globe", .app),
            ("Canvas Forge", "5.1.2", .setapp, 735_000_000, 8, 2, "pencil.and.outline", .app),
            ("Cedar Player", "1.9.4", .pkg, 96_000_000, 82, 14, "music.note", .app),
            ("Harbor IDE", "2026.2", .toolbox, 2_800_000_000, 21, 1, "curlybraces", .app),
            ("Lighthouse Library", "4.0.3", .unmanaged, 260_000_000, nil, 245, "books.vertical", .app),
            ("Meadow Worlds", "1.6.0", .steam, 4_100_000_000, 44, 16, "gamecontroller", .game),
            ("Nimbus Archive", "2.0.0", .unmanaged, 58_000_000, nil, nil, "archivebox", .app),
            ("Orbit Mail", "6.3.0", .homebrewCask, 310_000_000, 5, 0, "envelope", .app),
            ("quartz-cli", "1.10.0", .homebrewFormula, 24_000_000, 17, nil, "terminal", .package),
            ("river-tools", "0.8.2", .macPorts, 18_000_000, 63, nil, "terminal", .package),
            ("summit-shell", "3.2.1", .nix, 32_000_000, 26, nil, "terminal", .package)
        ]
        return rows.enumerated().map { index, row in
            var item = SoftwareItem(name: row.0, kind: row.7, source: row.2, evidence: Evidence("Synthetic demonstration; not a real installation"))
            item.id = "demo:\(index)"; item.version = row.1; item.sizeBytes = row.3
            item.installedAt = row.4.map { now.addingTimeInterval(-Double($0) * 86400) }
            item.lastOpenedAt = row.5.map { now.addingTimeInterval(-Double($0) * 86400) }
            item.evidence["installedAt"] = Evidence("Synthetic demonstration", availability: item.installedAt == nil ? .notAvailable : .available)
            item.evidence["lastOpenedAt"] = Evidence("Synthetic demonstration", availability: item.lastOpenedAt == nil ? .notAvailable : .available)
            item.attributes = ["Demonstration": "Synthetic", "Demo symbol": row.6]
            item.scannedAt = now
            return item
        }
    }
}
