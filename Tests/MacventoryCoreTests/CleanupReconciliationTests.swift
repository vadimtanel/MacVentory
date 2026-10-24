import Foundation
import Testing
@testable import MacventoryCore

private struct FixturePresence: AppDataPresenceChecking {
    var result: AppDataPresence
    func presence(_ path: String) -> AppDataPresence { result }
}
private actor CleanupCalls {
    var paths: [String] = []
    func record(_ path: String) { paths.append(path) }
}
@Suite("Missing targets and independent cleanup reconciliation")
struct CleanupReconciliationTests {
    private func candidates(_ box: Sandbox) throws -> [AppDataCandidate] {
        try box.write("Library/Caches/net.fiction.a/file", "fixture")
        try box.write("Library/Preferences/net.fiction.a.plist", "fixture")
        return AppDataDiscoveryService(library: box.root.appendingPathComponent("Library"), home: box.root).discover(for: .init(name: "Orchard", bundleID: "net.fiction.a", evidence: "Fixture", installed: false)).candidates
    }
    @Test func alreadyMissingDoesNotSubmitAndIndependentItemContinues() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let found = try candidates(box), calls = CleanupCalls()
        try FileManager.default.removeItem(atPath: found[0].path)
        let result = await AppDataCleanupRunner.run(found, simulated: true, recycle: { await calls.record($0.path) })
        #expect(result.results.map(\.status) == [.alreadyRemoved, .moved])
        #expect(await calls.paths == [found[1].path])
        #expect(result.summary.contains("1 already absent"))
        #expect(FileManager.default.fileExists(atPath: found[1].path))
    }
    @Test func reconciliationDropsOnlyConfirmedMissingAndRemovesEmptyGroups() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let found = try candidates(box)
        let identity = ApplicationIdentity(name: "Orchard", bundleID: "net.fiction.a", evidence: "Fixture", installed: false)
        let groups = [AppDataDiscoveryResult(identity: identity, candidates: found)]
        #expect(LeftoverReconciliation.reconcile(groups, checking: FixturePresence(result: .permissionDenied)).first?.candidates.count == 2)
        #expect(LeftoverReconciliation.reconcile(groups, checking: FixturePresence(result: .inconclusive)).first?.candidates.count == 2)
        try FileManager.default.removeItem(atPath: found[0].path)
        let remaining = LeftoverReconciliation.reconcile(groups)
        #expect(remaining.first?.candidates.map(\.id) == [found[1].id])
        #expect(LeftoverPresentationGroup.make(from: remaining, mode: .application).first?.measuredSize == found[1].sizeBytes)
        try FileManager.default.removeItem(atPath: found[1].path)
        #expect(LeftoverReconciliation.reconcile(remaining).isEmpty)
    }
    @Test func permissionAndChangedIdentityAreIndividualFailures() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        var found = try candidates(box); found[0].identity?.inode += 1
        let calls = CleanupCalls()
        let changed = await AppDataCleanupRunner.run(found, simulated: true, recycle: { await calls.record($0.path) })
        #expect(changed.results.map(\.status) == [.changed, .moved])
        #expect(changed.stepStatus == .partial)
        let denied = await AppDataCleanupRunner.run([found[1]], checking: FixturePresence(result: .permissionDenied), recycle: { _ in Issue.record("Must not submit denied item") })
        #expect(denied.results.first?.status == .permissionDenied)
    }
    @Test func unknownOutcomeStopsLaterRequestsAndNeverReportsRemoval() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let found = try candidates(box), calls = CleanupCalls()
        let outcome = await AppDataCleanupRunner.run(found, recycle: { item in
            await calls.record(item.path); throw AppDataCleanupError.unknownOutcome
        })
        #expect(outcome.results.map(\.status) == [.unknown, .skipped])
        #expect(await calls.paths.count == 1)
        #expect(outcome.results.allSatisfy { !$0.completed })
    }
    @Test func protectedAndOverlappingTargetsCannotBeSubmitted() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        var found = try candidates(box); found[0].classification = .protected
        let expectedID = found[1].id
        let result = await AppDataCleanupRunner.run(found, simulated: true, recycle: { item in #expect(item.id == expectedID) })
        #expect(result.results.map(\.status) == [.protected, .moved])
        let duplicate = await AppDataCleanupRunner.run([found[1], found[1]], recycle: { _ in Issue.record("Duplicates must not submit") })
        #expect(duplicate.results.allSatisfy { $0.status == .failed })
    }
    @Test func combinedReviewReportsMissingItemWithoutBlockingIndependentCleanup() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let found = try candidates(box)
        try FileManager.default.removeItem(atPath: found[0].path)
        var app = SoftwareItem(name: "Orchard"); app.bundleID = "net.fiction.a"
        let identity = ApplicationIdentity(item: app)
        let target = RunningApplicationTarget(processIdentifier: 999_999, bundleURL: "/Synthetic/Orchard.app", bundleID: "net.fiction.a")
        let request = ManagementRequest(item: app, identity: identity, target: target, candidates: found, operations: [.forceQuit, .clearData])
        let result = try await ManagementSession(executor: SimulatedManagementExecutor(), simulated: true).confirm(request, acknowledged: true)
        #expect(result.steps.map(\.status) == [.completed, .completed])
        #expect(result.steps.last?.cleanupResults.map(\.status) == [.alreadyRemoved, .moved])
    }
    @Test func danglingAncestorIsNotConfirmedAbsent() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try FileManager.default.createSymbolicLink(atPath: box.root.appendingPathComponent("linked").path, withDestinationPath: box.root.appendingPathComponent("absent").path)
        #expect(NativeAppDataPresenceChecker().presence(box.root.appendingPathComponent("linked/child").path) == .inconclusive)
    }
    @Test func selectedFolderIsOneWholeTargetAndItsParentIsNeverSubmitted() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("Documents/Orchard/nested/work.txt", "fixture")
        try box.write("Documents/unrelated.txt", "unrelated fixture")
        let service = AppDataDiscoveryService(library: box.root.appendingPathComponent("Library"), home: box.root)
        let folder = try #require(service.manualCandidate(path: box.root.appendingPathComponent("Documents/Orchard").path))
        let calls = CleanupCalls()
        let outcome = await AppDataCleanupRunner.run([folder], simulated: true, recycle: { await calls.record($0.path) })
        #expect(await calls.paths == [box.root.appendingPathComponent("Documents/Orchard").path])
        #expect(outcome.results.count == 1)
        #expect(FileManager.default.fileExists(atPath: folder.path + "/nested/work.txt"))
        #expect(FileManager.default.fileExists(atPath: box.root.appendingPathComponent("Documents/unrelated.txt").path))
    }
    @Test func permissionFailureExplainsWhichCheckFailed() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let found = try candidates(box)
        let outcome = await AppDataCleanupRunner.run([found[0]], validate: { item in
            throw AppDataAccessError(path: item.path, action: "reading the selected location")
        }, recycle: { _ in Issue.record("Denied targets must not submit") })
        #expect(outcome.results.first?.status == .permissionDenied)
        #expect(outcome.results.first?.message.contains("reading the selected location") == true)
        #expect(outcome.results.first?.message.contains(found[0].path) == true)
    }
}
