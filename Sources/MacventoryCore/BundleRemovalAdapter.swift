import Foundation
import AppKit

public protocol BundleTrashOperating: Sendable {
    func recycle(_ plan: UninstallPlan) async throws
}
public struct NativeBundleTrashOperation: BundleTrashOperating {
    public init() {}
    @MainActor public func recycle(_ plan: UninstallPlan) async throws {
        guard let path = plan.item.path, let proof = plan.standaloneEligibility, !proof.simulated,
              proof.roots == StandaloneRemovalChecker.allowedRoots(configuration: proof.configuration),
              try StandaloneRemovalChecker.inspect(plan.item, roots: proof.roots) == plan.fingerprint,
              !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleURL.map { FileSystem.contained($0.path, in: path) } == true }) else { throw ScanError.process("Bundle identity, ownership, scope or running state changed") }
        try await NativeTrashRequest.recycle(URL(fileURLWithPath: path))
    }
}
public struct BundleRemovalAdapter: UninstallExecuting {
    public let checker: any StandaloneRemovalChecking
    public let trash: any BundleTrashOperating
    public init(checker: any StandaloneRemovalChecking, trash: any BundleTrashOperating = NativeBundleTrashOperation()) { self.checker = checker; self.trash = trash }
    public func execute(_ plan: UninstallPlan) async throws -> UninstallOutcome {
        guard plan.method == .trashBundle, let path = plan.item.path, (0..<300).contains(Date().timeIntervalSince(plan.createdAt)) else { throw ScanError.process("Invalid bundle removal preview") }
        let fresh = try await checker.check(plan.item)
        guard fresh.fingerprint == plan.fingerprint, fresh.roots == plan.standaloneEligibility?.roots else { throw ScanError.process("Bundle or removal scope changed") }
        try Task.checkCancellation()
        try await trash.recycle(plan)
        switch ArtifactObservation.inspect(path).presence {
        case .missing: return .appBundleRemoved
        case .present, .brokenLink: return .partialRemoval
        case .inaccessible: return .unknownResult
        }
    }
}
