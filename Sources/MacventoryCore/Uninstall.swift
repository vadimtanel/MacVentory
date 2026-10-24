import Foundation
import CryptoKit
import AppKit
import Darwin

public enum UninstallMethod: String, Sendable { case homebrewCask, trashBundle, external, blocked }
public struct UninstallPlan: Sendable, Identifiable {
    public let id: UUID
    public let item: SoftwareItem
    public let method: UninstallMethod
    public let explanation: String
    public let executable: String?
    public let arguments: [String]
    public let fingerprint: String?
    let standaloneEligibility: StandaloneEligibility?
    public let createdAt: Date
    public var canExecute: Bool { method == .homebrewCask || method == .trashBundle }
    public var actionTitle: String { method == .trashBundle ? "Move to Trash" : method == .homebrewCask ? "Homebrew Uninstall" : "Uninstall" }
    public var acknowledgment: String { method == .trashBundle ? "I reviewed the application and want to move it to Trash." : "I reviewed the application and want to uninstall it." }
    public var operation: String {
        switch method {
        case .homebrewCask: "Remove only this app-only Homebrew cask; retain user data and dependencies."
        case .trashBundle: "Move only this app bundle to Trash. This is not a complete uninstall; external components and user data remain."
        case .external: "Use the source's application or vendor uninstaller."
        case .blocked: "Removal is blocked."
        }
    }
}
public enum UninstallPlanner {
    public static func plan(for item: SoftwareItem, running: Bool = false, now: Date = Date(), standaloneEligibility: StandaloneEligibility? = nil) -> UninstallPlan {
        func result(_ method: UninstallMethod, _ reason: String, executable: String? = nil, arguments: [String] = [], fingerprint: String? = nil) -> UninstallPlan {
            UninstallPlan(id: UUID(), item: item, method: method, explanation: reason, executable: executable, arguments: arguments, fingerprint: fingerprint, standaloneEligibility: standaloneEligibility, createdAt: now)
        }
        guard item.attributes["Demonstration"] != "Synthetic" else { return result(.blocked, "Demonstration records are never uninstall targets.") }
        guard !item.isSystem, item.bundleID?.hasPrefix("com.apple.") != true,
              item.bundleID != "org.vadimtanel.Macventory" else { return result(.blocked, "System components and Macventory itself are protected.") }
        guard item.kind == .app || item.kind == .game, let path = item.path, path.hasSuffix(".app"),
              path == FileSystem.canonical(path), !path.hasPrefix("/System/"), !path.hasPrefix("/Library/"), !path.hasPrefix("/usr/"), !path.hasPrefix("/nix/"),
              !path.contains(".app/"), FileSystem.exists(path + "/Contents/Info.plist") else { return result(.blocked, "Only an existing top-level application bundle can be considered. Packages and embedded helpers require their manager.") }
        guard !running else { return result(.blocked, "Quit this application yourself before preparing removal. Macventory will not force it to quit.") }
        guard !item.stale, now.timeIntervalSince(item.scannedAt) >= -300, now.timeIntervalSince(item.scannedAt) <= 600 else { return result(.blocked, "Refresh the inventory first; cached or older ownership cannot authorize removal.") }
        guard item.primarySource != .unknown, !item.sources.contains(where: { $0.source == .unknown }) else { return result(.blocked, "Ownership is ambiguous or incomplete.") }
        let managed = Set(item.sources.filter { [.homebrewCask, .homebrewFormula, .macPorts, .nix, .setapp, .steam, .toolbox].contains($0.source) }.map(\.source))
        guard managed.count <= 1 else { return result(.blocked, "Multiple managers claim this installation.") }
        if item.primarySource == .unmanaged, item.sources.allSatisfy({ $0.source == .unmanaged }) {
            guard let eligibility = standaloneEligibility else { return result(.external, "Checking standalone eligibility is required. Inferred source alone cannot authorize Trash.") }
            do {
                guard try StandaloneRemovalChecker.inspect(item, roots: eligibility.roots) == eligibility.fingerprint else { return result(.blocked, "The bundle changed. Prepare a new preview.") }
                return result(.trashBundle, eligibility.simulated ? "Synthetic standalone fixture validated for simulation. No live ownership audit or installed software was used." : "Standalone bundle checks and a fresh ownership audit found no supported manager claim. Move only this bundle to recoverable Trash; this is not a complete uninstall.", fingerprint: eligibility.fingerprint)
            } catch { return result(.blocked, error.localizedDescription) }
        }
        guard item.confidence == .verified else { return result(.external, "The source is inferred, not verified. Removal must be reviewed in the vendor or source application; Macventory cannot safely select a mechanism.") }
        if item.primarySource == .homebrewCask {
            do {
                guard let token = item.packageID, validToken(token), let receiptPath = item.attributes["Homebrew receipt"],
                      let executable = item.attributes["Homebrew executable"], executable.hasSuffix("/bin/brew") else { return result(.blocked, "Verified manager paths and cask token are missing. Refresh first.") }
                let prefix = String(executable.dropLast("/bin/brew".count))
                guard receiptPath == prefix + "/Caskroom/" + token + "/.metadata/INSTALL_RECEIPT.json", FileManager.default.isExecutableFile(atPath: executable) else { return result(.blocked, "The manager executable or receipt location changed.") }
                let receipt = try FileSystem.json(receiptPath)
                let flightBlocks = receipt["uninstall_flight_blocks"]
                guard flightBlocks == nil || (flightBlocks as? Bool) == false,
                      let artifacts = receipt["uninstall_artifacts"] as? [[String: Any]], !artifacts.isEmpty,
                      artifacts.allSatisfy({ Set($0.keys).isSubset(of: ["app", "zap"]) }) else { return result(.external, "This cask has scripts, helpers, packages or other removal artifacts. Review its uninstall in Homebrew/vendor tooling; Macventory will not execute it.") }
                let apps = artifacts.flatMap { $0["app"] as? [String] ?? [] }
                guard apps.count == 1, !apps[0].hasPrefix("/"), !apps[0].contains("..") else { return result(.external, "Only an exact single-app cask mapping is supported.") }
                let config = try FileSystem.json(URL(fileURLWithPath: receiptPath).deletingLastPathComponent().appendingPathComponent("config.json").path)
                let appdir = (config["explicit"] as? [String: Any])?["appdir"] as? String ?? (config["default"] as? [String: Any])?["appdir"] as? String ?? "/Applications"
                guard FileSystem.canonical(URL(fileURLWithPath: appdir).appendingPathComponent(apps[0]).path) == path else { return result(.blocked, "The cask no longer maps exactly to this application.") }
                return result(.homebrewCask, "Verified installed receipt contains one app artifact and no executable removal hooks. No zap, force, cleanup or dependency removal.", executable: executable, arguments: ["uninstall", "--cask", "--", token], fingerprint: try fingerprint(item))
            } catch { return result(.blocked, "Cannot validate removal evidence: " + error.localizedDescription) }
        }
        let instructions: String
        switch item.primarySource {
        case .pkg: instructions = "Use the vendor's documented uninstaller. PKG receipts do not define a safe inverse installation operation."
        case .steam: instructions = "Use Steam → Library → select this game → Manage → Uninstall."
        case .setapp: instructions = "Select this application in Setapp and use its uninstall workflow."
        case .toolbox: instructions = "Select this IDE in JetBrains Toolbox and use its uninstall action."
        case .macPorts, .nix, .homebrewFormula: instructions = "Use the package manager to review dependents and remove the exact package. Macventory does not remove packages or dependencies automatically."
        default: instructions = "A safe bundle-only or complete removal mechanism has not been verified. Consult the vendor; Macventory will not assume Trash is a complete uninstall."
        }
        return result(.external, instructions)
    }
    public static func validToken(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 200 && value.first?.isLetter == true && value.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789@+._-").contains($0) } && !value.contains("..")
    }
    public static func fingerprint(_ item: SoftwareItem) throws -> String {
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
    case simulated, completed
    public var completionMessage: String {
        switch self {
        case .completed: "Operation completed.\nRefresh the inventory to verify the remaining installation state."
        case .simulated: "Simulation completed. Nothing was removed or modified."
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
        var eligibility: StandaloneEligibility?
        if plan.method == .trashBundle {
            let checker = standaloneChecker ?? StandaloneRemovalChecker(configuration: plan.standaloneEligibility?.configuration ?? ScanConfiguration())
            eligibility = try await checker.check(plan.item)
        }
        let running = await MainActor.run { NSWorkspace.shared.runningApplications.contains { $0.bundleURL.map { FileSystem.canonical($0.path) }.map { $0 == plan.item.path || $0.hasPrefix((plan.item.path ?? "") + "/") } == true } }
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
        try await FreshUninstallValidator().validate(plan)
        try Task.checkCancellation()
        switch plan.method {
        case .trashBundle:
            guard let path = plan.item.path else { throw ScanError.process("Missing target") }
            // Recheck identity and running state on the same main-queue turn that submits
            // the native operation; never permanently delete, retry, or sweep data.
            try await Self.recycle(plan, path: path)
        case .homebrewCask:
            guard let executable = plan.executable, let token = plan.item.packageID,
                  UninstallPlanner.validToken(token), plan.arguments == ["uninstall", "--cask", "--", token] else { throw ScanError.process("Unexpected command") }
            let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = plan.arguments
            process.environment = ["HOME": FileManager.default.homeDirectoryForCurrentUser.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ANALYTICS": "1", "HOMEBREW_NO_AUTOREMOVE": "1", "HOMEBREW_NO_INSTALL_CLEANUP": "1", "HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK": "1", "HOMEBREW_NO_ENV_HINTS": "1"]
            process.standardInput = FileHandle.nullDevice; process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
            try process.run()
            let deadline = ContinuousClock.now.advanced(by: .seconds(120))
            do {
                while process.isRunning {
                    try Task.checkCancellation()
                    guard ContinuousClock.now < deadline else { throw ScanError.timeout }
                    try await Task.sleep(for: .milliseconds(50))
                }
                guard process.terminationStatus == 0 else { throw ScanError.process("Homebrew failed (exit \(process.terminationStatus)). It may have partially applied the operation; refresh and review in Homebrew. No automatic retry or force is performed.") }
            } catch {
                if process.isRunning { process.terminate() }
                throw error
            }
        case .external, .blocked: throw ScanError.process("This plan cannot execute")
        }
        return .completed
    }
    @MainActor private static func recycle(_ plan: UninstallPlan, path: String) async throws {
        try Task.checkCancellation()
        guard let eligibility = plan.standaloneEligibility, !eligibility.simulated,
              eligibility.roots == StandaloneRemovalChecker.standardRoots,
              try StandaloneRemovalChecker.inspect(plan.item, roots: StandaloneRemovalChecker.standardRoots) == plan.fingerprint,
              !NSWorkspace.shared.runningApplications.contains(where: { app in
                  app.bundleURL.map { FileSystem.canonical($0.path) }.map { $0 == path || $0.hasPrefix(path + "/") } == true
              }) else { throw ScanError.process("The target changed or is running. Prepare a new preview.") }
        try await NativeTrashRequest.recycle(URL(fileURLWithPath: path))
    }

}

/// UI acknowledgment belongs to one immutable preview plan, never a reusable target name.
public struct UninstallReviewState: Sendable {
    public private(set) var planID: UUID
    public var acknowledged = false
    public init(planID: UUID) { self.planID = planID }
    public mutating func reset(for planID: UUID) { self = Self(planID: planID) }
}
