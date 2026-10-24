import Foundation

public enum UninstallExecutionLevel: String, CaseIterable, Sendable {
    case direct, interactive, guided
    public var title: String {
        switch self { case .direct: "Direct Uninstall"; case .interactive: "Interactive Uninstall"; case .guided: "Guided Only" }
    }
    public var symbol: String {
        switch self { case .direct: "gearshape.arrow.triangle.2.circlepath"; case .interactive: "person.crop.rectangle"; case .guided: "book" }
    }
}
public enum RemovalScope: String, Sendable {
    case managerPackage, profileElement, bundleOnly, vendorDefined, instructions
    public var description: String {
        switch self {
        case .managerPackage: "The exact selected package/version through its official manager. Other packages and optional data cleanup are excluded."
        case .profileElement: "Only the selected element of the reviewed mutable profile. Nix store objects, other profiles and previous generations remain."
        case .bundleOnly: "Only the selected app bundle moves to recoverable Trash. External components, preferences and personal data may remain."
        case .vendorDefined: "Review the official tool's scope. It may request authorization or affect vendor components; launching it is not confirmed removal."
        case .instructions: "Manual steps only. Macventory does not execute a removal for this plan."
        }
    }
}
public enum ManagedRemovalTarget: Codable, Equatable, Sendable {
    case macPorts(name: String, version: String, prefix: String)
    case nix(profile: String, element: String, storePaths: [String], version: String)
}
/// Created by read-only preparation, bound to this installation and the immutable preview.
public struct ManagedRemovalEvidence: Sendable {
    public let target: ManagedRemovalTarget
    public let itemID: String
    public let executable: String
    public let executableFingerprint: String
    public let stateFingerprint: String
    public let artifacts: [ArtifactObservation]
    public let registryIdentities: [String]
    public let requiresAuthorization: Bool
    public let preparedAt: Date
    public var arguments: [String] {
        switch target {
        case let .macPorts(name, version, _): ["-N", "uninstall", name, "@" + version]
        case let .nix(profile, element, _, _): ["--offline", "profile", "remove", "--profile", profile, "--", element]
        }
    }
}
public struct InteractiveRemovalEvidence: Sendable {
    public let application: String
    public let url: URL
    public let manifest: String
    public let appID: String
    public let payload: String
    public let fingerprint: String
    public let preparedAt: Date
}
public extension UninstallPlan {
    var executionLevel: UninstallExecutionLevel? {
        switch method {
        case .blocked: nil
        case .external: .guided
        case .vendorTool, .steamInteractive: .interactive
        default: .direct
        }
    }
    var isBlocked: Bool { method == .blocked }
    var scope: RemovalScope {
        switch method {
        case .homebrewCask, .homebrewFormula, .macPorts: .managerPackage
        case .nixProfile: .profileElement
        case .trashBundle: .bundleOnly
        case .vendorTool, .steamInteractive: .vendorDefined
        case .external, .blocked: .instructions
        }
    }
    var verificationDescription: String {
        switch method {
        case .homebrewCask, .homebrewFormula, .macPorts: "Requery this manager and exact installation; inspect the reviewed owned artifacts. Exit zero alone is insufficient."
        case .nixProfile: "Requery this exact profile, verify the selected element is absent and all other elements are unchanged. Store paths are expected to remain."
        case .trashBundle: "Verify the original selected bundle path is absent after Finder confirms moving it."
        case .vendorTool: "Await user completion, then inspect the selected application's original path. Other vendor components may remain."
        case .steamInteractive: "Await Steam confirmation, then recheck this exact App ID's library manifest and game payload."
        case .external, .blocked: "Rescan installation status after completing any permitted manual steps."
        }
    }
    var strategyEvidence: [String] {
        ["Source: " + item.primarySource.title, "Target: " + (item.packageID ?? item.bundleID ?? item.id), explanation, scope.description, verificationDescription]
    }
}
