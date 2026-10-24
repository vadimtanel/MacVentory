import Foundation

public enum InventorySortKey: String, CaseIterable, Sendable { case name, version, source, health, size, installed, opened }

/// One comparator shared by native table headers and inventory queries.
/// Nil placement and identity tie breaks do not reverse with the primary direction.
public struct InventoryComparator: SortComparator, Sendable {
    public var key: InventorySortKey
    public var order: SortOrder
    public init(_ key: InventorySortKey = .name, order: SortOrder = .forward) { self.key = key; self.order = order }
    /// Native tables can remember an inactive column's old direction. A newly
    /// selected header always starts ascending; only the active header toggles.
    public static func headerSelection(_ proposed: Self, after current: Self?) -> Self {
        var value = proposed
        if current?.key != value.key { value.order = .forward }
        return value
    }
    public func compare(_ lhs: SoftwareItem, _ rhs: SoftwareItem) -> ComparisonResult {
        func compareOptional<T>(_ a: T?, _ b: T?, using: (T, T) -> ComparisonResult) -> ComparisonResult? {
            switch (a, b) {
            case (nil, nil): return nil
            case (nil, _): return .orderedDescending
            case (_, nil): return .orderedAscending
            case let (a?, b?): return directed(using(a, b))
            }
        }
        func natural<T: Comparable>(_ a: T, _ b: T) -> ComparisonResult { a == b ? .orderedSame : a < b ? .orderedAscending : .orderedDescending }
        let result: ComparisonResult?
        switch key {
        case .health: result = directed(lhs.installationHealth.status.title.localizedStandardCompare(rhs.installationHealth.status.title))
        case .name: result = directed(lhs.name.localizedStandardCompare(rhs.name))
        case .source: result = directed(lhs.primarySource.title.localizedStandardCompare(rhs.primarySource.title))
        case .version:
            result = compareOptional(lhs.version, rhs.version) { a, b in
                // Numeric runs give 1.10 > 1.9; literal fallback distinguishes nonstandard equal forms.
                let numeric = a.compare(b, options: [.numeric, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                return numeric == .orderedSame ? a.compare(b, options: .literal) : numeric
            }
        case .size: result = compareOptional(lhs.sizeBytes, rhs.sizeBytes, using: natural)
        case .installed: result = compareOptional(lhs.installedAt, rhs.installedAt, using: natural)
        case .opened: result = compareOptional(lhs.lastOpenedAt, rhs.lastOpenedAt, using: natural)
        }
        if let result, result != .orderedSame { return result }
        return natural(lhs.id, rhs.id)
    }
    private func directed(_ result: ComparisonResult) -> ComparisonResult {
        guard order == .reverse else { return result }
        return result == .orderedAscending ? .orderedDescending : result == .orderedDescending ? .orderedAscending : .orderedSame
    }
}
public enum InventorySort {
    public static func sorted(_ items: [SoftwareItem], by key: InventorySortKey = .name, descending: Bool = false) -> [SoftwareItem] {
        items.sorted(using: InventoryComparator(key, order: descending ? .reverse : .forward))
    }
}
