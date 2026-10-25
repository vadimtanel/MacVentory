import Foundation
import AppKit
import Security

public protocol SteamClientChecking: Sendable {
    func validateRoot(_ root: String) throws
    func clientPath() throws -> String
    func fingerprint(_ path: String) throws -> String
}
public struct SignedSteamClientChecker: SteamClientChecking {
    public init() {}
    public func validateRoot(_ root: String) throws {
        guard root == FileSystem.canonical("~/Library/Application Support/Steam") else { throw ScanError.process("The selected library is not associated with this user's verified Steam data root") }
    }
    public func clientPath() throws -> String {
        for path in ["/Applications/Steam.app", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Steam.app").path] {
            if (try? fingerprint(path)) != nil { return path }
        }
        throw ScanError.process("A signed Valve Steam client with steam URL support is required for the targeted handoff")
    }
    public func fingerprint(_ path: String) throws -> String {
        guard path == FileSystem.canonical(path), let bundle = Bundle(path: path), bundle.bundleIdentifier == "com.valvesoftware.steam",
              (bundle.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]])?.contains(where: { ($0["CFBundleURLSchemes"] as? [String])?.contains("steam") == true }) == true,
              SignedVendorIdentityChecker().teamIdentifier(at: path) == "MXGJJ98X76" else { throw ScanError.process("Steam publisher, bundle or URL support could not be verified") }
        return try VendorUninstallerDiscovery.fingerprint(path: path, team: "MXGJJ98X76")
    }
}
public protocol InteractiveRemovalOpening: Sendable {
    func open(application: String, url: URL) async throws
}
public struct NativeInteractiveRemovalOpening: InteractiveRemovalOpening {
    public init() {}
    @MainActor public func open(application: String, url: URL) async throws {
        let config = ExactApplicationLaunch.configuration()
        let opened = try await NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: application), configuration: config)
        guard opened.bundleURL.map({ FileSystem.canonical($0.path) }) == application else { throw ScanError.process("Steam launch returned another physical installation; outcome unknown") }
    }
}
public struct SteamRemovalAdapter: UninstallExecuting {
    public let client: any SteamClientChecking
    public let opener: any InteractiveRemovalOpening
    public init(client: any SteamClientChecking = SignedSteamClientChecker(), opener: any InteractiveRemovalOpening = NativeInteractiveRemovalOpening()) { self.client = client; self.opener = opener }
    public func prepare(_ item: SoftwareItem) throws -> InteractiveRemovalEvidence {
        guard item.primarySource == .steam, !item.stale, let id = item.packageID, let number = UInt32(id), number > 0, String(number) == id,
              let library = item.attributes["Steam library"], library.hasPrefix("/"), let manifest = item.attributes["Steam manifest"], manifest == library + "/steamapps/appmanifest_" + id + ".acf", FileSystem.canonical(manifest) == manifest,
              let record = try KeyValues.parse(FileSystem.text(manifest))["AppState"]?.object, record["appid"]?.text == id,
              let directory = record["installdir"]?.text, !directory.isEmpty else { throw ScanError.process("Exact Steam App ID and library manifest are not verified") }
        let payload = URL(fileURLWithPath: library + "/steamapps/common").appendingPathComponent(directory).standardizedFileURL.path
        guard FileSystem.contained(payload, in: library + "/steamapps/common"), !ProtectionPolicy.isRunningCopy([payload]),
              item.path == nil || FileSystem.canonical(payload) == item.path else { throw ScanError.process("Steam library/target changed") }
        guard let root = item.attributes["Steam root"] else { throw ScanError.process("Steam data-root evidence is missing") }
        try client.validateRoot(root)
        let index = root + "/steamapps/libraryfolders.vdf"
        guard FileSystem.canonical(index) == index, let folders = try KeyValues.parse(FileSystem.text(index))["libraryfolders"]?.object else { throw ScanError.process("Steam's active library index could not be verified") }
        var libraries = Set([root])
        for value in folders.values {
            if let path = value.object?["path"]?.text ?? value.text, path.hasPrefix("/") { libraries.insert(FileSystem.canonical(path)) }
        }
        guard libraries.count <= 128 else { throw ScanError.limit("Too many Steam libraries for targeted review") }
        guard libraries.contains(library) else { throw ScanError.process("The selected Steam library is no longer registered") }
        var matches: [String] = []
        for candidate in libraries {
            let observation = ArtifactObservation.inspect(candidate + "/steamapps/appmanifest_" + id + ".acf")
            if observation.presence == .inaccessible || observation.presence == .brokenLink { throw ScanError.process("Another registered Steam library is unverified; the App ID cannot be safely targeted") }
            if observation.presence == .present { matches.append(observation.path) }
        }
        guard matches == [manifest] else { throw ScanError.process("Steam has multiple physical manifests for this App ID. Its uninstall URI cannot select a library; review the correct copy in Steam.") }
        let application = try client.clientPath(), appFingerprint = try client.fingerprint(application)
        // Valve's documented Steam Browser Protocol. Only a numeric ID can enter this URI.
        let url = URL(string: "steam://uninstall/" + id)!
        let fingerprint = RemovalIdentity.digest(try Data(contentsOf: URL(fileURLWithPath: manifest)) + Data(contentsOf: URL(fileURLWithPath: index)) + Data((payload + "|" + appFingerprint + "|" + (try RemovalIdentity.artifactFingerprint([manifest, index, payload]))).utf8))
        return .init(application: application, url: url, manifest: manifest, appID: id, payload: payload, fingerprint: fingerprint, preparedAt: Date())
    }
    public func validate(_ plan: UninstallPlan) throws {
        guard plan.method == .steamInteractive, let proof = plan.interactiveEvidence,
              (0..<300).contains(Date().timeIntervalSince(plan.createdAt)) else { throw ScanError.process("Interactive preview expired") }
        let fresh = try prepare(plan.item)
        guard proof.application == fresh.application, proof.url == fresh.url, proof.manifest == fresh.manifest, proof.payload == fresh.payload, proof.fingerprint == fresh.fingerprint, plan.fingerprint == fresh.fingerprint else { throw ScanError.process("Steam client or exact library target changed") }
    }
    public func execute(_ plan: UninstallPlan) async throws -> UninstallOutcome {
        try validate(plan); try Task.checkCancellation()
        guard let proof = plan.interactiveEvidence else { throw ScanError.process("Missing handoff evidence") }
        try await opener.open(application: proof.application, url: proof.url)
        return .waitingForUser
    }
    public static func verify(_ plan: UninstallPlan) -> UninstallOutcome {
        guard let proof = plan.interactiveEvidence else { return .unknownResult }
        let manifest = ArtifactObservation.inspect(proof.manifest), payload = ArtifactObservation.inspect(proof.payload)
        if [manifest, payload].contains(where: { $0.presence == .inaccessible }) { return .unknownResult }
        if manifest.presence == .missing && payload.presence == .missing {
            guard let root = plan.item.attributes["Steam root"], let folders = try? KeyValues.parse(FileSystem.text(root + "/steamapps/libraryfolders.vdf"))["libraryfolders"]?.object else { return .unknownResult }
            if folders.values.contains(where: { $0.object?["apps"]?.object?[proof.appID] != nil }) { return .partialRemoval }
            var libraries = Set([root])
            for value in folders.values {
                if let path = value.object?["path"]?.text ?? value.text, path.hasPrefix("/") { libraries.insert(FileSystem.canonical(path)) }
            }
            guard libraries.count <= 128 else { return .unknownResult }
            for library in libraries {
                guard ArtifactObservation.inspect(library).presence == .present else { return .unknownResult }
                switch ArtifactObservation.inspect(library + "/steamapps/appmanifest_" + proof.appID + ".acf").presence {
                case .present, .brokenLink: return .partialRemoval
                case .inaccessible: return .unknownResult
                case .missing: break
                }
            }
            return .verifiedRemoved
        }
        if manifest.presence == .missing || payload.presence == .missing { return .partialRemoval }
        return .waitingForUser
    }
}
public enum InteractiveRemovalVerification {
    public static func verify(_ plan: UninstallPlan) -> UninstallOutcome {
        if plan.method == .steamInteractive { return SteamRemovalAdapter.verify(plan) }
        guard plan.method == .vendorTool, let path = plan.item.path else { return .unknownResult }
        switch ArtifactObservation.inspect(path).presence {
        case .missing: return .appBundleRemoved
        case .inaccessible: return .unknownResult
        case .brokenLink: return .partialRemoval
        case .present: return .waitingForUser
        }
    }
}
