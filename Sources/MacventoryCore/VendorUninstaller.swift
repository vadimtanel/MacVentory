import Foundation
import Security
import AppKit
import CryptoKit

public struct VendorUninstallerCandidate: Sendable {
    public let path: String
    public let team: String
    public let fingerprint: String
}
public protocol VendorIdentityChecking: Sendable {
    func teamIdentifier(at path: String) -> String?
}
public struct SignedVendorIdentityChecker: VendorIdentityChecking {
    public init() {}
    public func teamIdentifier(at path: String) -> String? {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString("anchor apple generic" as CFString, [], &requirement) == errSecSuccess,
              SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code) == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode), requirement) == errSecSuccess else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let values = info as? [String: Any], let team = values[kSecCodeInfoTeamIdentifier as String] as? String, !team.isEmpty else { return nil }
        return team
    }
}
public enum VendorUninstallerDiscovery {
    /// Bounded local discovery only. Names find candidates; matching verified signing
    /// teams establish publisher association. No downloaded scripts or command catalog.
    public static func discover(for item: SoftwareItem, checker: any VendorIdentityChecking = SignedVendorIdentityChecker()) -> VendorUninstallerCandidate? {
        guard [.pkg, .unmanaged].contains(item.primarySource), !item.isSystem, !item.stale,
              let app = item.path, !ProtectionPolicy.protectedPath(app), !ProtectionPolicy.isRunningCopy([app]),
              let team = checker.teamIdentifier(at: app) else { return nil }
        // Publisher identity alone cannot associate a sibling tool with this product.
        let roots = [app + "/Contents/Helpers", app + "/Contents/Resources", app + "/Contents/Frameworks"]
        for root in roots {
            guard let children = try? FileSystem.children(root), children.count <= 100 else { continue }
            for candidate in children where candidate.pathExtension == "app" && candidate.lastPathComponent.lowercased().contains("uninstall") {
                let path = candidate.path
                guard path != app, path == FileSystem.canonical(path), FileSystem.contained(path, in: root),
                      checker.teamIdentifier(at: path) == team,
                      let fingerprint = try? fingerprint(path: path, team: team) else { continue }
                guard let target = try? Self.fingerprint(path: app, team: team) else { continue }
                return .init(path: path, team: team, fingerprint: fingerprint + "|" + target)
            }
        }
        return nil
    }
    public static func fingerprint(path: String, team: String) throws -> String {
        let a = try FileManager.default.attributesOfItem(atPath: path)
        let metadata = path + "/Contents/Info.plist"
        let attributes = try FileManager.default.attributesOfItem(atPath: metadata)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 4 * 1024 * 1024 else { throw ScanError.limit("Vendor metadata exceeds limit") }
        guard metadata == FileSystem.canonical(metadata) else { throw ScanError.process("Vendor metadata is linked") }
        let data = try Data(contentsOf: URL(fileURLWithPath: metadata))
        let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        guard let name = info?["CFBundleExecutable"] as? String, !name.isEmpty, name != ".", name != "..", !name.contains("/") else { throw ScanError.process("Vendor executable identity is unavailable") }
        let binary = path + "/Contents/MacOS/" + name
        guard binary == FileSystem.canonical(binary) else { throw ScanError.process("Vendor executable is linked") }
        var seal = ""
        var code: SecStaticCode?, signing: CFDictionary?
        if SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code) == errSecSuccess, let code,
           SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &signing) == errSecSuccess,
           let hash = (signing as? [String: Any])?[kSecCodeInfoUnique as String] as? Data { seal = hash.base64EncodedString() }
        return team + "|\(a[.systemFileNumber] ?? "")|" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() + "|" + (try RemovalIdentity.executableDigest(binary)) + "|" + seal
    }

    public static func launch(_ path: String, for item: SoftwareItem, fingerprint: String?) async throws {
        guard let current = await Task.detached(priority: .userInitiated, operation: { discover(for: item) }).value, current.path == path, current.fingerprint == fingerprint else { throw ScanError.process("Vendor signing identity or installation changed") }
        try await openVerifiedApplication(path)
    }
    @MainActor private static func openVerifiedApplication(_ path: String) async throws {
        let config = ExactApplicationLaunch.configuration()
        let opened = try await NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config)
        guard opened.bundleURL.map({ FileSystem.canonical($0.path) }) == path else { throw ScanError.process("Vendor launch returned another physical installation; outcome unknown") }
    }
}

/// Select a physical app, never substitute another running copy with the same identifier.
public enum ExactApplicationLaunch {
    @MainActor public static func configuration() -> NSWorkspace.OpenConfiguration {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.allowsRunningApplicationSubstitution = false
        return config
    }
}
