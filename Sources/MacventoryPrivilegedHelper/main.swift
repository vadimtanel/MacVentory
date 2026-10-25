import Foundation
import Security
import MacventoryCore

/// A deliberately narrow privileged service. It has no arbitrary-command/file/quit RPC.
private final class Delegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard let (client, requirement) = Self.verifiedClient(connection.processIdentifier) else { return false }
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: MacPortsPrivilegedXPC.self)
        connection.exportedObject = Service(clientBundle: client)
        connection.resume(); return true
    }
    private static func verifiedClient(_ pid: pid_t) -> (String, String)? {
        var ownCode: SecCode?, ownStatic: SecStaticCode?, ownInfo: CFDictionary?
        guard SecCodeCopySelf([], &ownCode) == errSecSuccess, let ownCode,
              SecCodeCopyStaticCode(ownCode, [], &ownStatic) == errSecSuccess, let ownStatic,
              SecCodeCopySigningInformation(ownStatic, SecCSFlags(rawValue: kSecCSSigningInformation), &ownInfo) == errSecSuccess,
              let team = (ownInfo as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String,
              !team.isEmpty, team.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        var requirement: SecRequirement?, guest: SecCode?
        guard let text = try? MacPortsAuthorization.peerRequirement(identifier: "org.vadimtanel.Macventory", team: team) else { return nil }
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
              SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &guest) == errSecSuccess, let guest,
              SecCodeCheckValidity(guest, [], requirement) == errSecSuccess else { return nil }
        var path: CFURL?, guestStatic: SecStaticCode?
        guard SecCodeCopyStaticCode(guest, [], &guestStatic) == errSecSuccess, let guestStatic, SecCodeCopyPath(guestStatic, [], &path) == errSecSuccess, let path else { return nil }
        let raw = FileSystem.canonical((path as URL).path)
        if raw.hasSuffix(".app") { return (raw, text) }
        if let range = raw.range(of: ".app/") { return (String(raw[..<range.lowerBound]) + ".app", text) }
        return nil
    }
}
private final class Service: NSObject, MacPortsPrivilegedXPC, @unchecked Sendable {
    private let clientBundle: String
    private static let session = Requests()
    init(clientBundle: String) { self.clientBundle = clientBundle }
    func uninstall(_ data: Data, reply: @escaping (Int32, String) -> Void) {
        guard data.count <= 64_000 else { reply(1, "Invalid request size"); return }
        let responder = Reply(reply)
        Task {
            do {
                let request = try JSONDecoder().decode(MacPortsAuthorizedRequest.self, from: data)
                try await Self.session.accept(request)
                let outcome = try await MacPortsAuthorizedOperation().execute(request, clientBundle: clientBundle)
                responder.call(outcome == .verifiedRemoved || outcome == .packageRegistrationRemoved || outcome == .alreadyAbsent ? 0 : 1, outcome.completionMessage)
            } catch { responder.call(1, error.localizedDescription) }
        }
    }
}
private final class Reply: @unchecked Sendable {
    let callback: (Int32, String) -> Void
    init(_ callback: @escaping (Int32, String) -> Void) { self.callback = callback }
    func call(_ code: Int32, _ message: String) { callback(code, message) }
}
private actor Requests {
    private var consumed: [UUID: Date] = [:]
    func accept(_ request: MacPortsAuthorizedRequest) throws {
        let now = Date()
        consumed = consumed.filter { (0..<300).contains(now.timeIntervalSince($0.value)) }
        guard (0..<300).contains(now.timeIntervalSince(request.createdAt)), consumed.count < 1000, consumed[request.id] == nil else { throw ScanError.process("Expired or reused authorization request") }
        consumed[request.id] = request.createdAt
    }
}
@main struct Main {
    static func main() {
        let delegate = Delegate(), listener = NSXPCListener(machServiceName: MacPortsAuthorization.serviceName)
        listener.delegate = delegate; listener.resume()
        withExtendedLifetime(delegate) { RunLoop.current.run() }
    }
}
