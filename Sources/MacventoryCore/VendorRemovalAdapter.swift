import Foundation

public protocol VendorToolOpening: Sendable {
    func open(_ candidate: VendorUninstallerCandidate, for item: SoftwareItem) async throws
}
public struct NativeVendorToolOpening: VendorToolOpening {
    public init() {}
    public func open(_ candidate: VendorUninstallerCandidate, for item: SoftwareItem) async throws {
        try await VendorUninstallerDiscovery.launch(candidate.path, for: item, fingerprint: candidate.fingerprint)
    }
}
public struct VendorRemovalAdapter: UninstallExecuting {
    public let finder: any VendorUninstallerFinding
    public let opener: any VendorToolOpening
    public init(finder: any VendorUninstallerFinding = LocalVendorUninstallerFinder(), opener: any VendorToolOpening = NativeVendorToolOpening()) { self.finder = finder; self.opener = opener }
    public func validate(_ plan: UninstallPlan) async throws -> VendorUninstallerCandidate {
        guard plan.method == .vendorTool, !plan.item.stale, (0..<300).contains(Date().timeIntervalSince(plan.createdAt)),
              let candidate = await finder.find(for: plan.item), candidate.path == plan.executable, candidate.fingerprint == plan.fingerprint else { throw ScanError.process("Vendor identity or target changed. Prepare a new review.") }
        return candidate
    }
    public func execute(_ plan: UninstallPlan) async throws -> UninstallOutcome {
        let candidate = try await validate(plan)
        try Task.checkCancellation()
        try await opener.open(candidate, for: plan.item)
        return .waitingForUser
    }
}
