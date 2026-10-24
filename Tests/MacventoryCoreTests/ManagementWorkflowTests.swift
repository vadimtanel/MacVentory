import Foundation
import Testing
@testable import MacventoryCore

private actor WorkflowRecorder: ManagementExecuting {
    var performed: [ManagementOperation] = []
    var fail: ManagementOperation?
    var invalid: Bool
    init(fail: ManagementOperation? = nil, invalid: Bool = false) { self.fail = fail; self.invalid = invalid }
    func validate(_ request: ManagementRequest) async throws { if invalid { throw ScanError.permission } }
    func perform(_ operation: ManagementOperation, request: ManagementRequest) async throws -> ManagementStepResult {
        performed.append(operation)
        try await Task.sleep(for: .milliseconds(15))
        if operation == fail { throw ScanError.process("Fixture failure") }
        return .init(operation, .completed, "Fixture success")
    }
}

@Suite("Unified management lifecycle and ordering")
struct ManagementWorkflowTests {
    @MainActor @Test func stalledNativeCallbackTimesOutAndLateCallbacksCannotRepeatCompletion() async throws {
        var completion: (@MainActor @Sendable (Result<Void, any Error>) -> Void)?
        do {
            try await NativeTrashRequest.perform(timeout: .milliseconds(2)) { completion = $0 }
            Issue.record("A stalled callback must not report success")
        } catch { #expect(error.localizedDescription.contains("outcome is unknown")) }
        completion?(.success(())); completion?(.failure(ScanError.permission))
        // Both late callbacks must be ignored. No native Trash adapter is invoked.
    }
    @Test func qaFactoryCannotSupplyProductionExecutorsEvenWithInjectedFailureFlags() {
        for mode in [InventoryRunMode.uiTesting, .demo, .safeQA] {
            #expect(ManagementExecutorFactory.make(mode: mode) is SimulatedManagementExecutor)
            #expect(ManagementExecutorFactory.make(mode: mode, failure: .uninstall, partialCleanup: true) is SimulatedManagementExecutor)
        }
    }
    private func request(_ operations: Set<ManagementOperation>) -> ManagementRequest {
        .init(item: nil, identity: .init(name: "Fixture", bundleID: "org.example.fixture", evidence: "Synthetic", installed: false), operations: operations)
    }
    @Test(arguments: 1...7) func allCombinationsExecuteOnlyTheirSelectedStepsInOrder(mask: Int) async throws {
        let operations = Set(ManagementOperation.allCases.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element))
        let recorder = WorkflowRecorder()
        let recordedSession = ManagementSession(executor: recorder, simulated: true)
        let result = try await recordedSession.confirm(request(operations), acknowledged: true)
        #expect(result.title == "Operation completed.")
        #expect(await recorder.performed == ManagementOperation.allCases.filter { operations.contains($0) })
    }
    @Test func confirmationIsRequiredSingleUseAndCanReopenWithNewRequest() async throws {
        let recorder = WorkflowRecorder(), session = ManagementSession(executor: recorder, simulated: true)
        let first = request([.uninstall])
        await #expect(throws: (any Error).self) { try await session.confirm(first, acknowledged: false) }
        #expect(await recorder.performed.isEmpty)
        _ = try await session.confirm(first, acknowledged: true)
        await #expect(throws: (any Error).self) { try await session.confirm(first, acknowledged: true) }
        _ = try await session.confirm(request([.uninstall]), acknowledged: true)
        #expect(await recorder.performed.count == 2)
    }
    @Test func failurePreservesEarlierSuccessAndSkipsLaterOperations() async throws {
        let recorder = WorkflowRecorder(fail: .clearData)
        let actual = ManagementSession(executor: recorder, simulated: false)
        let result = try await actual.confirm(request(Set(ManagementOperation.allCases)), acknowledged: true)
        #expect(result.title == "Partially completed.")
        #expect(result.steps.map(\.status) == [.completed, .failed, .skipped])
        #expect(await recorder.performed == [.forceQuit, .clearData])
    }
    @Test(arguments: ManagementOperation.allCases) func individualExecutionFailuresAlwaysProduceTerminalResult(operation: ManagementOperation) async throws {
        let session = ManagementSession(executor: WorkflowRecorder(fail: operation), simulated: true)
        let result = try await session.confirm(request([operation]), acknowledged: true)
        #expect(result.title == "Operation failed.")
        #expect(result.steps.first?.status == .failed)
    }
    @Test func preflightFailurePerformsNothing() async throws {
        let recorder = WorkflowRecorder(invalid: true)
        let result = try await ManagementSession(executor: recorder, simulated: true).confirm(request(Set(ManagementOperation.allCases)), acknowledged: true)
        #expect(result.steps.map(\.status) == [.failed, .skipped, .skipped])
        #expect(await recorder.performed.isEmpty)
    }
    @Test func cancellationDuringAwaitCannotExecuteNextStepOrBeReportedAsSuccess() async throws {
        let recorder = WorkflowRecorder(), session = ManagementSession(executor: recorder, simulated: true)
        let task = Task { try await session.confirm(request(Set(ManagementOperation.allCases)), acknowledged: true) }
        try await Task.sleep(for: .milliseconds(2)); task.cancel()
        let result = try await task.value
        #expect(result.title == "Operation cancelled.")
        #expect(result.steps.contains { $0.status == .cancelled })
        #expect(!result.steps.contains { $0.operation == .uninstall && $0.status == .completed })
    }
    @Test func simultaneousConfirmationCannotRunTwice() async throws {
        let recorder = WorkflowRecorder(), session = ManagementSession(executor: recorder, simulated: true), review = request([.uninstall])
        async let first = try? session.confirm(review, acknowledged: true)
        async let second = try? session.confirm(review, acknowledged: true)
        let results = await [first, second]
        #expect(results.compactMap { $0 }.count == 1)
        #expect(await recorder.performed.count == 1)
    }
    @Test func partialCleanupAndSimulationMessagesDoNotClaimActualRemoval() {
        let partial = ManagementResult(steps: [.init(.clearData, .partial, "One succeeded; one denied")], simulated: false)
        #expect(partial.title == "Partially completed.")
        #expect(!partial.explanation.contains("selected items were moved"))
        let success = ManagementResult(steps: [.init(.clearData, .completed, "Trash confirmed")], simulated: false)
        #expect(success.title == "Operation completed.")
        #expect(success.explanation == "The selected items were moved to Trash.")
        let simulated = ManagementResult(steps: [.init(.uninstall, .completed, "Mock only")], simulated: true)
        #expect(simulated.explanation.contains("No application, process or data was changed"))
        let uninstall = ManagementResult(steps: [.init(.uninstall, .completed, "Confirmed")], simulated: false)
        #expect(uninstall.explanation == "The reviewed application was removed. Refresh the inventory to verify its remaining state.")
    }
    @Test func selectionValidationRejectsMissingTargetsAndEmptyCleanup() throws {
        #expect(throws: (any Error).self) { try ManagementValidation.validateSelection(request([.forceQuit])) }
        #expect(throws: (any Error).self) { try ManagementValidation.validateSelection(request([.clearData])) }
        #expect(throws: (any Error).self) { try ManagementValidation.validateSelection(request([.uninstall])) }
    }
    @Test func changedMissingDuplicateAndNestedDataCannotPassPreflight() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("Library/Caches/org.example.fixture/child/file", "fixture")
        let service = AppDataDiscoveryService(library: box.root.appendingPathComponent("Library"), home: box.root)
        let candidate = try #require(service.discover(for: .init(name: "Fixture", bundleID: "org.example.fixture", evidence: "Synthetic", installed: false)).candidates.first)
        try AppDataSafety.validateSelection([candidate])
        #expect(throws: (any Error).self) { try AppDataSafety.validateSelection([candidate, candidate]) }
        var nested = candidate; nested.path += "/child"; nested.identity = FileIdentity(path: nested.path)
        #expect(throws: (any Error).self) { try AppDataSafety.validateSelection([candidate, nested]) }
        var changed = candidate; changed.identity?.inode += 1
        #expect(throws: (any Error).self) { try AppDataSafety.validateSelection([changed]) }
        var missing = candidate; missing.path += "/missing"
        #expect(throws: (any Error).self) { try AppDataSafety.validateSelection([missing]) }
    }
}
