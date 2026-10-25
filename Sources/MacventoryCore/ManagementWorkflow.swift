import Foundation

public enum ManagementOperation: String, CaseIterable, Sendable { case forceQuit = "Force Quit", clearData = "Clear App Data", uninstall = "Uninstall" }
public enum ManagementStepStatus: String, Sendable {
    case completed, partial, failed, skipped, cancelled, waitingForUser, unknown
    public var title: String { self == .waitingForUser ? "Waiting for User" : rawValue.capitalized }
}
public struct ManagementStepResult: Sendable, Identifiable {
    public var id: ManagementOperation { operation }
    public var operation: ManagementOperation
    public var status: ManagementStepStatus
    public var detail: String
    public var cleanupResults: [AppDataCleanupItemResult]
    public init(_ operation: ManagementOperation, _ status: ManagementStepStatus, _ detail: String, cleanupResults: [AppDataCleanupItemResult] = []) { self.operation = operation; self.status = status; self.detail = detail; self.cleanupResults = cleanupResults }
}
public struct ManagementResult: Sendable {
    public var steps: [ManagementStepResult]
    public var simulated: Bool
    public init(steps: [ManagementStepResult], simulated: Bool) { self.steps = steps; self.simulated = simulated }
    public var canVerifyInteractiveRemoval: Bool {
        steps.contains { $0.operation == .uninstall && [.waitingForUser, .partial, .unknown].contains($0.status) }
    }
    public func verifyingInteractiveRemoval(_ outcome: UninstallOutcome) -> ManagementResult {
        guard canVerifyInteractiveRemoval else { return self }
        let status: ManagementStepStatus
        switch outcome {
        case .verifiedRemoved, .appBundleRemoved, .packageRegistrationRemoved: status = .completed
        case .waitingForUser: status = .waitingForUser
        case .partialRemoval: status = .partial
        default: status = .unknown
        }
        return .init(steps: steps.map { $0.operation == .uninstall ? .init(.uninstall, status, outcome.completionMessage) : $0 }, simulated: simulated)
    }
    public var title: String {
        let items = steps.flatMap(\.cleanupResults)
        if steps.count == 1, !items.isEmpty, items.allSatisfy({ $0.status == .alreadyRemoved }) { return "Already Removed" }
        if steps.allSatisfy({ $0.status == .completed }), !steps.isEmpty { return "Operation completed." }
        if steps.contains(where: { $0.status == .completed || $0.status == .partial }) { return "Partially completed." }
        if steps.contains(where: { $0.status == .waitingForUser }) { return "Waiting for User" }
        if steps.contains(where: { $0.status == .unknown }) { return "Outcome Unverified" }
        if steps.contains(where: { $0.status == .cancelled }) { return "Operation cancelled." }
        return "Operation failed."
    }
    public var explanation: String {
        if steps.count == 1, !steps[0].cleanupResults.isEmpty { return steps[0].detail }
        if simulated { return "Simulation finished. No application, process or data was changed." }
        if steps.count == 1, steps[0].status == .completed {
            switch steps[0].operation {
            case .forceQuit: return "The application process exited. Background helpers may still be running."
            case .clearData: return "The selected items were moved to Trash."
            case .uninstall: return steps[0].detail
            }
        }
        if steps.allSatisfy({ $0.status == .completed }) {
            return "The selected operations completed."
        }
        return "Review the individual results below. Completed steps cannot be rolled back automatically."
    }
}
public struct ManagementRequest: Sendable, Identifiable {
    public var id = UUID()
    public var item: SoftwareItem?
    public var identity: ApplicationIdentity
    public var target: RunningApplicationTarget?
    public var candidates: [AppDataCandidate]
    /// A cleanup review can present several independently discovered identifiers together.
    /// This mapping preserves the source identity for every selected filesystem target.
    public var candidateIdentities: [String: ApplicationIdentity]
    public var uninstallPlan: UninstallPlan?
    public var operations: Set<ManagementOperation>
    public var createdAt = Date()
    public init(item: SoftwareItem?, identity: ApplicationIdentity, target: RunningApplicationTarget? = nil, candidates: [AppDataCandidate] = [], candidateIdentities: [String: ApplicationIdentity] = [:], uninstallPlan: UninstallPlan? = nil, operations: Set<ManagementOperation>) {
        self.item = item; self.identity = identity; self.target = target; self.candidates = candidates
        self.candidateIdentities = candidateIdentities.isEmpty ? Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, identity) }) : candidateIdentities
        self.uninstallPlan = uninstallPlan; self.operations = operations
    }
    public func identity(for candidate: AppDataCandidate) -> ApplicationIdentity { candidateIdentities[candidate.id] ?? identity }
}
public protocol ManagementExecuting: Sendable {
    func validate(_ request: ManagementRequest) async throws
    func perform(_ operation: ManagementOperation, request: ManagementRequest) async throws -> ManagementStepResult
}
public enum ManagementExecutorFactory {
    public static func make(mode: InventoryRunMode, failure: ManagementOperation? = nil, partialCleanup: Bool = false, missingFirst: Bool = false) -> any ManagementExecuting {
        if mode.allowsLiveRemoval { return LiveManagementExecutor() }
        return SimulatedManagementExecutor(failure: failure, partialCleanup: partialCleanup, missingFirst: missingFirst)
    }
}

/// A confirmation is consumed before any suspension. Reentrancy, double clicks and retries
/// cannot execute the same request twice, including after a failure or cancellation.
public actor ManagementSession {
    private let executor: any ManagementExecuting
    private let simulated: Bool
    private var consumed = Set<UUID>()
    private var executing = false
    public init(executor: any ManagementExecuting, simulated: Bool) { self.executor = executor; self.simulated = simulated }
    public func confirm(_ request: ManagementRequest, acknowledged: Bool) async throws -> ManagementResult {
        guard acknowledged, !request.operations.isEmpty, !executing, !consumed.contains(request.id), Date().timeIntervalSince(request.createdAt) < 300 else { throw ScanError.process("This review has expired or was already used. Reopen the dialog for a new confirmation.") }
        executing = true; consumed.insert(request.id)
        defer { executing = false }
        let ordered = ManagementOperation.allCases.filter { request.operations.contains($0) }
        var results: [ManagementStepResult] = []
        do { try Task.checkCancellation(); try await executor.validate(request) }
        catch {
            let status: ManagementStepStatus = error is CancellationError ? .cancelled : .failed
            return ManagementResult(steps: ordered.enumerated().map { .init($0.element, $0.offset == 0 ? status : .skipped, $0.offset == 0 ? error.localizedDescription : "Skipped because validation did not complete.") }, simulated: simulated)
        }
        for operation in ordered {
            if results.contains(where: { $0.status != .completed }) { results.append(.init(operation, .skipped, "Skipped because an earlier step did not complete.")); continue }
            do { try Task.checkCancellation(); results.append(try await executor.perform(operation, request: request)) }
            catch { results.append(.init(operation, error is CancellationError ? .cancelled : .failed, error.localizedDescription)) }
        }
        return ManagementResult(steps: results, simulated: simulated)
    }
}

/// Selected exclusively for isolated/demo/QA runs. This implementation owns no production
/// executor and never submits a native process, package-manager or Trash request.
public struct SimulatedManagementExecutor: ManagementExecuting {
    public var failure: ManagementOperation?
    public var partialCleanup: Bool
    public var missingFirst: Bool
    public init(failure: ManagementOperation? = nil, partialCleanup: Bool = false, missingFirst: Bool = false) { self.failure = failure; self.partialCleanup = partialCleanup; self.missingFirst = missingFirst }
    public func validate(_ request: ManagementRequest) async throws {
        try ManagementValidation.validateSelection(request)
        try Task.checkCancellation()
    }
    public func perform(_ operation: ManagementOperation, request: ManagementRequest) async throws -> ManagementStepResult {
        try await Task.sleep(for: .milliseconds(250))
        if failure == operation { throw ScanError.process("Simulated \(operation.rawValue) failure; nothing changed.") }
        if operation == .clearData {
            let checking = SimulatedCleanupPresence(missing: missingFirst ? request.candidates.first?.path : nil)
            let outcome = await AppDataCleanupRunner.run(request.candidates, simulated: true, checking: checking, validate: { candidate in
                if partialCleanup && candidate.id == request.candidates.last?.id { throw AppDataAccessError(path: candidate.path, action: "checking simulated write access") }
            }, recycle: { _ in })
            return .init(operation, outcome.stepStatus, outcome.summary, cleanupResults: outcome.results)
        }
        if operation == .uninstall, request.uninstallPlan?.executionLevel == .interactive {
            return .init(operation, .waitingForUser, "Simulated interactive handoff. " + UninstallOutcome.waitingForUser.completionMessage)
        }
        return .init(operation, .completed, "Simulated \(operation.rawValue); nothing changed.")
    }
}
private struct SimulatedCleanupPresence: AppDataPresenceChecking {
    let missing: String?
    func presence(_ path: String) -> AppDataPresence { path == missing ? .missing : NativeAppDataPresenceChecker().presence(path) }
}
public enum ManagementValidation {
    public static func validateSelection(_ request: ManagementRequest) throws {
        guard !request.operations.isEmpty else { throw ScanError.process("Select an eligible operation.") }
        if request.operations.contains(.forceQuit) {
            guard request.item != nil, request.target != nil else { throw ScanError.process("No safely identified running process was reviewed.") }
        }
        if request.operations.contains(.clearData) {
            guard !request.candidates.isEmpty else { throw ScanError.process("Select data locations before confirming.") }
            if request.operations == [.clearData] { try AppDataSafety.validateStructure(request.candidates) }
            else {
                try AppDataSafety.validateStructure(request.candidates)
                let remaining = request.candidates.filter { NativeAppDataPresenceChecker().presence($0.path) != .missing }
                try AppDataSafety.validateSelection(remaining)
            }
        }
        if request.operations.contains(.uninstall), request.uninstallPlan?.canExecute != true { throw ScanError.process("This application does not have an eligible uninstall plan.") }
    }
}
