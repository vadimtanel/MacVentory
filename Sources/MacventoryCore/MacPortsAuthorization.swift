import Foundation
import Security
import ServiceManagement

@objc public protocol MacPortsPrivilegedXPC {
    func uninstall(_ request: Data, reply: @escaping (Int32, String) -> Void)
}
public struct MacPortsAuthorizedRequest: Codable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let name: String
    public let version: String
    public let itemID: String
    public let executableFingerprint: String
    public let stateFingerprint: String
    public init(_ proof: ManagedRemovalEvidence) throws {
        guard case let .macPorts(name, version, prefix) = proof.target, prefix == "/opt/local", proof.executable == "/opt/local/bin/port" else { throw ScanError.process("Privileged helper accepts only the verified standard MacPorts installation") }
        self.id = UUID(); self.createdAt = proof.preparedAt; self.name = name; self.version = version; self.itemID = proof.itemID; self.executableFingerprint = proof.executableFingerprint; self.stateFingerprint = proof.stateFingerprint
    }
}
public enum MacPortsAuthorization {
    public static let serviceName = "org.vadimtanel.Macventory.macports-helper"
    public static let plistName = serviceName + ".plist"
    public static var isPackagedAndSigned: Bool {
        guard Bundle.main.bundleIdentifier == "org.vadimtanel.Macventory",
              let team = SignedVendorIdentityChecker().teamIdentifier(at: Bundle.main.bundleURL.path),
              SignedVendorIdentityChecker().teamIdentifier(at: Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/MacventoryPrivilegedHelper").path) == team,
              FileSystem.exists(Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchDaemons/" + plistName).path) else { return false }
        return true
    }
    /// Called only after the exact destructive preview is confirmed, never during discovery/QA.
    public static func execute(_ proof: ManagedRemovalEvidence) async throws -> Int32 {
        guard isPackagedAndSigned else { throw ScanError.process("macOS authorization requires the correctly signed app and its matching embedded helper") }
        let request = try JSONEncoder().encode(MacPortsAuthorizedRequest(proof))
        let service = SMAppService.daemon(plistName: plistName)
        if service.status == .notRegistered { try service.register() }
        switch service.status {
        case .enabled: break
        case .requiresApproval:
            // The OS owns approval. No password, silent grant or queued uninstall.
            await MainActor.run { SMAppService.openSystemSettingsLoginItems() }
            return LiveManagedRemovalBoundary.authorizationPending
        case .notFound, .notRegistered: throw ScanError.process("The signed helper is unavailable or not registered. No uninstall was submitted.")
        @unknown default: throw ScanError.process("Unknown macOS authorization state; no uninstall was submitted.")
        }
        return try await HelperRequest.perform(request)
    }
}
/// Bounded XPC wait; a lost reply or cancellation has an unknown result, never success.
private actor HelperRequest {
    private var continuation: CheckedContinuation<Int32, any Error>?
    private var connection: NSXPCConnection?
    private var timeout: Task<Void, Never>?
    private func finish(_ result: Result<Int32, any Error>) {
        guard let continuation else { return }; self.continuation = nil
        timeout?.cancel(); timeout = nil
        connection?.invalidate(); connection = nil; continuation.resume(with: result)
    }
    static func perform(_ request: Data) async throws -> Int32 {
        let operation = HelperRequest()
        return try await withTaskCancellationHandler {
            try await operation.start(request)
        } onCancel: { Task { await operation.finish(.failure(ScanError.process("Authorization operation cancelled; the helper may already have applied changes. Refresh before retrying."))) } }
    }
    private func start(_ request: Data) async throws -> Int32 {
        try Task.checkCancellation()
        let connection = NSXPCConnection(machServiceName: MacPortsAuthorization.serviceName, options: .privileged)
        self.connection = connection
        connection.remoteObjectInterface = NSXPCInterface(with: MacPortsPrivilegedXPC.self)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            connection.interruptionHandler = { Task { await self.finish(.failure(ScanError.process("MacPorts helper interrupted; outcome unknown. Refresh installation state."))) } }
            connection.invalidationHandler = { Task { await self.finish(.failure(ScanError.process("MacPorts helper unavailable; outcome unknown."))) } }
            connection.resume()
            guard !Task.isCancelled else { finish(.failure(CancellationError())); return }
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in Task { await self.finish(.failure(ScanError.process(error.localizedDescription))) } }) as? MacPortsPrivilegedXPC else {
                finish(.failure(ScanError.process("Cannot connect to the signed MacPorts helper"))); return
            }
            proxy.uninstall(request) { code, detail in
                Task { await self.finish(code == 0 ? .success(0) : .failure(ScanError.process(detail))) }
            }
            timeout = Task {
                do { try await Task.sleep(for: .seconds(150)) } catch { return }
                self.finish(.failure(ScanError.process("MacPorts helper timed out; outcome unknown. Refresh before retrying.")))
            }
        }
    }
}

/// Shared handler used by the real helper after caller code-signature authorization.
/// Tests inject the manager boundary; no privileged service is registered in tests.
public struct MacPortsAuthorizedOperation: Sendable {
    public let adapter: ManagedRemovalAdapter
    public init(adapter: ManagedRemovalAdapter = ManagedRemovalAdapter()) { self.adapter = adapter }
    public func execute(_ request: MacPortsAuthorizedRequest, clientBundle: String) async throws -> UninstallOutcome {
        guard (0..<300).contains(Date().timeIntervalSince(request.createdAt)), RemovalIdentity.portName(request.name), RemovalIdentity.portVersion(request.version) else { throw ScanError.process("Invalid or expired exact port authorization") }
        var item = SoftwareItem(name: request.name, kind: .package, source: .macPorts, packageID: request.name)
        item.id = request.itemID; item.version = request.version
        item.attributes["Prefix"] = "/opt/local"; item.attributes["Manager executable"] = "/opt/local/bin/port"
        let fresh = try await adapter.prepare(item)
        guard fresh.executableFingerprint == request.executableFingerprint, fresh.stateFingerprint == request.stateFingerprint,
              !fresh.requiresAuthorization, !ProtectionPolicy.isRunningCopy(fresh.artifacts.map(\.path), runningBundle: clientBundle) else { throw ScanError.process("Port installation or caller protection changed") }
        return try await adapter.execute(UninstallPlanner.plan(for: item, manager: fresh))
    }
}
