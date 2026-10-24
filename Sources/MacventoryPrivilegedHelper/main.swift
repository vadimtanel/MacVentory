import Foundation
import Security
import MacventoryCore

/// A deliberately narrow privileged service. It has no arbitrary-command/file/quit RPC.
private final class Delegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard let client = Self.verifiedClient(connection.processIdentifier) else { return false }
        connection.exportedInterface = NSXPCInterface(with: MacPortsPrivilegedXPC.self)
        connection.exportedObject = Service(clientBundle: client)
        connection.resume(); return true
    }
    private static func verifiedClient(_ pid: pid_t) -> String? {
        var ownCode: SecCode?, ownStatic: SecStaticCode?, ownInfo: CFDictionary?
        guard SecCodeCopySelf([], &ownCode) == errSecSuccess, let ownCode,
              SecCodeCopyStaticCode(ownCode, [], &ownStatic) == errSecSuccess, let ownStatic,
              SecCodeCopySigningInformation(ownStatic, SecCSFlags(rawValue: kSecCSSigningInformation), &ownInfo) == errSecSuccess,
              let team = (ownInfo as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String,
              !team.isEmpty, team.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        var requirement: SecRequirement?, guest: SecCode?
        let text = "anchor apple generic and identifier \"org.vadimtanel.Macventory\" and certificate leaf[subject.OU] = \"" + team + "\""
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
              SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &guest) == errSecSuccess, let guest,
              SecCodeCheckValidity(guest, [], requirement) == errSecSuccess else { return nil }
        var path: CFURL?, guestStatic: SecStaticCode?
        guard SecCodeCopyStaticCode(guest, [], &guestStatic) == errSecSuccess, let guestStatic, SecCodeCopyPath(guestStatic, [], &path) == errSecSuccess, let path else { return nil }
        let raw = FileSystem.canonical((path as URL).path)
        if raw.hasSuffix(".app") { return raw }
        if let range = raw.range(of: ".app/") { return String(raw[..<range.lowerBound]) + ".app" }
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
    private var consumed = Set<UUID>()
    func accept(_ request: MacPortsAuthorizedRequest) throws {
        guard (0..<300).contains(Date().timeIntervalSince(request.createdAt)), consumed.count < 1000, consumed.insert(request.id).inserted else { throw ScanError.process("Expired or reused authorization request") }
    }
}
@main struct Main {
    static func main() {
        let delegate = Delegate(), listener = NSXPCListener(machServiceName: MacPortsAuthorization.serviceName)
        listener.delegate = delegate; listener.resume()
        withExtendedLifetime(delegate) { RunLoop.current.run() }
    }
}
