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
private actor GatedValidation: UninstallValidating {
    var started = false
    var entered: CheckedContinuation<Void, Never>?
    var release: CheckedContinuation<Void, Never>?
    func waitUntilStarted() async {
        if !started { await withCheckedContinuation { entered = $0 } }
    }
    func proceed() { release?.resume(); release = nil }
    func validate(_ plan: UninstallPlan) async throws {
        started = true; entered?.resume(); entered = nil
        await withCheckedContinuation { release = $0 }
        try await FreshUninstallValidator(standaloneChecker: SimulatedStandaloneChecker(roots: [URL(fileURLWithPath: plan.item.path!).deletingLastPathComponent().path])).validate(plan)
    }
}
@Suite("Non-destructive uninstall planning and simulation")
struct UninstallTests {
    private func standalone(_ box: Sandbox) throws -> SoftwareItem {
        var item = try NativeScanner.item(at: box.app())
        item.sources = [.init(.unmanaged, Evidence("Synthetic verified fixture"))]
        let infoURL = URL(fileURLWithPath: item.path! + "/Contents/Info.plist")
        var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil) as! [String: Any]
        info["CFBundleExecutable"] = "Example"
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)
        try box.write("Example.app/Contents/MacOS/Example", "Synthetic fixture, never executed")
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: item.path! + "/Contents/MacOS/Example")
        return item
    }
    private func reviewPlan(for item: SoftwareItem, running: Bool = false) -> UninstallPlan {
        let roots = [URL(fileURLWithPath: item.path ?? "/").deletingLastPathComponent().path]
        let eligibility = (try? StandaloneRemovalChecker.inspect(item, roots: roots)).map { StandaloneEligibility(fingerprint: $0, configuration: ScanConfiguration(), roots: roots) }
        return UninstallPlanner.plan(for: item, running: running, standaloneEligibility: eligibility)
    }
    private func validator(_ item: SoftwareItem) -> FreshUninstallValidator {
        FreshUninstallValidator(standaloneChecker: SimulatedStandaloneChecker(roots: [URL(fileURLWithPath: item.path!).deletingLastPathComponent().path]))
    }
    @Test func confirmationAndSimulationLeaveTargetUntouched() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval()
        let before = try UninstallPlanner.fingerprint(item)
        let plan = reviewPlan(for: item)
        #expect(plan.method == .trashBundle)
        let session = UninstallSession(executor: recorder, validator: validator(item))
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
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval()
        let plan = reviewPlan(for: item), session = UninstallSession(executor: recorder, validator: validator(item))
        await session.prepare(plan); await session.cancel()
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        #expect(await recorder.calls == 0)
    }
    @Test func changedTargetCannotUseOldConfirmation() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval()
        let plan = reviewPlan(for: item), session = UninstallSession(executor: recorder, validator: validator(item))
        await session.prepare(plan)
        _ = try box.app(name: "Changed synthetic fixture")
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        #expect(await recorder.calls == 0)
    }
    @Test func permissionsAndExecutionFailuresAreSimulated() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval(fail: true)
        let plan = reviewPlan(for: item)
        let denied = UninstallSession(executor: recorder, validator: RejectValidation())
        await denied.prepare(plan)
        await #expect(throws: (any Error).self) { try await denied.confirm(id: plan.id, acknowledged: true) }
        #expect(await recorder.calls == 0)
        let failed = UninstallSession(executor: recorder, validator: validator(item))
        await failed.prepare(plan)
        await #expect(throws: (any Error).self) { try await failed.confirm(id: plan.id, acknowledged: true) }
        #expect(await recorder.calls == 1)
        #expect(FileSystem.exists(item.path!))
    }
    @Test func protectsSystemRunningStaleAndUncertainApplications() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        var item = try standalone(box)
        #expect(reviewPlan(for: item, running: true).method == .blocked)
        item.isSystem = true; #expect(!reviewPlan(for: item).canExecute)
        item.isSystem = false; item.stale = true; #expect(!reviewPlan(for: item).canExecute)
        item.stale = false; item.sources = [.init(.unmanaged, Evidence("Inferred", confidence: .inferred))]
        #expect(reviewPlan(for: item).method == .trashBundle)
        item.primarySource = .unknown; #expect(reviewPlan(for: item).method == .blocked)
    }
    @Test func receiptsAndOtherManagersNeverBecomeBundleDeletion() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        for source in [InstallSource.steam, .setapp, .toolbox, .macPorts, .nix, .homebrewFormula] {
            var item = try standalone(box); item.primarySource = source; item.sources = [.init(source, Evidence("Fixture"))]
            #expect(reviewPlan(for: item).method == .external)
        }
    }
    @Test func safeCaskPlansOnlyExactTokenWithoutCleanup() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
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
        item.health = .init(.verified, "Synthetic manager verified installed", registration: .installed, artifacts: [.init(path, .present)])
        item.attributes["Homebrew receipt"] = box.root.appendingPathComponent(receipt + "/INSTALL_RECEIPT.json").path
        item.attributes["Homebrew executable"] = box.root.appendingPathComponent("bin/brew").path
        let plan = reviewPlan(for: item)
        #expect(plan.method == .homebrewCask)
        #expect(plan.arguments == ["uninstall", "--cask", "--", "example"])
        try box.write(receipt + "/INSTALL_RECEIPT.json", "{\"uninstall_flight_blocks\":[\"unknown hook\"],\"uninstall_artifacts\":[{\"app\":[\"Example.app\"]}]}")
        #expect(reviewPlan(for: item).method == .external)
        #expect(!plan.arguments.contains("--zap")); #expect(!plan.arguments.contains("--force"))
        try box.write(receipt + "/INSTALL_RECEIPT.json", "{\"uninstall_artifacts\":[{\"app\":[\"Example.app\"]},{\"uninstall\":[{\"script\":\"forbidden\"}]}]}")
        #expect(reviewPlan(for: item).method == .external)
    }
    @Test func checkboxResetsForEveryPlanAndCannotAuthorizeAnotherTarget() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval()
        let first = reviewPlan(for: item), replacement = reviewPlan(for: item)
        var review = UninstallReviewState(planID: first.id)
        #expect(!review.acknowledged)
        review.acknowledged = true
        review.reset(for: replacement.id)
        #expect(!review.acknowledged && review.planID == replacement.id)
        let session = UninstallSession(executor: recorder, validator: validator(item))
        await session.prepare(first); await session.prepare(replacement)
        await #expect(throws: (any Error).self) { try await session.confirm(id: first.id, acknowledged: true) }
        #expect(await recorder.calls == 0)
        #expect(try await session.confirm(id: replacement.id, acknowledged: true) == .simulated)
        #expect(await recorder.calls == 1)
    }
    @Test func duplicateRequestsDuringValidationCannotExecuteTwice() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try standalone(box), recorder = RecordingRemoval()
        let plan = reviewPlan(for: item), replacement = reviewPlan(for: item)
        let gate = GatedValidation()
        let session = UninstallSession(executor: recorder, validator: gate)
        await session.prepare(plan)
        async let result = session.confirm(id: plan.id, acknowledged: true)
        await gate.waitUntilStarted()
        await session.prepare(replacement)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        await #expect(throws: (any Error).self) { try await session.confirm(id: replacement.id, acknowledged: true) }
        await gate.proceed()
        #expect(try await result == .simulated)
        #expect(await recorder.calls == 1)
    }
    @Test func unsupportedAndProtectedPreviewsNeverExecute() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let recorder = RecordingRemoval()
        var item = try standalone(box)
        let session = UninstallSession(executor: recorder, validator: validator(item))
        for kind in [SoftwareKind.package, .app] {
            item.kind = kind; item.isSystem = kind == .app
            let plan = reviewPlan(for: item)
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
