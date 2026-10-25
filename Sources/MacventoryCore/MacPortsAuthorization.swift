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
    public let authorization: Data
    public init(_ proof: ManagedRemovalEvidence, authorization: Data = Data()) throws {
        guard case let .macPorts(name, version, prefix) = proof.target, prefix == "/opt/local", proof.executable == "/opt/local/bin/port" else { throw ScanError.process("Privileged helper accepts only the verified standard MacPorts installation") }
        self.id = UUID(); self.createdAt = proof.preparedAt; self.name = name; self.version = version; self.itemID = proof.itemID; self.executableFingerprint = proof.executableFingerprint; self.stateFingerprint = proof.stateFingerprint; self.authorization = authorization
    }
}
public enum MacPortsAuthorization {
    public static let serviceName = "org.vadimtanel.Macventory.macports-helper"
    public static let plistName = serviceName + ".plist"
    public static func peerRequirement(identifier: String, team: String) throws -> String {
        guard ["org.vadimtanel.Macventory", serviceName].contains(identifier), !team.isEmpty, team.count <= 64, team.utf8.allSatisfy({ (65...90).contains($0) || (48...57).contains($0) }) else { throw ScanError.process("Invalid peer signing identity") }
        return "anchor apple generic and identifier \"" + identifier + "\" and certificate leaf[subject.OU] = \"" + team + "\""
    }
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
        try Task.checkCancellation()
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
        let lease = try await Task.detached(priority: .userInitiated) { try MacPortsAdminAuthorization() }.value
        defer { lease.invalidate() }
        try Task.checkCancellation()
        let request = try JSONEncoder().encode(MacPortsAuthorizedRequest(proof, authorization: lease.externalForm))
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
        guard let team = SignedVendorIdentityChecker().teamIdentifier(at: Bundle.main.bundleURL.path) else { throw ScanError.process("App signing identity is unavailable") }
        connection.setCodeSigningRequirement(try MacPortsAuthorization.peerRequirement(identifier: MacPortsAuthorization.serviceName, team: team))
        self.connection = connection
        connection.remoteObjectInterface = NSXPCInterface(with: MacPortsPrivilegedXPC.self)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            connection.interruptionHandler = { Task { self.finish(.failure(ScanError.process("MacPorts helper interrupted; outcome unknown. Refresh installation state."))) } }
            connection.invalidationHandler = { Task { self.finish(.failure(ScanError.process("MacPorts helper unavailable; outcome unknown."))) } }
            connection.resume()
            guard !Task.isCancelled else { finish(.failure(CancellationError())); return }
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in Task { self.finish(.failure(ScanError.process(error.localizedDescription))) } }) as? MacPortsPrivilegedXPC else {
                finish(.failure(ScanError.process("Cannot connect to the signed MacPorts helper"))); return
            }
            proxy.uninstall(request) { code, detail in
                Task { self.finish(code == 0 ? .success(0) : .failure(ScanError.process(detail))) }
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
    public let authorizer: any MacPortsRequestAuthorizing
    public init(adapter: ManagedRemovalAdapter = ManagedRemovalAdapter(), authorizer: any MacPortsRequestAuthorizing = MacPortsSystemAuthorizer()) { self.adapter = adapter; self.authorizer = authorizer }
    public func execute(_ request: MacPortsAuthorizedRequest, clientBundle: String) async throws -> UninstallOutcome {
        guard (0..<300).contains(Date().timeIntervalSince(request.createdAt)), RemovalIdentity.portName(request.name), RemovalIdentity.portVersion(request.version) else { throw ScanError.process("Invalid or expired exact port authorization") }
        try authorizer.validate(request.authorization) // Reject before even querying the privileged manager.
        var item = SoftwareItem(name: request.name, kind: .package, source: .macPorts, packageID: request.name)
        item.id = request.itemID; item.version = request.version
        item.attributes["Prefix"] = "/opt/local"; item.attributes["Manager executable"] = "/opt/local/bin/port"
        let fresh = try await adapter.prepare(item)
        guard fresh.executableFingerprint == request.executableFingerprint, fresh.stateFingerprint == request.stateFingerprint,
              !fresh.requiresAuthorization, !ProtectionPolicy.isRunningCopy(fresh.artifacts.map(\.path), runningBundle: clientBundle) else { throw ScanError.process("Port installation or caller protection changed") }
        let guarded = ManagedRemovalAdapter(boundary: AuthorizedPortBoundary(base: adapter.boundary, authorizer: authorizer, authorization: request.authorization), security: adapter.security)
        return try await guarded.execute(UninstallPlanner.plan(for: item, manager: fresh))
    }
}

/// A connection's code identity and an approved daemon do not authorize a root operation.
public protocol MacPortsRequestAuthorizing: Sendable {
    func validate(_ externalForm: Data) throws
}
public struct MacPortsSystemAuthorizer: MacPortsRequestAuthorizing {
    public init() {}
    public func validate(_ data: Data) throws {
        guard data.count == MemoryLayout<AuthorizationExternalForm>.size else { throw ScanError.process("Administrator authorization is missing or malformed") }
        var form = AuthorizationExternalForm()
        withUnsafeMutableBytes(of: &form) { _ = data.copyBytes(to: $0) }
        var reference: AuthorizationRef?
        guard AuthorizationCreateFromExternalForm(&form, &reference) == errAuthorizationSuccess, let reference else { throw ScanError.process("Administrator authorization is invalid or expired") }
        defer { AuthorizationFree(reference, []) }
        // Never prompt from the privileged daemon, nor extend an ungranted right.
        try MacPortsAdminAuthorization.check(reference, flags: [])
    }
}
private struct AuthorizedPortBoundary: ManagedRemovalBoundary {
    let base: any ManagedRemovalBoundary
    let authorizer: any MacPortsRequestAuthorizing
    let authorization: Data
    func query(_ command: InventoryCommand) async throws -> Data { try await base.query(command) }
    func remove(_ proof: ManagedRemovalEvidence) async throws -> Int32 {
        try authorizer.validate(authorization) // Immediately before the actual privileged effect.
        return try await base.remove(proof)
    }
}
/// A fresh OS authorization session for one confirmed request; never serialized to disk/logs.
private final class MacPortsAdminAuthorization: @unchecked Sendable {
    private var reference: AuthorizationRef?
    let externalForm: Data
    init() throws {
        var reference: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &reference) == errAuthorizationSuccess, let reference else { throw ScanError.process("Cannot start administrator authorization") }
        do {
            try Self.check(reference, flags: [.interactionAllowed, .extendRights])
            var form = AuthorizationExternalForm()
            guard AuthorizationMakeExternalForm(reference, &form) == errAuthorizationSuccess else { throw ScanError.process("Cannot bind administrator authorization to this request") }
            self.externalForm = withUnsafeBytes(of: &form) { Data($0) }
            self.reference = reference
        } catch { AuthorizationFree(reference, [.destroyRights]); throw error }
    }
    func invalidate() { if let reference { self.reference = nil; AuthorizationFree(reference, [.destroyRights]) } }
    deinit { invalidate() }
    static func check(_ reference: AuthorizationRef, flags: AuthorizationFlags) throws {
        let status = kAuthorizationRightExecute.withCString { name in
            var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &item) { pointer in
                var rights = AuthorizationRights(count: 1, items: pointer)
                return AuthorizationCopyRights(reference, &rights, nil, flags, nil)
            }
        }
        guard status == errAuthorizationSuccess else { throw ScanError.process("Administrator authorization was denied, cancelled or expired (\(status)). No removal was authorized.") }
    }
}
