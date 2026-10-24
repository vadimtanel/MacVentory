import Foundation

public protocol VendorUninstallerFinding: Sendable {
    func find(for item: SoftwareItem) async -> VendorUninstallerCandidate?
}
public struct LocalVendorUninstallerFinder: VendorUninstallerFinding {
    public init() {}
    public func find(for item: SoftwareItem) async -> VendorUninstallerCandidate? {
        await Task.detached(priority: .utility) { VendorUninstallerDiscovery.discover(for: item) }.value
    }
}
/// One capability resolver for every presentation. The first eligible, most complete
/// verified strategy wins; execution failure never invokes this resolver as a fallback.
public struct UninstallPreparationService: Sendable {
    public let manager: ManagedRemovalAdapter
    public let steam: SteamRemovalAdapter
    public let bundles: any StandaloneRemovalChecking
    public let vendors: any VendorUninstallerFinding
    public let queries: any CommandRunning
    public init(configuration: ScanConfiguration = ScanConfiguration(), manager: ManagedRemovalAdapter = ManagedRemovalAdapter(), steam: SteamRemovalAdapter = SteamRemovalAdapter(), bundles: (any StandaloneRemovalChecking)? = nil, vendors: any VendorUninstallerFinding = LocalVendorUninstallerFinder(), queries: any CommandRunning = ProcessRunner()) {
        self.manager = manager; self.steam = steam; self.bundles = bundles ?? StandaloneRemovalChecker(configuration: configuration); self.vendors = vendors; self.queries = queries
    }
    public func prepare(_ item: SoftwareItem, running: Bool = false) async -> UninstallPlan {
        let base = UninstallPlanner.plan(for: item, running: running)
        guard !base.isBlocked else { return base }
        do {
            if [.macPorts, .nix].contains(item.primarySource) {
                return UninstallPlanner.plan(for: item, running: running, manager: try await manager.prepare(item))
            }
            if item.primarySource == .steam { return UninstallPlanner.plan(for: item, running: running, interactive: try steam.prepare(item)) }
            if [.pkg, .unmanaged].contains(item.primarySource) {
                if let vendor = await vendors.find(for: item) { return UninstallPlanner.plan(for: item, running: running, vendor: vendor) }
            }
            if [.unmanaged, .appStore, .pkg].contains(item.primarySource), item.path?.hasSuffix(".app") == true {
                return UninstallPlanner.plan(for: item, running: running, standaloneEligibility: try await bundles.check(item))
            }
            if item.primarySource == .homebrewFormula, base.canExecute, let executable = base.executable, let token = item.packageID {
                let dependents = try await queries.run(.brewDependents(executable: executable, token: token))
                guard String(decoding: dependents, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ScanError.process("Installed dependents require this formula; they will not be removed automatically.") }
                try HomebrewServiceReview.validate(try await queries.run(.brewServices(executable: executable)), token: token)
            }
            return base
        } catch {
            return UninstallPlanner.guided(for: item, reason: error.localizedDescription + " " + SourceRemovalGuide.forItem(item).instructions)
        }
    }
}
public enum HomebrewServiceReview {
    public static func validate(_ data: Data, token: String) throws {
        guard let records = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw ScanError.malformed("Homebrew service state is unverified; review the formula in Homebrew") }
        for record in records where record["name"] as? String == token {
            let running = record["running"] as? Bool == true || record["loaded"] as? Bool == true
            let status = record["status"] as? String
            guard !running, status == "none" || status == "stopped" else { throw ScanError.process("This formula has a loaded/running or unverified service. Stop and review the exact service yourself before a new uninstall preview.") }
        }
    }
}
