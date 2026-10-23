import Foundation
import Testing
@testable import MacventoryCore

private actor TrashRecorder: UninstallExecuting {
    private(set) var calls = 0
    func execute(_ plan: UninstallPlan) async throws -> UninstallOutcome {
        calls += 1
        return .simulated // Does not call NSWorkspace, FileManager Trash or any subprocess.
    }
}
private struct OwnershipChanged: StandaloneRemovalChecking {
    func check(_ item: SoftwareItem) async throws -> StandaloneEligibility {
        throw ScanError.process("Synthetic manager ownership appeared after preview")
    }
}
@Suite("Standalone Trash eligibility — no real removal")
struct StandaloneRemovalTests {
    private func fixture(_ box: Sandbox) throws -> SoftwareItem {
        let path = try box.app()
        let infoURL = URL(fileURLWithPath: path + "/Contents/Info.plist")
        var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil) as! [String: Any]
        info["CFBundleExecutable"] = "Example"
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)
        try box.write("Example.app/Contents/MacOS/Example", "Synthetic fixture; never executed")
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path + "/Contents/MacOS/Example")
        return try NativeScanner.item(at: path)
    }
    @Test func inferredOriginRemainsInferredAfterEligibilityAndSimulation() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try fixture(box)
        // Self-contained share extensions stay inside the bundle, unlike system services.
        try box.write("Example.app/Contents/PlugIns/Share.appex/Contents/Info.plist", "Synthetic share extension")
        #expect(item.confidence == .inferred)
        #expect(!UninstallPlanner.plan(for: item).canExecute) // No unchecked fallback.
        let checker = SimulatedStandaloneChecker(roots: [box.root.path])
        let eligibility = try await checker.check(item)
        let plan = UninstallPlanner.plan(for: item, standaloneEligibility: eligibility)
        #expect(plan.canExecute && plan.method == .trashBundle)
        #expect(plan.item.confidence == .inferred)
        #expect(plan.actionTitle == "Move to Trash")
        #expect(plan.acknowledgment.contains("move it to Trash"))
        #expect(plan.executable == nil && plan.arguments.isEmpty)
        let recorder = TrashRecorder()
        let session = UninstallSession(executor: recorder, validator: FreshUninstallValidator(standaloneChecker: checker))
        let before = try StandaloneRemovalChecker.inspect(item, roots: eligibility.roots)
        await session.prepare(plan)
        #expect(try await session.confirm(id: plan.id, acknowledged: true) == .simulated)
        #expect(await recorder.calls == 1)
        #expect(try StandaloneRemovalChecker.inspect(item, roots: eligibility.roots) == before)
    }
    @Test func arbitraryLocationCannotBeAuthorizedByAnAttribute() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        var item = try fixture(box)
        item.attributes["Bundle-only removal"] = "Verified eligible"
        #expect(!UninstallPlanner.plan(for: item).canExecute)
        await #expect(throws: (any Error).self) { try await StandaloneRemovalChecker().check(item) }
    }
    @Test(arguments: ["Contents/_MASReceipt/receipt", "Contents/Library/LaunchDaemons/service.plist", "Contents/Library/LaunchAgents/service.plist", "Contents/Library/LoginItems/Helper.app/Contents/Info.plist", "Contents/Library/HelperTools/helper", "Contents/Library/SystemExtensions/test.systemextension/Info.plist", "Contents/Library/DriverExtensions/test.dext/Info.plist", "Contents/Library/Extensions/test.kext/Info.plist", "Contents/Frameworks/Setapp.framework/Info.plist", "Contents/Resources/.toolbox/metadata.json"])
    func serviceAndProviderMarkersBlock(_ marker: String) async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try fixture(box)
        try box.write("Example.app/" + marker, "Synthetic marker")
        await #expect(throws: (any Error).self) { try await SimulatedStandaloneChecker(roots: [box.root.path]).check(item) }
    }
    @Test func rejectsPrivilegeDeclarationsMissingExecutablesAndMismatchedIdentity() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        var item = try fixture(box)
        let checker = SimulatedStandaloneChecker(roots: [box.root.path])
        item.bundleID = "com.apple.synthetic"
        await #expect(throws: (any Error).self) { try await checker.check(item) }
        item.bundleID = "org.example.app"
        let infoURL = URL(fileURLWithPath: item.path! + "/Contents/Info.plist")
        var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil) as! [String: Any]
        info["SMPrivilegedExecutables"] = ["org.example.helper": "synthetic"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)
        await #expect(throws: (any Error).self) { try await checker.check(item) }
        info.removeValue(forKey: "SMPrivilegedExecutables"); info["CFBundleExecutable"] = "missing"
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)
        await #expect(throws: (any Error).self) { try await checker.check(item) }
    }
    @Test func symbolicLinksAndLinkedDiscoveryAreRejected() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try fixture(box)
        let alias = box.root.appendingPathComponent("Link.app").path
        try FileManager.default.createSymbolicLink(atPath: alias, withDestinationPath: item.path!)
        let linked = try NativeScanner.item(at: alias)
        #expect(linked.attributes["Linked discovery"] != nil)
        await #expect(throws: (any Error).self) { try await SimulatedStandaloneChecker(roots: [box.root.path]).check(linked) }
        let scan = try await NativeScanner(roots: [box.root.path]).scan()
        #expect(scan.items.count == 1)
        #expect(scan.items[0].attributes["Linked discovery"] != nil)
        await #expect(throws: (any Error).self) { try await SimulatedStandaloneChecker(roots: [box.root.path]).check(scan.items[0]) }
    }
    @Test func everyManagerClaimAndIncompleteAuditBlocks() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try fixture(box)
        let reports = StandaloneRemovalChecker.managers.map { SourceReport($0, .notInstalled) }
        let clean = InventorySnapshot(items: [], reports: reports)
        try StandaloneRemovalChecker.validateOwnership(item, snapshot: clean)
        for source in StandaloneRemovalChecker.managers {
            var snapshot = clean
            var claim = item; claim.primarySource = source
            snapshot.observations[source.rawValue] = [claim]
            #expect(throws: (any Error).self) { try StandaloneRemovalChecker.validateOwnership(item, snapshot: snapshot) }
            claim.path = nil; claim.relatedPaths = [item.path! + "/Contents/Info.plist"]
            snapshot.observations[source.rawValue] = [claim]
            #expect(throws: (any Error).self) { try StandaloneRemovalChecker.validateOwnership(item, snapshot: snapshot) }
            for state in [SourceState.failed, .unsupported, .canceled, .scanning] {
                snapshot = clean
                snapshot.reports.removeAll { $0.source == source }
                snapshot.reports.append(SourceReport(source, state))
                #expect(throws: (any Error).self) { try StandaloneRemovalChecker.validateOwnership(item, snapshot: snapshot) }
            }
        }
        #expect(throws: (any Error).self) { try StandaloneRemovalChecker.validateOwnership(item, snapshot: InventorySnapshot(items: [], reports: [])) }
    }
    @Test func ownershipChangesBeforeExecutionNeverReachExecutor() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try fixture(box), recorder = TrashRecorder()
        let eligibility = try await SimulatedStandaloneChecker(roots: [box.root.path]).check(item)
        let plan = UninstallPlanner.plan(for: item, standaloneEligibility: eligibility)
        let session = UninstallSession(executor: recorder, validator: FreshUninstallValidator(standaloneChecker: OwnershipChanged()))
        await session.prepare(plan)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        #expect(await recorder.calls == 0)
        #expect(FileSystem.exists(item.path!))
    }
    @Test func executableReplacementInvalidatesConfirmedIdentity() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try fixture(box)
        let checker = SimulatedStandaloneChecker(roots: [box.root.path])
        let plan = UninstallPlanner.plan(for: item, standaloneEligibility: try await checker.check(item))
        try box.write("Example.app/Contents/MacOS/Example", "Changed synthetic executable content")
        await #expect(throws: (any Error).self) { try await FreshUninstallValidator(standaloneChecker: checker).validate(plan) }
    }
}
