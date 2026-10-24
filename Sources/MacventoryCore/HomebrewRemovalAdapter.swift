import Foundation

public protocol HomebrewRemovalOperating: Sendable {
    func installed(executable: String, cask: Bool) async throws -> [String: [String]]
    func dependents(executable: String, token: String) async throws -> String
    func services(executable: String) async throws -> Data
    func remove(executable: String, arguments: [String]) async throws -> Int32
}
public extension HomebrewRemovalOperating {
    func services(executable: String) async throws -> Data { Data("[]".utf8) }
}
public struct HomebrewRemovalAdapter: UninstallExecuting {
    public var operation: any HomebrewRemovalOperating
    public init(operation: any HomebrewRemovalOperating) { self.operation = operation }
    public static func expectedVersion(for item: SoftwareItem) -> String? {
        if item.primarySource == .homebrewCask {
            let value = item.attributes["Manager version"]
            return value == "Unknown" ? nil : value
        }
        return item.version
    }
    public func execute(_ plan: UninstallPlan) async throws -> UninstallOutcome {
        guard [.homebrewCask, .homebrewFormula].contains(plan.method), plan.canExecute,
              let executable = plan.executable, let token = plan.item.packageID, UninstallPlanner.validToken(token),
              plan.arguments == ["uninstall", plan.method == .homebrewCask ? "--cask" : "--formula", "--", token] else { throw ScanError.process("Unexpected manager operation") }
        let cask = plan.method == .homebrewCask
        let installed = try await operation.installed(executable: executable, cask: cask)
        guard let versions = installed[token] else {
            let artifacts = (plan.item.health?.artifacts ?? plan.item.path.map { [ArtifactObservation($0, .present)] } ?? []).map { ArtifactObservation.inspect($0.path) }
            if artifacts.contains(where: { $0.presence == .inaccessible }) { return .unknownResult }
            return artifacts.contains { [.present, .brokenLink].contains($0.presence) } ? .partialRemoval : .alreadyAbsent
        }
        if cask, let version = Self.expectedVersion(for: plan.item), !versions.contains(version) { throw ScanError.process("Installed cask version changed. Refresh before reviewing removal.") }
        if !cask {
            try await HomebrewServiceReview.validate(operation.services(executable: executable), token: token)
            guard versions.count == 1, versions.first == plan.item.version else { throw ScanError.process("Formula version changed or multiple kegs are installed. Review the exact version in Homebrew.") }
            guard try await operation.dependents(executable: executable, token: token).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ScanError.process("Installed packages depend on this formula. No dependents will be removed.") }
        }
        try Task.checkCancellation()
        guard Date().timeIntervalSince(plan.createdAt) < 300, try UninstallPlanner.fingerprint(plan.item) == plan.fingerprint else { throw ScanError.process("Manager or artifact evidence changed during preflight") }
        // No second executor or shell; injected implementations own only this exact operation.
        let exit = try await operation.remove(executable: executable, arguments: plan.arguments)
        do {
            let after = try await operation.installed(executable: executable, cask: cask)
            let artifacts = (plan.item.health?.artifacts ?? plan.item.path.map { [ArtifactObservation($0, .present)] } ?? []).map { ArtifactObservation.inspect($0.path) }
            return RemovalVerification.managerOutcome(installed: after[token] != nil, artifacts: artifacts, exitCode: exit)
        } catch { return .unknownResult }
    }
}
public enum RemovalVerification {
    public static func managerOutcome(installed: Bool, artifacts: [ArtifactObservation], exitCode: Int32) -> UninstallOutcome {
        if artifacts.contains(where: { $0.presence == .inaccessible }) { return .unknownResult }
        if installed { return exitCode == 0 ? .partialRemoval : .failed }
        if artifacts.contains(where: { $0.presence == .present || $0.presence == .brokenLink }) { return .partialRemoval }
        if exitCode != 0 { return .partialRemoval }
        return artifacts.isEmpty ? .packageRegistrationRemoved : .verifiedRemoved
    }
}
public struct LiveHomebrewOperation: HomebrewRemovalOperating {
    private let runner = ProcessRunner()
    public init() {}
    public func installed(executable: String, cask: Bool) async throws -> [String: [String]] {
        try HomebrewScanner.installedTokens(try await runner.run(.brewInstalled(executable: executable, cask: cask)))
    }
    public func services(executable: String) async throws -> Data { try await runner.run(.brewServices(executable: executable)) }
    public func dependents(executable: String, token: String) async throws -> String {
        String(decoding: try await runner.run(.brewDependents(executable: executable, token: token)), as: UTF8.self)
    }
    public func remove(executable: String, arguments: [String]) async throws -> Int32 {
        try HomebrewTrust.validateExecutable(executable)
        guard arguments.count == 4, arguments[0] == "uninstall", ["--cask", "--formula"].contains(arguments[1]), arguments[2] == "--", UninstallPlanner.validToken(arguments[3]) else { throw ScanError.process("Unexpected Homebrew arguments") }
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.environment = ["HOME": FileManager.default.homeDirectoryForCurrentUser.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ANALYTICS": "1", "HOMEBREW_NO_AUTOREMOVE": "1", "HOMEBREW_NO_INSTALL_CLEANUP": "1", "HOMEBREW_NO_ENV_HINTS": "1"]
        // No password prompt may hang a modal. Privileged hooks use guided handoff.
        process.standardInput = FileHandle.nullDevice; process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try Task.checkCancellation(); try process.run()
        let deadline = ContinuousClock.now.advanced(by: .seconds(120))
        do {
            while process.isRunning {
                try Task.checkCancellation()
                guard ContinuousClock.now < deadline else { throw ScanError.timeout }
                try await Task.sleep(for: .milliseconds(50))
            }
            return process.terminationStatus
        } catch {
            if process.isRunning { process.terminate() }
            // Outcome after timeout/cancel is unknown, never success or safe rollback.
            throw ScanError.process("Homebrew interrupted: " + error.localizedDescription + ". It may have partially applied changes. Refresh; do not automatically retry or force.")
        }
    }
}
