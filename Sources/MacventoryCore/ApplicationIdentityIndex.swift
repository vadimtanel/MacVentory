import Foundation

/// Naming evidence only. None of these fields confer file ownership or cleanup rights.
public struct ObservedApplicationIdentity: Codable, Hashable, Sendable {
    public var bundleID: String
    public var name: String
    public var vendor: String?
    public var parentBundleID: String?
    public var source: String
    public var lastObserved: Date
    public init(bundleID: String, name: String, vendor: String? = nil, parentBundleID: String? = nil, source: String, lastObserved: Date = Date()) {
        self.bundleID = bundleID; self.name = name; self.vendor = vendor; self.parentBundleID = parentBundleID; self.source = source; self.lastObserved = lastObserved
    }
}

public struct ApplicationIdentityIndex: Codable, Sendable {
    public var version = 1
    public var entries: [ObservedApplicationIdentity] = []
    public init(entries: [ObservedApplicationIdentity] = []) { self.entries = entries }
    public mutating func observe(_ observations: [ObservedApplicationIdentity], now: Date = Date()) {
        // Two years retains names after removal without retaining installation paths.
        entries = (entries + observations).filter { now.timeIntervalSince($0.lastObserved) < 730 * 86400 && $0.lastObserved <= now.addingTimeInterval(300) && LeftoverDiscoveryService.validBundleID($0.bundleID) && !$0.name.isEmpty && $0.name.count < 256 && $0.source.count < 1024 }
        let newestByID = Dictionary(grouping: entries, by: \.bundleID).mapValues { $0.map(\.lastObserved).max()! }
        entries = entries.filter { $0.lastObserved == newestByID[$0.bundleID] }
        entries = Array(Set(entries)).sorted { $0.lastObserved > $1.lastObserved }.prefix(4000).map { $0 }
    }
    public func resolve(_ identity: ApplicationIdentity) -> ApplicationIdentity {
        guard let id = identity.bundleID else { return identity }
        let now = Date()
        let matches = entries.filter { $0.bundleID == id && now.timeIntervalSince($0.lastObserved) < 730 * 86400 && $0.lastObserved <= now.addingTimeInterval(300) }
        guard let newest = matches.map(\.lastObserved).max() else { return identity }
        let latest = matches.filter { $0.lastObserved == newest }
        guard Set(latest.map(\.name)).count == 1, let record = latest.first else { return identity }
        var result = identity
        result.name = record.name; result.namingSource = record.source
        result.namingConfidence = "Previously observed local metadata"
        result.vendor = record.vendor
        if Set(latest.map(\.parentBundleID)).count == 1, let parent = record.parentBundleID, parent != id {
            let parents = entries.filter { $0.bundleID == parent && now.timeIntervalSince($0.lastObserved) < 730 * 86400 && $0.lastObserved <= now.addingTimeInterval(300) }
            if let date = parents.map(\.lastObserved).max(), Set(parents.filter { $0.lastObserved == date }.map(\.name)).count == 1 {
                result.parentBundleID = parent
                result.parentApplicationName = parents.first { $0.lastObserved == date }?.name
            }
        }
        return result
    }
    public static func observations(items: [SoftwareItem], inspectBundles: Bool = true, now: Date = Date()) -> [ObservedApplicationIdentity] {
        var result: [ObservedApplicationIdentity] = []
        for item in items where item.kind == .app && !item.isSystem {
            guard let id = item.bundleID, LeftoverDiscoveryService.validBundleID(id) else { continue }
            // A provider name is retained only if it already has explicit name evidence.
            guard item.evidence["name"] != nil || item.attributes["Identity fixture"] == "true" else { continue }
            result.append(.init(bundleID: id, name: item.name, vendor: item.vendor, source: item.evidence["name"]?.origin ?? "Synthetic bundle metadata", lastObserved: inspectBundles ? now : item.scannedAt))
            guard inspectBundles, let path = item.path else { continue }
            // Only direct embedded extension/helper bundles establish parentage.
            for relative in ["Contents/PlugIns", "Contents/Library/LoginItems", "Contents/Frameworks"] {
                let root = URL(fileURLWithPath: path).appendingPathComponent(relative)
                for url in (try? FileSystem.children(root.path))?.prefix(100) ?? [] {
                    guard ["app", "appex"].contains(url.pathExtension), url.path == FileSystem.canonical(url.path), FileSystem.contained(url.path, in: path),
                          let child = try? NativeScanner.item(at: url.path), let childID = child.bundleID, LeftoverDiscoveryService.validBundleID(childID) else { continue }
                    result.append(.init(bundleID: childID, name: child.name, parentBundleID: id, source: "Embedded bundle Info.plist and enclosing application", lastObserved: now))
                }
            }
        }
        return result
    }
}

public actor ApplicationIdentityStore {
    private let url: URL
    public init(directory: URL) { url = directory.appendingPathComponent("application-identities.json") }
    public func load() throws -> ApplicationIdentityIndex {
        guard FileManager.default.fileExists(atPath: url.path) else { return .init() }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max < 4_194_304 else { throw ScanError.limit("Application identity index exceeds 4 MiB") }
        let index = try JSONDecoder().decode(ApplicationIdentityIndex.self, from: Data(contentsOf: url))
        guard index.version == 1 else { throw ScanError.malformed("Unsupported application identity index version") }
        return index
    }
    public func save(_ index: ApplicationIdentityIndex) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(index)
        guard data.count < 4_194_304 else { throw ScanError.limit("Application identity index exceeds 4 MiB") }
        try data.write(to: url, options: .atomic)
    }
}
