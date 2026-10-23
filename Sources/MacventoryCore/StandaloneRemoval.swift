import Foundation
import AppKit
import Darwin

/// Eligibility concerns bundle-only removal, not the application's unknown download origin.
public struct StandaloneEligibility: Sendable {
    let fingerprint: String
    let configuration: ScanConfiguration
    let roots: [String]
    var simulated = false
}
public protocol StandaloneRemovalChecking: Sendable {
    func check(_ item: SoftwareItem) async throws -> StandaloneEligibility
}

public struct StandaloneRemovalChecker: StandaloneRemovalChecking {
    public let configuration: ScanConfiguration
    public init(configuration: ScanConfiguration = ScanConfiguration()) { self.configuration = configuration }
    public func check(_ item: SoftwareItem) async throws -> StandaloneEligibility {
        let roots = Self.standardRoots
        let before = try Self.inspect(item, roots: roots)
        // A fresh read-only audit, without cached observations or expensive size traversal.
        // Include system receipts too: they must never be mistaken for standalone software.
        var config = configuration
        config.showSystem = true
        config.homebrewPrefixes = Array(Set(config.homebrewPrefixes + ["/opt/homebrew", "/usr/local"]))
        if config.macPortsExecutable != "/opt/local/bin/port", FileSystem.exists("/opt/local/bin/port") {
            throw ScanError.process("Default MacPorts ownership must be checked before Trash; restore its default executable in Settings.")
        }
        if config.nixExecutable != "/nix/var/nix/profiles/default/bin/nix", FileSystem.exists("/nix/var/nix/profiles/default/bin/nix") {
            throw ScanError.process("Default Nix ownership must be checked before Trash; restore its default executable in Settings.")
        }
        let scanners = InventoryService.scanners(configuration: config).filter { ![.unmanaged, .appStore].contains($0.source) }
        let snapshot = await InventoryService().scan(configuration: config, previous: nil, measureSizes: false, scanners: scanners) { _ in }
        try Task.checkCancellation()
        try Self.validateOwnership(item, snapshot: snapshot)
        let after = try Self.inspect(item, roots: roots)
        guard before == after else { throw ScanError.process("The bundle changed during ownership checks. Prepare a new preview.") }
        return StandaloneEligibility(fingerprint: after, configuration: configuration, roots: roots)
    }
    static var standardRoots: [String] { ["/Applications", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path] }
    static let managers: Set<InstallSource> = [.homebrewCask, .homebrewFormula, .pkg, .macPorts, .nix, .setapp, .steam, .toolbox]
    static func validateOwnership(_ item: SoftwareItem, snapshot: InventorySnapshot) throws {
        guard let path = item.path else { throw ScanError.malformed("Missing application path") }
        for source in managers {
            guard let report = snapshot.reports.first(where: { $0.source == source }),
                  [.completed, .empty, .notInstalled].contains(report.state) else {
                throw ScanError.process("Ownership checks for \(source.title) are incomplete. Trash is unavailable.")
            }
        }
        for record in snapshot.observations.values.flatMap({ $0 }) {
            let claims = [record.path].compactMap { $0 } + record.relatedPaths
            if claims.contains(where: { claim in
                let canonical = FileSystem.canonical(claim)
                return canonical == path || canonical.hasPrefix(path + "/") || path.hasPrefix(canonical + "/")
            }) { throw ScanError.process("A package manager or installer claims this bundle. Use its removal workflow.") }
        }
    }
    static func inspect(_ item: SoftwareItem, roots: [String]) throws -> String {
        guard item.primarySource == .unmanaged, !item.sources.isEmpty,
              item.sources.allSatisfy({ $0.source == .unmanaged }), !item.isSystem, item.attributes["Linked discovery"] == nil,
              let path = item.path, path.hasSuffix(".app"), path == FileSystem.canonical(path),
              roots.contains(URL(fileURLWithPath: path).deletingLastPathComponent().path),
              !path.contains(".app/"), !item.stale else {
            throw ScanError.process("Trash requires a standalone bundle directly in /Applications or your Applications folder, with no manager ownership.")
        }
        let fm = FileManager.default
        // lstat every component: do not follow a replaced bundle, ancestor or Info.plist link.
        var component = path
        while component != "/" {
            let attrs = try fm.attributesOfItem(atPath: component)
            guard attrs[.type] as? FileAttributeType == .typeDirectory else { throw ScanError.process("Aliases and symbolic links are not eligible for Trash (\(component)).") }
            component = (component as NSString).deletingLastPathComponent
        }
        let url = URL(fileURLWithPath: path)
        let values = try url.resourceValues(forKeys: [.isAliasFileKey, .volumeIsLocalKey, .volumeIsReadOnlyKey])
        guard values.isAliasFile != true, values.volumeIsLocal == true, values.volumeIsReadOnly != true else { throw ScanError.process("Only local writable application bundles are supported.") }
        let attributes = try fm.attributesOfItem(atPath: path)
        let flags = (attributes[.immutable] as? Bool) == true || (attributes[.appendOnly] as? Bool) == true
        guard !flags, fm.isWritableFile(atPath: url.deletingLastPathComponent().path),
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid() else { throw ScanError.process("This bundle requires permissions Macventory will not request. Remove it manually in Finder if appropriate.") }
        let infoPath = path + "/Contents/Info.plist"
        let contents = try fm.attributesOfItem(atPath: path + "/Contents")
        let infoAttributes = try fm.attributesOfItem(atPath: infoPath)
        guard contents[.type] as? FileAttributeType == .typeDirectory,
              infoAttributes[.type] as? FileAttributeType == .typeRegular,
              (infoAttributes[.size] as? NSNumber)?.intValue ?? Int.max <= 4 * 1024 * 1024,
              infoPath == FileSystem.canonical(infoPath) else { throw ScanError.process("Bundle metadata is not a regular local file.") }
        let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: infoPath)), format: nil) as? [String: Any] ?? [:]
        guard info["CFBundlePackageType"] as? String == "APPL", let id = info["CFBundleIdentifier"] as? String,
              !id.isEmpty, id == item.bundleID, !id.hasPrefix("com.apple."), id != "org.vadimtanel.Macventory",
              let executable = info["CFBundleExecutable"] as? String, !executable.isEmpty,
              executable != ".", executable != "..", !executable.contains("/"),
              info["SMPrivilegedExecutables"] == nil, info["SMLoginItem"] == nil else { throw ScanError.process("Bundle identity, executable or standalone status could not be validated.") }
        for marker in ["Contents/_MASReceipt", "Contents/Library/LaunchDaemons", "Contents/Library/LaunchAgents", "Contents/Library/LoginItems", "Contents/Library/HelperTools", "Contents/Library/SystemExtensions", "Contents/Library/DriverExtensions", "Contents/Library/Extensions", "Contents/Frameworks/Setapp.framework", "Contents/Resources/.toolbox"] {
            do {
                _ = try fm.attributesOfItem(atPath: path + "/" + marker)
                throw ScanError.process("Store, provider or external service components require their source/vendor workflow (\(marker)).")
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) { /* absent marker */ }
        }
        let binary = path + "/Contents/MacOS/" + executable
        let binaryAttributes = try fm.attributesOfItem(atPath: binary)
        guard binaryAttributes[.type] as? FileAttributeType == .typeRegular, binary == FileSystem.canonical(binary),
              fm.isExecutableFile(atPath: binary) else { throw ScanError.process("The application executable is missing, linked or unsupported.") }
        let parent = try fm.attributesOfItem(atPath: url.deletingLastPathComponent().path)
        return try UninstallPlanner.fingerprint(item) + "|\(parent[.systemNumber] ?? "")|\(parent[.systemFileNumber] ?? "")" + "|\(binaryAttributes[.systemNumber] ?? "")|\(binaryAttributes[.systemFileNumber] ?? "")|\(binaryAttributes[.size] ?? "")|\((binaryAttributes[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0)|\((attributes[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0)"
    }
}

/// Synthetic QA can inject this checker with disposable roots; the production executor
/// always constructs its own standard-root checker and never accepts QA roots.
public struct SimulatedStandaloneChecker: StandaloneRemovalChecking {
    private let roots: [String]
    public init(roots: [String]) { self.roots = roots.map(FileSystem.canonical) }
    public func check(_ item: SoftwareItem) async throws -> StandaloneEligibility {
        try Task.checkCancellation()
        return StandaloneEligibility(fingerprint: try StandaloneRemovalChecker.inspect(item, roots: roots), configuration: ScanConfiguration(), roots: roots, simulated: true)
    }
}
