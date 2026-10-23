import Foundation

public actor SnapshotStore {
    public let directory: URL
    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Macventory", isDirectory: true)
    }
    public func load() throws -> InventorySnapshot? {
        let url = directory.appendingPathComponent("inventory.json")
        guard FileSystem.exists(url.path) else { return nil }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max < 32 * 1024 * 1024 else { throw ScanError.limit("Inventory cache exceeds 32 MiB") }
        var snapshot = try JSONDecoder().decode(InventorySnapshot.self, from: Data(contentsOf: url))
        guard snapshot.schemaVersion == 1 else { throw ScanError.malformed("Unsupported inventory cache version; refresh to rebuild") }
        for index in snapshot.items.indices { snapshot.items[index].stale = true }
        for key in Array(snapshot.observations.keys) {
            snapshot.observations[key] = snapshot.observations[key]?.map { var item = $0; item.stale = true; return item }
        }
        return snapshot
    }
    public func save(_ snapshot: InventorySnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        guard data.count < 32 * 1024 * 1024 else { throw ScanError.limit("Inventory cache exceeds 32 MiB") }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("inventory.json"), options: .atomic)
    }
    public func clear() throws {
        let url = directory.appendingPathComponent("inventory.json")
        if FileSystem.exists(url.path) { try FileManager.default.removeItem(at: url) }
    }
}

public enum Diagnostics {
    /// Deliberately excludes names, identifiers, installation paths, command output, and free-form errors.
    public static func sanitized(_ snapshot: InventorySnapshot?) throws -> Data {
        struct Report: Encodable { var source: String; var status: String; var count: Int }
        struct Document: Encodable { var schema = 1; var app = "Macventory"; var itemCount: Int; var reports: [Report] }
        let document = Document(itemCount: snapshot?.items.count ?? 0, reports: snapshot?.reports.map { Report(source: $0.source.rawValue, status: $0.state.rawValue, count: $0.count) } ?? [])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }
}
