import Foundation
import Testing
@testable import MacventoryCore

@Suite("Settings transactions and demo isolation")
struct SettingsDraftTests {
    @Test func editingAndCancelLeaveCommittedSettingsUntouched() throws {
        let original = ScanConfiguration()
        var draft = SettingsDraft(original)
        draft.value.appearance = "dark"; draft.value.recentlyInstalledDays = 28; draft.value.customAppDirectories = ["/Demo/Apps"]
        #expect(original.appearance == "system")
        #expect(original.customAppDirectories.isEmpty)
        draft.cancel()
        #expect(draft.value == original)
        #expect(try !draft.commit().hasChanges)
    }
    @Test func doneValidatesOneAtomicCommitWithOneRescanDecision() throws {
        let original = ScanConfiguration()
        var draft = SettingsDraft(original)
        draft.value.customAppDirectories = ["/Demo/Applications"]; draft.value.homebrewPrefixes = ["/Demo/Brew"]; draft.value.externalVolumes = true
        let change = try draft.commit()
        #expect(change.original == original)
        #expect(change.hasChanges && change.requiresRescan)
        #expect(change.configuration.customAppDirectories == ["/Demo/Applications"])
        #expect(change.configuration.homebrewPrefixes == ["/Demo/Brew"])
    }
    @Test func displayAndThresholdChangesNeverRequireRescan() throws {
        var draft = SettingsDraft()
        draft.value.hideAbsent = true; draft.value.appearance = "dark"
        draft.value.defaultSort = "size"; draft.value.unusedDays = 90; draft.value.recentlyInstalledDays = 28; draft.value.largeBytes = 500_000_000; draft.value.scanOnLaunch = false
        #expect(try draft.commit().hasChanges)
        #expect(try !draft.commit().requiresRescan)
    }
    @Test func systemDiscoveryChangesRequireOneRescanDecision() throws {
        var draft = SettingsDraft()
        draft.value.showSystem = true
        #expect(try draft.commit().requiresRescan)
        draft.value.customAppDirectories = ["/Demo/Applications"]
        draft.value.externalVolumes = true
        #expect(try draft.commit().requiresRescan)
        draft.cancel()
        #expect(try !draft.commit().requiresRescan)
    }
    @Test func allAppearanceChoicesRemainStagedUntilDoneAndRoundTrip() throws {
        for originalAppearance in ["light", "dark", "system"] {
            var original = ScanConfiguration(); original.appearance = originalAppearance
            for choice in ["light", "dark", "system"] {
                var draft = SettingsDraft(original)
                draft.value.appearance = choice; draft.value.unusedDays = 90
                #expect(original.appearance == originalAppearance)
                let commit = try draft.commit()
                #expect(!commit.requiresRescan)
                let reopened = try JSONDecoder().decode(ScanConfiguration.self, from: JSONEncoder().encode(commit.configuration))
                #expect(reopened.appearance == choice && reopened.unusedDays == 90)
                draft.cancel()
                #expect(draft.value == original)
            }
        }
    }
    @Test func invalidDraftCannotProduceCommit() {
        var draft = SettingsDraft(); draft.value.recentlyInstalledDays = 0
        #expect(throws: (any Error).self) { try draft.commit() }
        draft.cancel(); draft.value.homebrewPrefixes = ["https://example.invalid"]
        #expect(throws: (any Error).self) { try draft.commit() }
        draft.cancel(); draft.value.nixExecutable = "/bin/tool\nunsafe"
        #expect(throws: (any Error).self) { try draft.commit() }
        draft.cancel(); draft.value.largeBytes = -1
        #expect(throws: (any Error).self) { try draft.commit() }
    }
    @Test func demoRecordsAreFictionalNonActionableAndDeterministic() {
        let rows = DemoInventory.items()
        #expect(rows.count == 13)
        #expect(rows == DemoInventory.items())
        #expect(Set(rows.map(\.primarySource)).count == 10)
        #expect(rows.allSatisfy { $0.id.hasPrefix("demo:") && $0.path == nil && $0.attributes["Demonstration"] == "Synthetic" })
        for item in rows { #expect(UninstallPlanner.plan(for: item).method == .blocked) }
        #expect(!rows.contains { $0.attributes.values.contains { $0.contains("/Users/") } })
    }
    @Test func everyIsolatedOrQAModeRejectsLiveExecution() {
        for args in [["--demo"], ["--ui-testing"], ["--safe-qa"], ["--demo", "--safe-qa", "--ui-testing"]] {
            #expect(!InventoryRunMode(arguments: args).allowsLiveRemoval)
        }
        #expect(InventoryRunMode(arguments: ["--demo"]).isolated)
        #expect(InventoryRunMode(arguments: ["--ui-testing"]).isolated)
        #expect(!InventoryRunMode(arguments: []).isolated)
    }
}
