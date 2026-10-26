import Foundation
import CryptoKit
import AppKit
import Darwin

public enum UninstallMethod: String, Sendable { case homebrewCask, homebrewFormula, macPorts, nixProfile, vendorTool, steamInteractive, trashBundle, external, blocked }
public struct UninstallPlan: Sendable, Identifiable {
    public let id: UUID
    public let item: SoftwareItem
    public let method: UninstallMethod
    public let explanation: String
    public let executable: String?
    public let arguments: [String]
    public let fingerprint: String?
    let standaloneEligibility: StandaloneEligibility?
    public let managerEvidence: ManagedRemovalEvidence?
    public let interactiveEvidence: InteractiveRemovalEvidence?
    public let createdAt: Date
    init(id: UUID, item: SoftwareItem, method: UninstallMethod, explanation: String, executable: String?, arguments: [String], fingerprint: String?, standaloneEligibility: StandaloneEligibility?, createdAt: Date, managerEvidence: ManagedRemovalEvidence? = nil, interactiveEvidence: InteractiveRemovalEvidence? = nil) {
        self.id = id; self.item = item; self.method = method; self.explanation = explanation; self.executable = executable; self.arguments = arguments; self.fingerprint = fingerprint; self.standaloneEligibility = standaloneEligibility; self.createdAt = createdAt; self.managerEvidence = managerEvidence; self.interactiveEvidence = interactiveEvidence
    }
    public var canExecute: Bool { [.homebrewCask, .homebrewFormula, .macPorts, .nixProfile, .vendorTool, .steamInteractive, .trashBundle].contains(method) }
    public var actionTitle: String {
        if method == .trashBundle { return "Move to Trash" }
        if method == .macPorts { return "Uninstall with MacPorts" }
        if method == .nixProfile { return "Remove from Nix Profile" }
        if method == .steamInteractive { return "Open Steam Uninstall" }
        if method == .vendorTool { return "Uninstall with Vendor Tool" }
        if method == .homebrewCask && item.installationHealth.status == .attention { return "Remove Orphaned Installation" }
        return [.homebrewCask, .homebrewFormula].contains(method) ? "Uninstall with Homebrew" : "Review Removal Instructions"
    }
    public var acknowledgment: String { method == .trashBundle ? "I reviewed the application and want to move it to Trash." : "I reviewed the application and want to uninstall it." }
    public var operation: String {
        switch method {
        case .homebrewCask: "Macventory will ask this Homebrew installation to uninstall the whole cask and all listed app, font or owned-link artifacts. Retain user data and dependencies; no force, zap or cleanup."
        case .homebrewFormula: "Remove the exact formula with Homebrew after checking installed dependents. Other versions, dependencies and user data are not cleaned."
        case .macPorts: "Macventory will uninstall the exact reviewed port/version/variants using MacPorts. Installed dependents block removal. MacPorts may run its stored uninstall procedures; known service/extension payloads require separate review. macOS authorization may be required."
        case .nixProfile: "Macventory will remove the exact element from this mutable Nix profile; store paths and other generations remain."
        case .steamInteractive: "Macventory will open Steam’s official uninstall confirmation for this exact App ID. You complete Steam’s review; no game files are deleted by Macventory."
        case .vendorTool: "Open the verified vendor uninstaller. Complete its interactive review and authorization yourself, then refresh installation status."
        case .trashBundle: "Macventory will move only this bundle to recoverable Trash using Finder. macOS may request authorization. External components and user data may remain; this is limited bundle removal."
        case .external: "Use the source's application or vendor uninstaller."
        case .blocked: "Removal is blocked."
        }
    }
}
public enum UninstallPlanner {
    public static func plan(for item: SoftwareItem, running: Bool = false, now: Date = Date(), standaloneEligibility: StandaloneEligibility? = nil, vendor: VendorUninstallerCandidate? = nil, manager: ManagedRemovalEvidence? = nil, interactive: InteractiveRemovalEvidence? = nil) -> UninstallPlan {
        func result(_ method: UninstallMethod, _ reason: String, executable: String? = nil, arguments: [String] = [], fingerprint: String? = nil) -> UninstallPlan {
            UninstallPlan(id: UUID(), item: item, method: method, explanation: reason, executable: executable, arguments: arguments, fingerprint: fingerprint, standaloneEligibility: standaloneEligibility, createdAt: now, managerEvidence: manager, interactiveEvidence: interactive)
        }
        guard item.attributes["Demonstration"] != "Synthetic" else { return result(.blocked, "Demonstration records are never uninstall targets.") }
        guard !item.isSystem, !ProtectionPolicy.protectedPath(item.path) else { return result(.blocked, "Protected system applications cannot be removed here.") }
        let expectedPaths = item.health?.artifacts.map(\.path) ?? item.path.map { [$0] } ?? []
        guard !ProtectionPolicy.isRunningCopy(expectedPaths + [item.path].compactMap { $0 }) else { return result(.blocked, "This operation could remove the currently running Macventory bundle. Quit Macventory and use its manager externally; no in-process self-uninstall is allowed.") }
        guard !running else { return result(.blocked, "Quit this application yourself before preparing removal. Macventory will not force it to quit.") }
        guard !item.stale, now.timeIntervalSince(item.scannedAt) >= -300, now.timeIntervalSince(item.scannedAt) <= 600 else { return result(.blocked, "Refresh the inventory first; cached or older ownership cannot authorize removal.") }
        guard item.primarySource != .unknown, !item.sources.contains(where: { $0.source == .unknown }) else { return result(.blocked, "Ownership is ambiguous or incomplete.") }
        let managed = Set(item.sources.filter { [.homebrewCask, .homebrewFormula, .macPorts, .nix, .setapp, .steam, .toolbox].contains($0.source) }.map(\.source))
        guard managed.count <= 1 else { return result(.blocked, "Multiple managers claim this installation.") }
        if let manager, manager.itemID == item.id, (0..<300).contains(now.timeIntervalSince(manager.preparedAt)) {
            switch manager.target {
            case .macPorts where item.primarySource == .macPorts:
                return result(.macPorts, "Exact installed port/version/variants and dependents reviewed. " + (manager.requiresAuthorization ? "The signed Macventory helper requires explicit macOS approval. Approval registers a background helper for future reviewed MacPorts operations; permission can be revoked in Login Items. No uninstall is queued before approval." : "This manager prefix is writable without elevation."), executable: manager.executable, arguments: manager.arguments, fingerprint: manager.stateFingerprint)
            case .nix where item.primarySource == .nix:
                return result(.nixProfile, "Exact named element, Nix version and user-owned mutable profile verified. No declarative configuration, store paths or other profiles are changed.", executable: manager.executable, arguments: manager.arguments, fingerprint: manager.stateFingerprint)
            default: return result(.blocked, "Manager evidence does not match the selected source.")
            }
        }
        if let interactive, item.primarySource == .steam, interactive.appID == item.packageID {
            return result(.steamInteractive, "Verified Steam App ID, library manifest, installed client identity and documented targeted uninstall URI. Steam will ask you to complete its own confirmation.", executable: interactive.application, fingerprint: interactive.fingerprint)
        }
        // Manager-level eligibility deliberately precedes bundle-only eligibility.
        if item.primarySource == .homebrewFormula {
            guard let token = item.packageID, validToken(token), let executable = item.attributes["Homebrew executable"],
                  let path = item.path, let version = item.version,
                  path == String(executable.dropLast("/bin/brew".count)) + "/Cellar/" + token + "/" + version,
                  item.health?.registration == .installed else { return result(.external, "Refresh the exact formula, keg version and Homebrew prefix. Review installed dependents in Homebrew before removal.") }
            do {
                guard executable.hasSuffix("/bin/brew"), FileManager.default.isExecutableFile(atPath: executable) else { throw ScanError.process("Homebrew executable unavailable") }
                return result(.homebrewFormula, "Fresh preflight will verify this exact installed version and reject installed dependents. No dependency override, autoremove, force or garbage collection.", executable: executable, arguments: ["uninstall", "--formula", "--", token], fingerprint: try fingerprint(item))
            } catch { return result(.blocked, error.localizedDescription) }
        }
        if item.primarySource == .homebrewCask {
            do {
                guard let token = item.packageID, validToken(token), let receiptPath = item.attributes["Homebrew receipt"],
                      let executable = item.attributes["Homebrew executable"], executable.hasSuffix("/bin/brew") else { return result(.external, "The exact cask token, installed receipt and manager executable are required. Refresh, then review this installation in Homebrew.") }
                let prefix = String(executable.dropLast("/bin/brew".count))
                guard receiptPath == prefix + "/Caskroom/" + token + "/.metadata/INSTALL_RECEIPT.json", FileManager.default.isExecutableFile(atPath: executable) else { return result(.blocked, "The manager executable or receipt location changed.") }
                guard !ProtectionPolicy.isRunningCopy(HomebrewTrust.caskRemovalScope(executable: executable, token: token, artifacts: [])) else { return result(.blocked, "The cask's staged payload contains this running Macventory copy. Use an external manager after quitting.") }
                if let state = item.health?.registration, state != .installed { return result(.external, "Homebrew has not verified this exact token installed. Refresh Installation Status; historical metadata alone cannot authorize removal.") }
                let receipt = try FileSystem.json(receiptPath)
                guard CaskEffectReview.allowsAutomation(receipt, item: item) else {
                    return result(.external, CaskEffectReview.describe(receipt) + " Review and run the official Homebrew workflow externally. Macventory does not execute unaudited hooks or collect administrator passwords.")
                }
                let config = try FileSystem.json((receiptPath as NSString).deletingLastPathComponent + "/config.json")
                let mappings = try CaskMappedArtifact.read(receipt: receipt, config: config, root: prefix + "/Caskroom/" + token)
                guard !mappings.isEmpty, item.path == nil || mappings.contains(where: { FileSystem.canonical($0.path) == item.path }) else { return result(.external, "The complete cask artifact scope cannot be established. No filesystem fallback will be substituted.") }
                guard mappings.map(\.path).sorted() == (item.health?.artifacts.map(\.path) ?? []).sorted(),
                      mappings.map({ ArtifactObservation.inspect($0.path) }).sorted(by: { $0.path < $1.path }) == (item.health?.artifacts ?? []).sorted(by: { $0.path < $1.path }) else {
                    return result(.blocked, "The cask artifact targets changed since discovery. Refresh the inventory and review a new plan.")
                }
                let ownedApps = mappings.filter { $0.kind == "app" }.map(\.path)
                for mapping in mappings { try mapping.validateForRemoval(ownedAppRoots: ownedApps) }
                return result(.homebrewCask, (CaskEffectReview.hasQuitDirective(receipt) ? "Official quit directive is restricted to this bundle identifier; no matching copy may be running. " : "") + "Exact declarative cask artifact mappings verified. Homebrew may refuse a missing artifact; failure is reported with guided recovery and never retried with force. User data and dependencies remain.", executable: executable, arguments: ["uninstall", "--cask", "--", token], fingerprint: try fingerprint(item))
            } catch { return result(.blocked, "Cannot validate removal evidence: " + error.localizedDescription) }
        }
        if ![.unmanaged, .appStore, .pkg].contains(item.primarySource) {
            return result(.external, SourceRemovalGuide.forItem(item).instructions)
        }
        guard item.kind == .app || item.kind == .game, let path = item.path, path.hasSuffix(".app"),
              path == FileSystem.canonical(path), !path.hasPrefix("/Library/"), !path.hasPrefix("/nix/"),
              !path.contains(".app/"), FileSystem.exists(path + "/Contents/Info.plist") else { return result(.external, SourceRemovalGuide.forItem(item).instructions) }
        if let vendor, [.pkg, .unmanaged].contains(item.primarySource) {
            return result(.vendorTool, "Verified vendor signing team: " + vendor.team + ". Review the interactive tool's full scope yourself; it may affect shared components or user data. Launching it does not prove removal.", executable: vendor.path, fingerprint: vendor.fingerprint)
        }
        if [InstallSource.unmanaged, .appStore, .pkg].contains(item.primarySource), item.sources.allSatisfy({ [.unmanaged, .appStore, .pkg].contains($0.source) }), item.primarySource != .pkg || standaloneEligibility != nil {
            guard let eligibility = standaloneEligibility else { return result(.external, "Checking standalone eligibility is required. Inferred source alone cannot authorize Trash.") }
            do {
                guard try StandaloneRemovalChecker.inspect(item, roots: eligibility.roots, signatures: eligibility.signatureChecker) == eligibility.fingerprint else { return result(.blocked, "The bundle changed. Prepare a new preview.") }
                return result(.trashBundle, eligibility.simulated ? "Synthetic standalone fixture validated for simulation. No live ownership audit or installed software was used." : "Standalone bundle checks and a fresh ownership audit found no supported manager claim. Move only this bundle to recoverable Trash; this is not a complete uninstall.", fingerprint: eligibility.fingerprint)
            } catch { return result(.blocked, error.localizedDescription) }
        }
        guard item.confidence == .verified else { return result(.external, "The source is inferred, not verified. Removal must be reviewed in the vendor or source application; Macventory cannot safely select a mechanism.") }
        return result(.external, SourceRemovalGuide.forItem(item).instructions)
    }
    public static func guided(for item: SoftwareItem, reason: String, now: Date = Date()) -> UninstallPlan {
        let base = plan(for: item, now: now)
        guard !base.isBlocked else { return base }
        return UninstallPlan(id: UUID(), item: item, method: .external, explanation: reason, executable: nil, arguments: [], fingerprint: nil, standaloneEligibility: nil, createdAt: now)
    }
    public static func validToken(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 200 && value.first.map { $0.isLetter || $0.isNumber } == true && value.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789@+._-").contains($0) } && !value.contains("..")
    }
    public static func fingerprint(_ item: SoftwareItem) throws -> String {
        if [.homebrewCask, .homebrewFormula].contains(item.primarySource) {
            guard let receipt = item.attributes["Homebrew receipt"], let executable = item.attributes["Homebrew executable"] else { throw ScanError.malformed("Missing manager evidence") }
            var evidence = Data((receipt + "|" + executable + "|" + (item.packageID ?? "")).utf8)
            let files = [receipt] + (item.primarySource == .homebrewCask ? [(receipt as NSString).deletingLastPathComponent + "/config.json"] : [])
            for path in files {
                let attributes = try FileManager.default.attributesOfItem(atPath: path)
                guard attributes[.type] as? FileAttributeType == .typeRegular, FileSystem.canonical(path) == path,
                      (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 4 * 1024 * 1024 else { throw ScanError.process("Manager evidence is linked or exceeds limits") }
                evidence.append(try Data(contentsOf: URL(fileURLWithPath: path)))
            }
            evidence.append(Data(try HomebrewTrust.executableFingerprint(executable).utf8))
            for artifact in item.health?.artifacts ?? item.path.map({ [ArtifactObservation.inspect($0)] }) ?? [] {
                let observation = ArtifactObservation.inspect(artifact.path)
                evidence.append(Data((observation.path + "|" + observation.presence.rawValue).utf8))
                if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: artifact.path) { evidence.append(Data(("|link=" + destination).utf8)) }
                if observation.presence == .present {
                    let a = try FileManager.default.attributesOfItem(atPath: artifact.path)
                    evidence.append(Data("|\(a[.systemFileNumber] ?? "")|\(a[.modificationDate] ?? "")".utf8))
                    if artifact.path.hasSuffix(".app") {
                        let info = artifact.path + "/Contents/Info.plist"
                        let attributes = try FileManager.default.attributesOfItem(atPath: info)
                        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 4 * 1024 * 1024, FileSystem.canonical(info) == info else { throw ScanError.process("Application metadata is linked or too large") }
                        evidence.append(try Data(contentsOf: URL(fileURLWithPath: info)))
                    }
                }
            }
            return SHA256.hash(data: evidence).map { String(format: "%02x", $0) }.joined()
        }
        guard let path = item.path else { throw ScanError.malformed("Missing target") }
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        func boundedData(_ url: URL) throws -> Data {
            let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
            let bytes = try handle.read(upToCount: 16 * 1024 * 1024 + 1) ?? Data()
            guard bytes.count <= 16 * 1024 * 1024 else { throw ScanError.limit("Removal evidence exceeds size limit") }
            return bytes
        }
        var data = Data("\(path)|\(attributes[.systemNumber] ?? "")|\(attributes[.systemFileNumber] ?? "")".utf8)
        data.append(try boundedData(URL(fileURLWithPath: path + "/Contents/Info.plist")))
        if let receipt = item.attributes["Homebrew receipt"] {
            data.append(try boundedData(URL(fileURLWithPath: receipt)))
            data.append(try boundedData(URL(fileURLWithPath: receipt).deletingLastPathComponent().appendingPathComponent("config.json")))
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public enum UninstallOutcome: String, Sendable {
    case authorizationRequired, simulated, completed, verifiedRemoved, packageRegistrationRemoved, appBundleRemoved, remainingDataFound, waitingForUser, partialRemoval, alreadyAbsent, blocked, failed, unknownResult
    public var completionMessage: String {
        switch self {
        case .authorizationRequired: "Approve the signed Macventory helper in macOS Login Items, then return and prepare a fresh preview. No uninstall was submitted before approval."
        case .completed: "Operation completed.\nRefresh the inventory to verify the remaining installation state."
        case .simulated: "Simulation completed. Nothing was removed or modified."
        case .verifiedRemoved: "The selected manager registration and expected artifacts are verified removed. User data was retained; review Leftover Data separately."
        case .packageRegistrationRemoved: "The exact package registration is verified removed. Other artifacts or user data may remain."
        case .appBundleRemoved: "The selected app bundle is verified absent. This was limited bundle removal; external components and user data may remain."
        case .remainingDataFound: "Known data remains. Review it separately; nothing was automatically cleaned."
        case .waitingForUser: "Waiting for you to complete the external workflow. Refresh Installation Status afterwards; launching a tool does not prove removal."
        case .partialRemoval: "Removal is partial: the manager registration or expected artifacts remain. Refresh and review the official manager instructions; no force or automatic retry was used."
        case .alreadyAbsent: "The selected installation was already absent."
        case .blocked: "Removal was blocked by fresh validation."
        case .failed: "The operation failed. It may have applied some changes; refresh before another review."
        case .unknownResult: "The resulting installation state could not be verified. Refresh before taking further action."
        }
    }
}
public protocol UninstallExecuting: Sendable { func execute(_ plan: UninstallPlan) async throws -> UninstallOutcome }
public protocol UninstallValidating: Sendable { func validate(_ plan: UninstallPlan) async throws }
public struct FreshUninstallValidator: UninstallValidating {
    private let standaloneChecker: (any StandaloneRemovalChecking)?
    private let allowRunningDuringPreflight: Bool
    public init(standaloneChecker: (any StandaloneRemovalChecking)? = nil, allowRunningDuringPreflight: Bool = false) { self.standaloneChecker = standaloneChecker; self.allowRunningDuringPreflight = allowRunningDuringPreflight }
    public func validate(_ plan: UninstallPlan) async throws {
        try Task.checkCancellation()
        guard plan.canExecute, !plan.item.stale, (-300...600).contains(Date().timeIntervalSince(plan.item.scannedAt)), (0..<300).contains(Date().timeIntervalSince(plan.createdAt)) else { throw ScanError.process("Removal preview expired. Prepare a fresh review.") }
        if [.macPorts, .nixProfile].contains(plan.method) { try await ManagedRemovalAdapter().validate(plan); return }
        if plan.method == .steamInteractive { try SteamRemovalAdapter().validate(plan); return }
        var eligibility: StandaloneEligibility?
        if plan.method == .trashBundle {
            let checker = standaloneChecker ?? StandaloneRemovalChecker(configuration: plan.standaloneEligibility?.configuration ?? ScanConfiguration())
            eligibility = try await checker.check(plan.item)
        }
        if [.homebrewCask, .homebrewFormula].contains(plan.method) {
            guard let executable = plan.executable, let token = plan.item.packageID else { throw ScanError.process("Missing manager identity") }
            try HomebrewTrust.validateExecutable(executable)
            let versions = try HomebrewScanner.installedTokens(try await ProcessRunner().run(.brewInstalled(executable: executable, cask: plan.method == .homebrewCask)))
            let expectedVersion = HomebrewRemovalAdapter.expectedVersion(for: plan.item)
            guard let installed = versions[token], expectedVersion == nil || installed.contains(expectedVersion!) else { throw ScanError.process("Homebrew installation state or version changed. Refresh first.") }
            if plan.method == .homebrewCask, let receiptPath = plan.item.attributes["Homebrew receipt"], CaskEffectReview.hasQuitDirective(try FileSystem.json(receiptPath)) {
                let matchingCopy = await MainActor.run { NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == plan.item.bundleID } }
                guard !matchingCopy else { throw ScanError.process("Homebrew's quit directive could affect another running copy. Quit all matching copies yourself, then prepare a fresh review.") }
            }
            if plan.method == .homebrewFormula { try HomebrewServiceReview.validate(try await ProcessRunner().run(.brewServices(executable: executable)), token: token) }
            var paths = plan.item.health?.artifacts.map(\.path) ?? plan.item.path.map { [$0] } ?? []
            if plan.method == .homebrewCask { paths = HomebrewTrust.caskRemovalScope(executable: executable, token: token, artifacts: paths) }
            guard !ProtectionPolicy.isRunningCopy(paths) else { throw ScanError.process("The operation affects the running Macventory copy; use external manager removal after quitting.") }
            let runningArtifact = await MainActor.run { NSWorkspace.shared.runningApplications.contains { app in
                app.bundleURL.map { url in paths.contains { FileSystem.contained(url.path, in: $0) } } == true
            } }
            guard !runningArtifact || allowRunningDuringPreflight else { throw ScanError.process("An owned application is running. Quit it and prepare a new review.") }
        }
        if plan.method == .vendorTool {
            let vendorTargetRunning = await MainActor.run { NSWorkspace.shared.runningApplications.contains { app in
                guard let path = plan.item.path, let url = app.bundleURL else { return false }
                return FileSystem.contained(url.path, in: path)
            } }
            guard !vendorTargetRunning || allowRunningDuringPreflight else { throw ScanError.process("Quit the selected application before launching its uninstaller") }
            guard let candidate = VendorUninstallerDiscovery.discover(for: plan.item), candidate.path == plan.executable, candidate.fingerprint == plan.fingerprint else { throw ScanError.process("Vendor uninstaller identity changed") }
            return
        }
        let running = await MainActor.run { NSWorkspace.shared.runningApplications.contains { app in
            guard let path = plan.item.path, let url = app.bundleURL else { return false }
            return FileSystem.contained(url.path, in: path)
        } }
        let fresh = UninstallPlanner.plan(for: plan.item, running: running && !allowRunningDuringPreflight, standaloneEligibility: eligibility)
        guard plan.canExecute, Date().timeIntervalSince(plan.createdAt) < 300,
              fresh.method == plan.method, fresh.arguments == plan.arguments, fresh.executable == plan.executable,
              fresh.fingerprint == plan.fingerprint else { throw ScanError.process("Application, ownership or removal plan changed. Refresh and prepare a new confirmation.") }
    }
}
public struct SimulatedUninstallExecutor: UninstallExecuting {
    public init() {}
    public func execute(_ plan: UninstallPlan) async throws -> UninstallOutcome {
        try Task.checkCancellation()
        guard plan.canExecute else { throw ScanError.process("Unsupported plan") }
        return .simulated
    }
}
public actor UninstallSession {
    private let executor: any UninstallExecuting
    private let validator: any UninstallValidating
    private var pending: UninstallPlan?
    private var executing = false
    public init(executor: any UninstallExecuting, validator: any UninstallValidating = FreshUninstallValidator()) { self.executor = executor; self.validator = validator }
    public func prepare(_ plan: UninstallPlan) { if !executing { pending = plan } }
    public func cancel() { pending = nil }
    public func confirm(id: UUID, acknowledged: Bool) async throws -> UninstallOutcome {
        guard !executing, acknowledged, let plan = pending, plan.id == id, plan.canExecute else { throw ScanError.process("Review and confirm this exact removal plan before continuing.") }
        executing = true
        defer { executing = false }
        pending = nil // Confirmation is single use, including failures and cancellation.
        try Task.checkCancellation()
        try await validator.validate(plan)
        try Task.checkCancellation()
        return try await executor.execute(plan)
    }
}

/// Production adapter. Development/QA must inject SimulatedUninstallExecutor instead.
/// No test invokes this adapter; actual destructive verification is explicitly pending.
public struct LiveUninstallExecutor: UninstallExecuting {
    public init() {}
    public func execute(_ plan: UninstallPlan) async throws -> UninstallOutcome {
        try await UninstallExecutionService().execute(plan)
    }
}

/// UI acknowledgment belongs to one immutable preview plan, never a reusable target name.
public struct UninstallReviewState: Sendable {
    public private(set) var planID: UUID
    public var acknowledged = false
    public init(planID: UUID) { self.planID = planID }
    public mutating func reset(for planID: UUID) { self = Self(planID: planID) }
}
