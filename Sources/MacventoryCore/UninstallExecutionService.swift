import Foundation

/// Dispatch exactly the confirmed mechanism once. There is deliberately no catch-and-
/// fallback path; switching mechanisms requires a fresh preview and confirmation.
public struct UninstallExecutionService: UninstallExecuting {
    public let validator: any UninstallValidating
    public let homebrew: any UninstallExecuting
    public let managed: any UninstallExecuting
    public let bundles: (any UninstallExecuting)?
    public let vendor: any UninstallExecuting
    public let steam: any UninstallExecuting
    public init(validator: any UninstallValidating = FreshUninstallValidator(), homebrew: any UninstallExecuting = HomebrewRemovalAdapter(operation: LiveHomebrewOperation()), managed: any UninstallExecuting = ManagedRemovalAdapter(), bundles: (any UninstallExecuting)? = nil, vendor: any UninstallExecuting = VendorRemovalAdapter(), steam: any UninstallExecuting = SteamRemovalAdapter()) {
        self.validator = validator; self.homebrew = homebrew; self.managed = managed; self.bundles = bundles; self.vendor = vendor; self.steam = steam
    }
    public func execute(_ plan: UninstallPlan) async throws -> UninstallOutcome {
        guard plan.canExecute else { throw ScanError.process("Guided and blocked previews do not execute removal") }
        try await validator.validate(plan)
        try Task.checkCancellation()
        switch plan.method {
        case .homebrewCask, .homebrewFormula: return try await homebrew.execute(plan)
        case .macPorts, .nixProfile: return try await managed.execute(plan)
        case .trashBundle:
            let adapter = bundles ?? BundleRemovalAdapter(checker: StandaloneRemovalChecker(configuration: plan.standaloneEligibility?.configuration ?? ScanConfiguration()))
            return try await adapter.execute(plan)
        case .vendorTool: return try await vendor.execute(plan)
        case .steamInteractive: return try await steam.execute(plan)
        case .external, .blocked: throw ScanError.process("No executable removal mechanism")
        }
    }
}
