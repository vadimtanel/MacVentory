import Foundation
import Testing
@testable import MacventoryCore

private actor RecordingRemoval: UninstallExecuting {
    private(set) var calls = 0
    var fail: Bool
    init(fail: Bool = false) { self.fail = fail }
    func execute(_ plan: UninstallPlan) async throws -> UninstallOutcome {
        calls += 1
        if fail { throw ScanError.permission }
        return .simulated // Never calls Process, trashItem, removeItem or a manager.
    }
}
private struct RejectValidation: UninstallValidating {
    func validate(_ plan: UninstallPlan) async throws { throw ScanError.permission }
}
private struct SlowValidation: UninstallValidating {
    func validate(_ plan: UninstallPlan) async throws {
        try await Task.sleep(for: .milliseconds(100))
        try await FreshUninstallValidator().validate(plan)
    }
}
@Suite("Non-destructive uninstall planning and simulation")
struct UninstallTests {
    private func standalone(_ box: Sandbox) throws -> SoftwareItem {
        var item = try NativeScanner.item(at: box.app())
        item.sources = [.init(.unmanaged, Evidence("Synthetic verified fixture"))]
        item.attributes["Bundle-only removal"] = "Verified eligible"
        return item
    }
    @Test func confirmationAndSimulationLeaveTargetUntouched() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval()
        let before = try UninstallPlanner.fingerprint(item)
        let plan = UninstallPlanner.plan(for: item)
        #expect(plan.method == .trashBundle)
        let session = UninstallSession(executor: recorder)
        await session.prepare(plan)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: false) }
        #expect(await recorder.calls == 0)
        #expect(try await session.confirm(id: plan.id, acknowledged: true) == .simulated)
        #expect(await recorder.calls == 1)
        #expect(try UninstallPlanner.fingerprint(item) == before)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        #expect(await recorder.calls == 1)
    }
    @Test func cancelBeforeConfirmationNeverExecutes() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval()
        let plan = UninstallPlanner.plan(for: item), session = UninstallSession(executor: recorder)
        await session.prepare(plan); await session.cancel()
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        #expect(await recorder.calls == 0)
    }
    @Test func changedTargetCannotUseOldConfirmation() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval()
        let plan = UninstallPlanner.plan(for: item), session = UninstallSession(executor: recorder)
        await session.prepare(plan)
        _ = try box.app(name: "Changed synthetic fixture")
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        #expect(await recorder.calls == 0)
    }
    @Test func permissionsAndExecutionFailuresAreSimulated() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval(fail: true)
        let plan = UninstallPlanner.plan(for: item)
        let denied = UninstallSession(executor: recorder, validator: RejectValidation())
        await denied.prepare(plan)
        await #expect(throws: (any Error).self) { try await denied.confirm(id: plan.id, acknowledged: true) }
        #expect(await recorder.calls == 0)
        let failed = UninstallSession(executor: recorder)
        await failed.prepare(plan)
        await #expect(throws: (any Error).self) { try await failed.confirm(id: plan.id, acknowledged: true) }
        #expect(await recorder.calls == 1)
        #expect(FileSystem.exists(item.path!))
    }
    @Test func protectsSystemRunningStaleAndUncertainApplications() throws {
        let box = try Sandbox(); defer { box.clean() }
        var item = try standalone(box)
        #expect(UninstallPlanner.plan(for: item, running: true).method == .blocked)
        item.isSystem = true; #expect(!UninstallPlanner.plan(for: item).canExecute)
        item.isSystem = false; item.stale = true; #expect(!UninstallPlanner.plan(for: item).canExecute)
        item.stale = false; item.sources = [.init(.unmanaged, Evidence("Inferred", confidence: .inferred))]
        #expect(UninstallPlanner.plan(for: item).method == .external)
        item.primarySource = .unknown; #expect(UninstallPlanner.plan(for: item).method == .blocked)
    }
    @Test func receiptsAndOtherManagersNeverBecomeBundleDeletion() throws {
        let box = try Sandbox(); defer { box.clean() }
        for source in [InstallSource.pkg, .steam, .setapp, .toolbox, .macPorts, .nix, .homebrewFormula] {
            var item = try standalone(box); item.primarySource = source; item.sources = [.init(source, Evidence("Fixture"))]
            #expect(UninstallPlanner.plan(for: item).method == .external)
        }
    }
    @Test func safeCaskPlansOnlyExactTokenWithoutCleanup() throws {
        let box = try Sandbox(); defer { box.clean() }
        let path = try box.app("Applications/Example.app")
        let receipt = "Caskroom/example/.metadata"
        try box.write(receipt + "/INSTALL_RECEIPT.json", "{\"uninstall_artifacts\":[{\"app\":[\"Example.app\"]},{\"zap\":[{\"trash\":\"ignored user data\"}]}]}")
        let config = ["default": ["appdir": box.root.appendingPathComponent("Applications").path]]
        try box.write(receipt + "/config.json", String(decoding: try JSONSerialization.data(withJSONObject: config), as: UTF8.self))
        // A fake manager file establishes a path for planning only. It is never executed.
        try box.write("bin/brew", "not executable code")
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: box.root.appendingPathComponent("bin/brew").path)
        var item = try NativeScanner.item(at: path); item.primarySource = .homebrewCask; item.packageID = "example"
        item.sources = [.init(.homebrewCask, Evidence("Fixture receipt"))]
        item.attributes["Homebrew receipt"] = box.root.appendingPathComponent(receipt + "/INSTALL_RECEIPT.json").path
        item.attributes["Homebrew executable"] = box.root.appendingPathComponent("bin/brew").path
        let plan = UninstallPlanner.plan(for: item)
        #expect(plan.method == .homebrewCask)
        #expect(plan.arguments == ["uninstall", "--cask", "--", "example"])
        try box.write(receipt + "/INSTALL_RECEIPT.json", "{\"uninstall_flight_blocks\":[\"unknown hook\"],\"uninstall_artifacts\":[{\"app\":[\"Example.app\"]}]}")
        #expect(UninstallPlanner.plan(for: item).method == .external)
        #expect(!plan.arguments.contains("--zap")); #expect(!plan.arguments.contains("--force"))
        try box.write(receipt + "/INSTALL_RECEIPT.json", "{\"uninstall_artifacts\":[{\"app\":[\"Example.app\"]},{\"uninstall\":[{\"script\":\"forbidden\"}]}]}")
        #expect(UninstallPlanner.plan(for: item).method == .external)
    }
    @Test func checkboxResetsForEveryPlanAndCannotAuthorizeAnotherTarget() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval()
        let first = UninstallPlanner.plan(for: item), replacement = UninstallPlanner.plan(for: item)
        var review = UninstallReviewState(planID: first.id)
        #expect(!review.acknowledged)
        review.acknowledged = true
        review.reset(for: replacement.id)
        #expect(!review.acknowledged && review.planID == replacement.id)
        let session = UninstallSession(executor: recorder)
        await session.prepare(first); await session.prepare(replacement)
        await #expect(throws: (any Error).self) { try await session.confirm(id: first.id, acknowledged: true) }
        #expect(await recorder.calls == 0)
        #expect(try await session.confirm(id: replacement.id, acknowledged: true) == .simulated)
        #expect(await recorder.calls == 1)
    }
    @Test func duplicateRequestsDuringValidationCannotExecuteTwice() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval()
        let plan = UninstallPlanner.plan(for: item), replacement = UninstallPlanner.plan(for: item)
        let session = UninstallSession(executor: recorder, validator: SlowValidation())
        await session.prepare(plan)
        async let result = session.confirm(id: plan.id, acknowledged: true)
        try await Task.sleep(for: .milliseconds(20))
        await session.prepare(replacement)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        await #expect(throws: (any Error).self) { try await session.confirm(id: replacement.id, acknowledged: true) }
        #expect(try await result == .simulated)
        #expect(await recorder.calls == 1)
    }
    @Test func unsupportedAndProtectedPreviewsNeverExecute() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let recorder = RecordingRemoval(), session = UninstallSession(executor: recorder)
        var item = try standalone(box)
        for kind in [SoftwareKind.package, .app] {
            item.kind = kind; item.isSystem = kind == .app
            let plan = UninstallPlanner.plan(for: item)
            #expect(!plan.canExecute && !plan.explanation.isEmpty)
            await session.prepare(plan)
            await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        }
        #expect(await recorder.calls == 0)
    }
    @Test func completionCopySeparatesActualAndSimulatedSuccess() {
        #expect(UninstallOutcome.completed.completionMessage == "Operation completed.\nRefresh the inventory to verify the remaining installation state.")
        #expect(UninstallOutcome.simulated.completionMessage == "Simulation completed. Nothing was removed or modified.")
    }
    @Test func tokenInjectionIsRejected() {
        for token in ["--zap", "foo;rm", "../foo", "foo/bar", "foo bar", "$(bad)", ""] { #expect(!UninstallPlanner.validToken(token)) }
        #expect(UninstallPlanner.validToken("intellij-idea@2026"))
    }
}
