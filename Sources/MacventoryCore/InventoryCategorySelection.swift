import Foundation

public enum InventoryCategorySelection {
    public static func key(_ view: LibraryView) -> String {
        switch view {
        case .all: "view:all"; case .apps: "view:apps"; case .packages: "view:packages"
        case .unused: "view:unused"; case .large: "view:large"; case .recent: "view:recent"; case .unknown: "view:unknown"
        }
    }
    public static func normalized(_ proposed: Set<String>, previous: Set<String>) -> Set<String> {
        let known = Set(LibraryView.allCases.map(key) + InstallSource.allCases.map { "source:" + $0.rawValue } + ["leftovers"])
        var values = proposed.intersection(known)
        let added = values.subtracting(previous)
        if added.contains("leftovers") { return ["leftovers"] }
        if !added.isEmpty { values.remove("leftovers") }
        if added.contains("view:all") { return ["view:all"] }
        if !added.isEmpty { values.remove("view:all") }
        return values.isEmpty ? ["view:all"] : values
    }
    /// Sidebar selections are a union. Search and the ordinary filters are applied
    /// separately by the caller, and physical installations still appear only once.
    public static func matches(_ item: SoftwareItem, categories: Set<String>, configuration: ScanConfiguration, now: Date = Date()) -> Bool {
        categories.contains { category in
            if let view = LibraryView.allCases.first(where: { key($0) == category }) {
                var filter = InventoryFilter(); filter.view = view; filter.showSystem = true
                return filter.matches(item, configuration: configuration, now: now)
            }
            guard category.hasPrefix("source:"), let source = InstallSource(rawValue: String(category.dropFirst(7))) else { return false }
            return source == .unknown ? item.primarySource == .unknown : item.sources.contains { $0.source == source }
        }
    }
}
