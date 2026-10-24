import Foundation

public enum InstallSource: String, Codable, CaseIterable, Sendable, Identifiable {
    case appStore, homebrewCask, homebrewFormula, unmanaged, pkg, macPorts, nix, setapp, steam, toolbox, unknown
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .appStore: "Mac App Store"
        case .homebrewCask: "Homebrew Casks"
        case .homebrewFormula: "Homebrew Formulae"
        case .unmanaged: "Direct / Unmanaged"
        case .pkg: "PKG Installers"
        case .macPorts: "MacPorts"
        case .nix: "Nix"
        case .setapp: "Setapp"
        case .steam: "Steam"
        case .toolbox: "JetBrains Toolbox"
        case .unknown: "Unknown / Ambiguous"
        }
    }
}
public enum SoftwareKind: String, Codable, CaseIterable, Sendable { case app, cli, package, game, other }
public enum Confidence: String, Codable, CaseIterable, Sendable { case verified, inferred, unknown }
public enum Availability: String, Codable, Sendable {
    case available, unknown, notAvailable, calculating, accessDenied, failed, stale, partial
    public var title: String {
        switch self {
        case .available: "Available"
        case .unknown: "Unknown"
        case .notAvailable: "Not Available"
        case .calculating: "Calculating…"
        case .accessDenied: "Access Denied"
        case .failed: "Scan Failed"
        case .stale: "Cached / Stale"
        case .partial: "Partial"
        }
    }
}
public struct Evidence: Codable, Hashable, Sendable {
    public var origin: String
    public var confidence: Confidence
    public var availability: Availability
    public var explanation: String
    public init(_ origin: String, confidence: Confidence = .verified, availability: Availability = .available, explanation: String = "") {
        self.origin = origin; self.confidence = confidence; self.availability = availability; self.explanation = explanation
    }
}
public struct SourceEvidence: Codable, Hashable, Sendable {
    public var source: InstallSource
    public var evidence: Evidence
    public init(_ source: InstallSource, _ evidence: Evidence) { self.source = source; self.evidence = evidence }
}
public struct SoftwareItem: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var version: String?
    public var bundleID: String?
    public var packageID: String?
    public var vendor: String?
    public var kind: SoftwareKind
    public var primarySource: InstallSource
    public var sources: [SourceEvidence]
    public var path: String?
    public var relatedPaths: [String] = []
    public var sizeBytes: Int64?
    public var sizeMetric: String = "Logical bytes; excludes external symlink targets and user data"
    public var installedAt: Date?
    public var updatedAt: Date?
    public var fileCreatedAt: Date?
    public var fileModifiedAt: Date?
    public var lastOpenedAt: Date?
    public var isSystem: Bool = false
    public var evidence: [String: Evidence] = [:]
    public var attributes: [String: String] = [:]
    public var scannedAt: Date = Date()
    public var stale: Bool = false
    public var health: InstallationHealth? = nil
    public init(name: String, kind: SoftwareKind = .app, source: InstallSource = .unmanaged, path: String? = nil, packageID: String? = nil, evidence: Evidence = Evidence("Filesystem")) {
        self.name = name; self.kind = kind; self.primarySource = source; self.path = path.map(FileSystem.canonical)
        self.packageID = packageID; self.sources = [.init(source, evidence)]
        self.id = Self.identity(path: self.path, source: source, packageID: packageID ?? name)
    }
    public static func identity(path: String?, source: InstallSource, packageID: String) -> String {
        path.map { "path:" + FileSystem.canonical($0) } ?? "record:\(source.rawValue):\(packageID)"
    }
    public func state(_ field: String) -> String { evidence[field]?.availability.title ?? Availability.notAvailable.title }
    public var confidence: Confidence { sources.first(where: { $0.source == primarySource })?.evidence.confidence ?? .unknown }
}

public enum SourceState: String, Codable, Sendable {
    case notInstalled, empty, scanning, completed, unsupported, failed, canceled
    public var title: String {
        switch self {
        case .notInstalled: "Not Installed"
        case .empty: "Installed / Empty"
        case .scanning: "Scanning"
        case .completed: "Completed"
        case .unsupported: "Unavailable / Unsupported"
        case .failed: "Scan Failed"
        case .canceled: "Canceled"
        }
    }
}
public struct SourceReport: Codable, Sendable, Identifiable {
    public var id: InstallSource { source }
    public var source: InstallSource
    public var state: SourceState
    public var message: String
    public var count: Int
    public var refreshedAt: Date
    public init(_ source: InstallSource, _ state: SourceState, _ message: String = "", count: Int = 0) {
        self.source = source; self.state = state; self.message = message; self.count = count; self.refreshedAt = Date()
    }
}
public struct ScanResult: Sendable {
    public var items: [SoftwareItem]
    public var report: SourceReport
    public init(_ source: InstallSource, items: [SoftwareItem] = [], state: SourceState? = nil, message: String = "") {
        self.items = items; self.report = SourceReport(source, state ?? (items.isEmpty ? .empty : .completed), message, count: items.count)
    }
}
public protocol SoftwareScanner: Sendable {
    var source: InstallSource { get }
    func scan() async throws -> ScanResult
}

public struct ScanConfiguration: Codable, Sendable, Equatable {
    public var showSystem = false
    public var customAppDirectories: [String] = []
    public var homebrewPrefixes: [String] = ["/opt/homebrew", "/usr/local"]
    public var macPortsExecutable = "/opt/local/bin/port"
    public var nixExecutable = "/nix/var/nix/profiles/default/bin/nix"
    public var additionalProviderRoots: [String] = []
    public var externalVolumes = false
    // Optional storage preserves decoding of configuration files from older builds.
    private var personalFolderDiscoveryEnabled: Bool? = nil
    public var discoverPersonalFolders: Bool {
        get { personalFolderDiscoveryEnabled ?? false }
        set { personalFolderDiscoveryEnabled = newValue }
    }
    public var scanOnLaunch = true
    public var hideAbsent = false
    public var unusedDays = 180
    public var largeBytes: Int64 = 1_073_741_824
    public var recentlyInstalledDays = 30
    public var appearance = "system"
    public var defaultSort = "name"
    public init() {}
}

public enum LibraryView: String, CaseIterable, Sendable {
    case all = "All Software", apps = "Applications", packages = "CLI & Packages"
    case attention = "Attention Required"
    case unused = "Possibly Unused", large = "Large Applications", recent = "Recently Installed", unknown = "Unknown Metadata"
}
public struct InventoryFilter: Sendable {
    public var search = ""
    public var source: InstallSource?
    public var kind: SoftwareKind?
    public var minimumSize: Int64?
    public var installedAfter: Date?
    public var installedBefore: Date?
    public var openedAfter: Date?
    public var openedBefore: Date?
    public var missingOnly = false
    public var healthStatus: InstallationStatus?
    public var confidence: Confidence?
    public var showSystem = false
    public var systemOnly = false
    public var view: LibraryView = .all
    public init() {}
    public func matches(_ item: SoftwareItem, configuration: ScanConfiguration, now: Date = Date()) -> Bool {
        if !showSystem && item.isSystem { return false }
        if systemOnly && !item.isSystem { return false }
        if let source, !(source == .unknown ? item.primarySource == .unknown : item.sources.contains(where: { $0.source == source })) { return false }
        if let healthStatus, healthStatus != item.installationHealth.status { return false }
        if let kind, kind != item.kind { return false }
        if let confidence, confidence != item.confidence { return false }
        if let minimumSize, item.sizeBytes.map({ $0 >= minimumSize }) != true { return false }
        for (value, lower, upper) in [(item.installedAt, installedAfter, installedBefore), (item.lastOpenedAt, openedAfter, openedBefore)] {
            if let lower, value.map({ $0 >= lower }) != true { return false }
            if let upper, value.map({ $0 <= upper }) != true { return false }
        }
        let missing = item.primarySource == .unknown || item.installedAt == nil || item.sizeBytes == nil || item.lastOpenedAt == nil
        if missingOnly && !missing { return false }
        if !search.isEmpty {
            let text = ([item.name, item.version, item.bundleID, item.packageID, item.path].compactMap { $0 } + item.sources.map { $0.source.title }).joined(separator: "\n")
            if text.range(of: search, options: [.caseInsensitive, .diacriticInsensitive]) == nil { return false }
        }
        switch view {
        case .all: return true
        case .attention: return [.attention, .partial].contains(item.installationHealth.status)
        case .apps: return item.kind == .app || item.kind == .game
        case .packages: return item.kind != .app && item.kind != .game
        case .unknown: return missing
        case .large: return (item.kind == .app || item.kind == .game) && item.sizeBytes.map { $0 >= configuration.largeBytes } == true
        case .unused:
            let credible = item.evidence["lastOpenedAt"].map { $0.confidence != .unknown && $0.availability == .available } ?? false
            return !item.isSystem && (item.kind == .app || item.kind == .game) && credible && item.lastOpenedAt.map { $0 < now.addingTimeInterval(-Double(configuration.unusedDays) * 86400) } == true
        case .recent:
            return item.evidence["installedAt"]?.confidence == .verified && item.installedAt.map { $0 <= now && $0 >= now.addingTimeInterval(-Double(configuration.recentlyInstalledDays) * 86400) } == true
        }
    }
}
