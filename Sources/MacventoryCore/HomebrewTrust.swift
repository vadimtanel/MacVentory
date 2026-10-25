import Foundation
import CryptoKit
import Darwin

/// Homebrew is an unsigned script. Only locally installed, owner-controlled standard
/// managers are automated. Custom prefixes remain discoverable with guided recovery.
public enum HomebrewTrust {
    static func caskRemovalScope(executable: String, token: String, artifacts: [String]) -> [String] {
        artifacts + [String(executable.dropLast("/bin/brew".count)) + "/Caskroom/" + token]
    }
    public static func permitsResolution(executable: String, resolved: String) -> Bool {
        switch executable {
        case "/opt/homebrew/bin/brew": resolved == "/opt/homebrew/bin/brew"
        case "/usr/local/bin/brew": ["/usr/local/bin/brew", "/usr/local/Homebrew/bin/brew"].contains(resolved)
        default: false
        }
    }
    public static func validateExecutable(_ executable: String) throws {
        guard ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].contains(executable),
              FileManager.default.isExecutableFile(atPath: executable) else { throw ScanError.process("Homebrew executable is missing or outside verified standard locations. Use the configured manager externally.") }
        let canonical = FileSystem.canonical(executable)
        guard permitsResolution(executable: executable, resolved: canonical) else { throw ScanError.process("Homebrew executable resolves outside its installation.") }
        var current = canonical
        while current != "/" {
            let a = try FileManager.default.attributesOfItem(atPath: current)
            let owner = (a[.ownerAccountID] as? NSNumber)?.uint32Value
            let mode = (a[.posixPermissions] as? NSNumber)?.intValue ?? 0o777
            let group = a[.groupOwnerAccountName] as? String
            let trustedGroupWrite = ["admin", "wheel"].contains(group ?? "")
            guard owner == 0 || owner == getuid(), mode & 0o002 == 0, mode & 0o020 == 0 || trustedGroupWrite else { throw ScanError.process("Homebrew path has unsafe ownership or write permissions.") }
            current = (current as NSString).deletingLastPathComponent
        }
    }
    public static func executableFingerprint(_ path: String) throws -> String {
        let a = try FileManager.default.attributesOfItem(atPath: FileSystem.canonical(path))
        guard (a[.size] as? NSNumber)?.intValue ?? Int.max <= 4 * 1024 * 1024 else { throw ScanError.limit("Manager executable too large") }
        return SHA256.hash(data: try Data(contentsOf: URL(fileURLWithPath: path))).map { String(format: "%02x", $0) }.joined() + "|\(a[.systemFileNumber] ?? "")"
    }
}
