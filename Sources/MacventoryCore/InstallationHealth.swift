import Foundation
import Darwin

public enum InstallationStatus: String, Codable, CaseIterable, Sendable {
    case verified, attention, protected, unverified, partial, historical
    public var title: String {
        switch self {
        case .verified: "Verified Installed"
        case .attention: "Attention Required"
        case .protected: "Protected / System"
        case .unverified: "Unknown / Unverified"
        case .partial: "Partially Removed"
        case .historical: "Receipt Only / Historical"
        }
    }
    public var symbol: String {
        switch self {
        case .verified: "checkmark.circle"
        case .attention, .partial: "exclamationmark.triangle"
        case .protected: "lock.shield"
        case .unverified: "questionmark.circle"
        case .historical: "info.circle"
        }
    }
}
public enum ManagerRegistration: String, Codable, Sendable { case installed, absent, receiptOnly, unknown }
public enum ArtifactPresence: String, Codable, Sendable { case present, missing, brokenLink, inaccessible }
public struct ArtifactObservation: Codable, Equatable, Sendable {
    public var path: String
    public var presence: ArtifactPresence
    public init(_ path: String, _ presence: ArtifactPresence) { self.path = path; self.presence = presence }
    public static func inspect(_ path: String) -> Self {
        // fileExists alone conflates access denial with absence. Verify the parent chain
        // before accepting ENOENT; a blocked ancestor is never evidence of absence.
        var value = stat()
        if lstat(path, &value) == 0 {
            if value.st_mode & S_IFMT == S_IFLNK {
                var target = stat()
                if stat(path, &target) != 0 { return Self(path, errno == ENOENT ? .brokenLink : .inaccessible) }
            }
            return Self(path, .present)
        }
        guard errno == ENOENT || errno == ENOTDIR else { return Self(path, .inaccessible) }
        var parent = (path as NSString).deletingLastPathComponent
        while parent != "/" && !parent.isEmpty {
            if lstat(parent, &value) == 0 {
                guard access(parent, R_OK | X_OK) == 0 else { return Self(path, .inaccessible) }
                return Self(path, .missing)
            }
            guard errno == ENOENT || errno == ENOTDIR else { return Self(path, .inaccessible) }
            parent = (parent as NSString).deletingLastPathComponent
        }
        return Self(path, .missing)
    }
}
public struct InstallationHealth: Codable, Equatable, Sendable {
    public var status: InstallationStatus
    public var explanation: String
    public var checkedAt: Date
    public var registration: ManagerRegistration
    public var artifacts: [ArtifactObservation]
    public init(_ status: InstallationStatus, _ explanation: String, registration: ManagerRegistration = .unknown, artifacts: [ArtifactObservation] = [], checkedAt: Date = Date()) {
        self.status = status; self.explanation = explanation; self.registration = registration; self.artifacts = artifacts; self.checkedAt = checkedAt
    }
}
public extension SoftwareItem {
    var installationHealth: InstallationHealth {
        if stale { return .init(.unverified, "Cached observation; the source did not complete a fresh scan.", checkedAt: scannedAt) }
        if isSystem || ProtectionPolicy.protectedPath(path) { return .init(.protected, "System location or macOS filesystem protection prevents supported removal.", checkedAt: scannedAt) }
        if primarySource == .unknown { return health?.status == .unverified ? health! : .init(.unverified, "Ownership is conflicting or incomplete.", checkedAt: scannedAt) }
        return health ?? .init(.unverified, "Installation state has not been verified.", checkedAt: scannedAt)
    }
}
public enum ProtectionPolicy {
    public static func protectedPath(_ path: String?) -> Bool {
        guard let path else { return false }
        // /usr/local is the documented writable exception to macOS's /usr protection.
        if path == "/usr/local" || path.hasPrefix("/usr/local/") { return false }
        return ["/System", "/usr", "/bin", "/sbin"].contains { path == $0 || path.hasPrefix($0 + "/") }
    }
    public static func isRunningCopy(_ paths: [String], runningBundle: String? = Bundle.main.bundleURL.path) -> Bool {
        guard let runningBundle, runningBundle.hasSuffix(".app") else { return false }
        let active = FileSystem.canonical(runningBundle)
        return paths.contains { let target = FileSystem.canonical($0); return active == target || active.hasPrefix(target + "/") }
    }
}
public enum InstallationHealthClassifier {
    public static func classify(_ item: SoftwareItem, registration: ManagerRegistration = .unknown, artifacts: [ArtifactObservation]? = nil) -> InstallationHealth {
        let artifacts = artifacts ?? item.path.map { [ArtifactObservation.inspect($0)] } ?? []
        if item.stale { return .init(.unverified, "Cached observation; refresh the source before acting.", registration: registration, artifacts: artifacts, checkedAt: item.scannedAt) }
        if item.isSystem || ProtectionPolicy.protectedPath(item.path) { return .init(.protected, "Protected system location.", registration: registration, artifacts: artifacts) }
        if ProtectionPolicy.isRunningCopy([item.path].compactMap { $0 }) { return .init(.protected, "Currently running Macventory bundle. Use an external manager workflow after quitting.", registration: registration, artifacts: artifacts) }
        if item.primarySource == .unknown { return .init(.unverified, "Conflicting or incomplete ownership.", artifacts: artifacts) }
        if artifacts.contains(where: { $0.presence == .inaccessible }) { return .init(.unverified, "Artifact inspection was incomplete or access was denied.", registration: registration, artifacts: artifacts) }
        if registration == .absent, artifacts.contains(where: { $0.presence == .present }) {
            return .init(.attention, "Files remain but the manager no longer reports this exact installation. Review ownership before removal.", registration: registration, artifacts: artifacts)
        }
        if item.primarySource == .pkg, item.kind == .package { return .init(.historical, "A PKG receipt records an installation event; it does not establish an installed application. " + (item.attributes["Payload"] ?? ""), registration: .receiptOnly, artifacts: artifacts) }
        if artifacts.contains(where: { $0.presence == .missing || $0.presence == .brokenLink }) {
            if registration == .installed {
                return .init(.attention, (item.primarySource == .homebrewCask && artifacts.contains(where: { $0.path.hasSuffix(".app") }) ? "Application Missing — Homebrew Registration Remains. " : "Expected Files Missing — Manager Registration Remains. ") + "The exact manager identity is installed; an expected artifact is absent or its link is broken.", registration: registration, artifacts: artifacts)
            }
            return .init(.unverified, "Expected files are absent, but current manager installation state is not verified.", registration: registration, artifacts: artifacts)
        }
        if registration == .receiptOnly { return .init(.historical, "Historical receipt; current manager installation state was not established.", registration: registration, artifacts: artifacts) }
        if registration == .installed || (!artifacts.isEmpty && artifacts.allSatisfy { $0.presence == .present }) {
            return .init(.verified, registration == .installed ? "The manager reports the exact package installed. Package-only installations do not require an application bundle." : "The selected artifact exists. Manager ownership and complete removal are separate checks.", registration: registration, artifacts: artifacts)
        }
        return .init(.unverified, "No complete installation-state observation is available.", registration: registration, artifacts: artifacts)
    }
}
