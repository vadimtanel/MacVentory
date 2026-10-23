import Foundation
import Testing
@testable import MacventoryCore

@Suite("Table header sorting")
struct HeaderSortTests {
    private func item(_ id: String, version: String? = nil, size: Int64? = nil, date: Date? = nil) -> SoftwareItem {
        var value = SoftwareItem(name: "Example", kind: .app, source: .unmanaged)
        value.id = id; value.version = version; value.sizeBytes = size; value.installedAt = date; value.lastOpenedAt = date
        return value
    }
    @Test func newlySelectedHeaderAlwaysStartsAscending() {
        let active = InventoryComparator(.name, order: .reverse)
        #expect(InventoryComparator.headerSelection(InventoryComparator(.size, order: .reverse), after: active).order == .forward)
        #expect(InventoryComparator.headerSelection(InventoryComparator(.name, order: .forward), after: active).order == .forward)
        #expect(InventoryComparator.headerSelection(InventoryComparator(.name, order: .reverse), after: InventoryComparator(.name)).order == .reverse)
    }
    @Test func allHeadersToggleWithoutReversingMissingValues() {
        let values = [item("unknown"), item("high", version: "1.10", size: 2_000_000_000, date: Date(timeIntervalSince1970: 200)), item("low", version: "1.9", size: 900_000_000, date: Date(timeIntervalSince1970: 100))]
        for key in [InventorySortKey.version, .size, .installed, .opened] {
            #expect(InventorySort.sorted(values, by: key).map(\.id) == ["low", "high", "unknown"])
            #expect(InventorySort.sorted(values, by: key, descending: true).map(\.id) == ["high", "low", "unknown"])
            var header = InventoryComparator(key)
            #expect(header.order == .forward)
            header.order = .reverse
            #expect(values.sorted(using: header).map(\.id) == ["high", "low", "unknown"])
            header.order = .forward
            #expect(values.sorted(using: header).map(\.id) == ["low", "high", "unknown"])
        }
    }
    @Test func stableIdentityTiesAcrossAllColumnsAndDirections() {
        let a = item("a", version: "dev", size: 10), b = item("b", version: "dev", size: 10)
        for key in InventorySortKey.allCases {
            for reverse in [false, true] { #expect(InventorySort.sorted([b,a], by: key, descending: reverse).map(\.id) == ["a", "b"]) }
        }
    }
    @Test func localizedNameSourceAndNonstandardVersionsAreDeterministic() {
        var a = item("a", version: "nightly 9"), b = item("b", version: "nightly 10")
        #expect(InventorySort.sorted([b,a], by: .version).map(\.id) == ["a", "b"])
        a.name = "App 2"; b.name = "App 10"
        #expect(InventorySort.sorted([b,a], by: .name).map(\.id) == ["a", "b"])
        a.primarySource = .homebrewCask; b.primarySource = .unmanaged
        let expected = [a,b].sorted { $0.primarySource.title.localizedStandardCompare($1.primarySource.title) == .orderedAscending }.map(\.id)
        #expect(InventorySort.sorted([b,a], by: .source).map(\.id) == expected)
    }
    @Test func filteringAndSortingPreserveInstallationSelectionIdentity() {
        var a = item("selected", version: "2.0", size: 200), b = item("other", version: "1.0", size: 100), c = item("excluded", size: 50)
        a.name = "Example selected"; b.name = "Example other"; c.name = "Different"
        var filter = InventoryFilter(); filter.search = "Example"; filter.minimumSize = 100
        let matches = [a,b,c].filter { filter.matches($0, configuration: ScanConfiguration()) }
        for key in InventorySortKey.allCases {
            for reverse in [false,true] {
                let sorted = InventorySort.sorted(matches, by: key, descending: reverse)
                #expect(sorted.count == 2)
                #expect(sorted.first { $0.id == a.id }?.id == "selected")
            }
        }
    }
}
