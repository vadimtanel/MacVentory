import Foundation

public struct SettingsCommit: Sendable {
    public let original: ScanConfiguration
    public let configuration: ScanConfiguration
    public let requiresRescan: Bool
    public var hasChanges: Bool { original != configuration }
    public var requiresLeftoverRescan: Bool { original.discoverPersonalFolders != configuration.discoverPersonalFolders }
}
public struct SettingsDraft: Sendable {
    public private(set) var original: ScanConfiguration
    public var value: ScanConfiguration
    public init(_ configuration: ScanConfiguration = ScanConfiguration()) { original = configuration; value = configuration }
    public mutating func cancel() { value = original }
    public func commit() throws -> SettingsCommit {
        guard (1...365).contains(value.recentlyInstalledDays), (1...3650).contains(value.unusedDays), value.largeBytes > 0, value.largeBytes <= 1_000_000_000_000_000,
              ["system", "light", "dark"].contains(value.appearance), InventorySortKey(rawValue: value.defaultSort) != nil else {
            throw ScanError.malformed("Check the day thresholds, size, appearance and default sort before saving.")
        }
        let paths = value.customAppDirectories + value.homebrewPrefixes + value.additionalProviderRoots + [value.macPortsExecutable, value.nixExecutable].filter { !$0.isEmpty }
        guard paths.allSatisfy({ ($0.hasPrefix("/") || $0.hasPrefix("~/")) && !$0.contains("://") && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) && $0.utf8.count <= 4096 }) else {
            throw ScanError.malformed("Use local absolute paths or ~/ paths. URLs and control characters are not allowed.")
        }
        let rescan = original.showSystem != value.showSystem || original.customAppDirectories != value.customAppDirectories || original.homebrewPrefixes != value.homebrewPrefixes || original.macPortsExecutable != value.macPortsExecutable || original.nixExecutable != value.nixExecutable || original.additionalProviderRoots != value.additionalProviderRoots || original.externalVolumes != value.externalVolumes
        return SettingsCommit(original: original, configuration: value, requiresRescan: rescan)
    }
}
