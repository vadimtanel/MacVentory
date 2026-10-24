import Foundation
import Testing
@testable import MacventoryCore

@Suite("Inventory sidebar multiple categories")
struct InventoryCategorySelectionTests {
    @Test func addingCategoriesReplacesAllAndCleanupStaysSeparate() {
        #expect(InventoryCategorySelection.normalized(["view:all", "source:homebrewCask"], previous: ["view:all"]) == ["source:homebrewCask"])
        #expect(InventoryCategorySelection.normalized(["source:homebrewCask", "source:pkg"], previous: ["source:homebrewCask"]) == ["source:homebrewCask", "source:pkg"])
        #expect(InventoryCategorySelection.normalized(["leftovers", "source:pkg"], previous: ["source:pkg"]) == ["leftovers"])
        #expect(InventoryCategorySelection.normalized(["leftovers", "view:apps"], previous: ["leftovers"]) == ["view:apps"])
        #expect(InventoryCategorySelection.normalized([], previous: ["source:pkg"]) == ["view:all"])
    }
    @Test func sourceUnionKeepsOverlappingInstallationsOnceAndAppliesSearch() {
        var overlap = SoftwareItem(name: "Orchard", source: .homebrewCask)
        overlap.sources.append(.init(.pkg, Evidence("Fixture receipt")))
        let package = SoftwareItem(name: "Meadow", source: .pkg)
        let unrelated = SoftwareItem(name: "Harbor", source: .unmanaged)
        let selected: Set<String> = ["source:homebrewCask", "source:pkg"]
        let values = [overlap, package, unrelated].filter { InventoryCategorySelection.matches($0, categories: selected, configuration: .init()) }
        #expect(values.count == 2)
        var filter = InventoryFilter(); filter.search = "Orchard"
        #expect(values.filter { filter.matches($0, configuration: .init()) }.map(\.name) == ["Orchard"])
    }
    @Test func libraryCategoriesCanBeCombinedWithSourcesAndSystemFilterStillApplies() {
        let application = SoftwareItem(name: "Orchard", source: .unmanaged)
        let cli = SoftwareItem(name: "Meadow", kind: .package, source: .homebrewFormula)
        let otherCLI = SoftwareItem(name: "Harbor", kind: .package, source: .nix)
        let categories: Set<String> = ["view:apps", "source:homebrewFormula"]
        #expect([application, cli, otherCLI].filter { InventoryCategorySelection.matches($0, categories: categories, configuration: .init()) }.map(\.name) == ["Orchard", "Meadow"])
        var system = application; system.isSystem = true
        #expect(!InventoryFilter().matches(system, configuration: .init()))
    }
}
