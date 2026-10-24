import Foundation
import AppKit
import CryptoKit
import Darwin

public protocol ManagedRemovalBoundary: Sendable {
    func query(_ command: InventoryCommand) async throws -> Data
    func remove(_ evidence: ManagedRemovalEvidence) async throws -> Int32
}
public protocol ManagedRemovalSecurity: Sendable {
    func executableFingerprint(_ executable: String, source: InstallSource) throws -> String
    func profileFingerprint(_ profile: String) throws -> String
    func requiresAuthorization(prefix: String) throws -> Bool
}
public enum RemovalIdentity {
    public static func portName(_ value: String) -> Bool {
        let reserved: Set<String> = ["all", "active", "inactive", "installed", "uninstalled", "outdated", "obsolete", "requested", "unrequested", "leaves", "rleaves", "current"]
        return token(value) && !reserved.contains(value)
    }
    public static func token(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 200 && value.first?.isLetter == true && value.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [45, 95, 46, 43].contains($0) } && !value.contains("..")
    }
    public static func portVersion(_ value: String) -> Bool {
        !value.isEmpty && value.count < 200 && value.first?.isNumber == true && value.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [45, 95, 46, 43].contains($0) } && !value.contains("..")
    }
    public static func nixElement(_ value: String) -> Bool {
        token(value) && !value.contains(".") && !value.contains("+") // Never a regex, path, option or numeric index.
    }
    public static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public static func canonicalJSON(_ data: Data) throws -> Data {
        try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: data), options: [.sortedKeys])
    }
    public static func executableDigest(_ path: String) throws -> String {
        let canonical = FileSystem.canonical(path), attributes = try FileManager.default.attributesOfItem(atPath: canonical)
        guard attributes[.type] as? FileAttributeType == .typeRegular, (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 256 * 1024 * 1024 else { throw ScanError.process("Manager executable is not a bounded regular file") }
        let file = try FileHandle(forReadingFrom: URL(fileURLWithPath: canonical)); defer { try? file.close() }
        var hash = SHA256()
        while let data = try file.read(upToCount: 65_536), !data.isEmpty { hash.update(data: data) }
        return canonical + "|\(attributes[.systemNumber] ?? "")|\(attributes[.systemFileNumber] ?? "")|" + hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
public struct LiveManagedRemovalSecurity: ManagedRemovalSecurity {
    public init() {}
    public func executableFingerprint(_ executable: String, source: InstallSource) throws -> String {
        let resolved = FileSystem.canonical(executable)
        switch source {
        case .macPorts:
            guard executable == "/opt/local/bin/port", resolved == executable,
                  FileSystem.exists("/opt/local/etc/macports/macports.conf"), FileSystem.exists("/opt/local/share/macports/Tcl/macports1.0/macports.tcl") else { throw ScanError.process("This MacPorts executable/prefix has not been verified for execution") }
        case .nix:
            guard URL(fileURLWithPath: resolved).lastPathComponent == "nix", resolved.hasPrefix("/nix/store/"), resolved.contains("/bin/nix") else { throw ScanError.process("Nix must resolve to its root-owned installed store executable") }
        default: throw ScanError.process("Unsupported manager")
        }
        if source == .macPorts {
            for anchor in ["/opt/local/etc/macports/macports.conf", "/opt/local/share/macports/Tcl/macports1.0/macports.tcl"] {
                let a = try FileManager.default.attributesOfItem(atPath: anchor)
                guard FileSystem.canonical(anchor) == anchor, a[.type] as? FileAttributeType == .typeRegular,
                      (a[.ownerAccountID] as? NSNumber)?.uint32Value == 0,
                      ((a[.posixPermissions] as? NSNumber)?.intValue ?? 0o777) & 0o022 == 0 else { throw ScanError.process("MacPorts configuration/library ownership is unsafe") }
            }
        }
        guard FileManager.default.isExecutableFile(atPath: resolved) else { throw ScanError.process("Manager executable is missing") }
        var path = resolved
        while path != "/" {
            let a = try FileManager.default.attributesOfItem(atPath: path)
            let owner = (a[.ownerAccountID] as? NSNumber)?.uint32Value ?? UInt32.max
            let mode = (a[.posixPermissions] as? NSNumber)?.intValue ?? 0o777
            guard Self.permitsOwnership(path: path, source: source, owner: owner, mode: mode, group: a[.groupOwnerAccountName] as? String) else { throw ScanError.process("Manager installation has unsafe ownership or writable components") }
            path = (path as NSString).deletingLastPathComponent
        }
        return try RemovalIdentity.executableDigest(executable)
    }
    public static func permitsOwnership(path: String, source: InstallSource, owner: UInt32, mode: Int, group: String?) -> Bool {
        guard owner == 0 || (source == .nix && owner == getuid()), mode & 0o002 == 0 else { return false }
        // The official multi-user store is sticky and group-writable by build users;
        // every package directory and executable above it must still be non-writable.
        return mode & 0o020 == 0 || (source == .nix && path == "/nix/store" && owner == 0 && group == "nixbld" && mode & 0o1000 != 0)
    }
    public func profileFingerprint(_ profile: String) throws -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let roots = [home + "/.local/state/nix/profiles", "/nix/var/nix/profiles/per-user/" + NSUserName()]
        guard profile == URL(fileURLWithPath: profile).standardizedFileURL.path,
              roots.contains((profile as NSString).deletingLastPathComponent), RemovalIdentity.token(URL(fileURLWithPath: profile).lastPathComponent) else { throw ScanError.process("Only an exact current-user mutable profile slot is supported; system/declarative profiles are excluded") }
        let parent = (profile as NSString).deletingLastPathComponent
        guard FileSystem.canonical(parent) == parent, FileManager.default.isWritableFile(atPath: parent) else { throw ScanError.process("Profile directory is linked, inaccessible or not user-writable") }
        let parentAttributes = try FileManager.default.attributesOfItem(atPath: parent)
        guard (parentAttributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(), ((parentAttributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o777) & 0o022 == 0 else { throw ScanError.process("Profile directory ownership or permissions are unsafe") }
        let a = try FileManager.default.attributesOfItem(atPath: profile)
        guard a[.type] as? FileAttributeType == .typeSymbolicLink, (a[.ownerAccountID] as? NSNumber)?.uint32Value == getuid() else { throw ScanError.process("The profile slot is not a user-owned mutable profile link") }
        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: profile)
        let generation = destination.hasPrefix("/") ? URL(fileURLWithPath: destination).standardizedFileURL.path : URL(fileURLWithPath: parent).appendingPathComponent(destination).standardizedFileURL.path
        guard (generation as NSString).deletingLastPathComponent == parent, URL(fileURLWithPath: generation).lastPathComponent.hasPrefix(URL(fileURLWithPath: profile).lastPathComponent + "-"), generation.hasSuffix("-link") else { throw ScanError.process("The profile is not a mutable generation slot; declarative links require their configuration workflow") }
        let slotName = URL(fileURLWithPath: profile).lastPathComponent
        let generationName = URL(fileURLWithPath: generation).lastPathComponent
        let number = generationName.dropFirst(slotName.count + 1).dropLast("-link".count)
        guard !number.isEmpty, number.allSatisfy(\.isNumber) else { throw ScanError.process("Profile generation is not a numbered mutable generation") }
        let g = try FileManager.default.attributesOfItem(atPath: generation)
        guard g[.type] as? FileAttributeType == .typeSymbolicLink, (g[.ownerAccountID] as? NSNumber)?.uint32Value == getuid() else { throw ScanError.process("Profile generation ownership changed") }
        let store = FileSystem.canonical(profile)
        guard store.hasPrefix("/nix/store/") else { throw ScanError.process("Profile does not reference a Nix generation") }
        let manifest = try FileSystem.json(store + "/manifest.json", limit: 16 * 1024 * 1024)
        guard (manifest["version"] as? Int) == 3, manifest["elements"] is [String: Any] else { throw ScanError.process("Only named modern mutable profiles (manifest v3) are supported") }
        return profile + "|\(a[.systemFileNumber] ?? "")|" + destination + "|" + store
    }
    public func requiresAuthorization(prefix: String) throws -> Bool {
        guard prefix == "/opt/local" else { throw ScanError.process("Unsupported MacPorts prefix") }
        let required = !FileManager.default.isWritableFile(atPath: prefix + "/var/macports/registry")
        if required && !MacPortsAuthorization.isPackagedAndSigned { throw ScanError.process("This root-owned port requires the signed Macventory app and matching embedded authorization helper. This build cannot request that privileged operation safely.") }
        return required
    }
}
public struct ManagedRemovalAdapter: UninstallExecuting {
    public let boundary: any ManagedRemovalBoundary
    public let security: any ManagedRemovalSecurity
    public init(boundary: any ManagedRemovalBoundary = LiveManagedRemovalBoundary(), security: any ManagedRemovalSecurity = LiveManagedRemovalSecurity()) { self.boundary = boundary; self.security = security }
    public func prepare(_ item: SoftwareItem) async throws -> ManagedRemovalEvidence {
        guard !item.stale, [.macPorts, .nix].contains(item.primarySource), item.confidence == .verified else { throw ScanError.process("Fresh verified manager ownership is required") }
        guard let executable = item.attributes["Manager executable"] else { throw ScanError.process("The exact manager executable is missing; refresh this source") }
        let executableFingerprint = try security.executableFingerprint(executable, source: item.primarySource)
        if item.primarySource == .macPorts {
            guard let name = item.packageID, RemovalIdentity.portName(name), let version = item.attributes["MacPorts version"] ?? item.version, RemovalIdentity.portVersion(version), let prefix = item.attributes["Prefix"], executable == prefix + "/bin/port" else { throw ScanError.process("Exact installed port version/variants and prefix are required") }
            let installed = try await boundary.query(.ports(executable: executable))
            let records = try MacPortsScanner.parse(String(decoding: installed, as: UTF8.self), prefix: prefix)
            guard records.contains(where: { $0.packageID == name && $0.version == version }) else { throw ScanError.process("The selected port/version is no longer installed") }
            let dependents = String(decoding: try await boundary.query(.portDependents(executable: executable, name: name, version: version)), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            guard dependents.isEmpty || dependents == "\(name) has no dependents." else { throw ScanError.process("Installed dependents or an unrecognized dependency response block this removal. No dependents will be removed.") }
            let data = try await boundary.query(.portExactContents(executable: executable, name: name, version: version))
            let paths = String(decoding: data, as: UTF8.self).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("/") }
            guard paths.count <= 100_000, paths.allSatisfy({ !$0.split(separator: "/").contains("..") && !ProtectionPolicy.protectedPath($0) }) else { throw ScanError.process("Port payload includes unsafe or protected paths") }
            guard !paths.contains(where: { path in ["/LaunchDaemons/", "/LaunchAgents/", "/Extensions/", "/SystemExtensions/", "/PrivilegedHelperTools/"].contains(where: path.contains) }) else { throw ScanError.process("This port owns service/extension components requiring an individually reviewed manager workflow") }
            let apps = Set(paths.compactMap { path -> String? in
                if let range = path.range(of: ".app/") { return String(path[..<range.lowerBound]) + ".app" }
                return path.hasSuffix(".app") ? path : nil
            })
            let artifacts = apps.isEmpty ? paths.filter { (try? FileManager.default.attributesOfItem(atPath: $0)[.type] as? FileAttributeType) != .typeDirectory }.prefix(64).map(ArtifactObservation.inspect) : apps.sorted().map(ArtifactObservation.inspect)
            guard !ProtectionPolicy.isRunningCopy(artifacts.map(\.path)), !artifacts.contains(where: { [.brokenLink, .inaccessible].contains($0.presence) }) else { throw ScanError.process("Owned artifacts are linked, inaccessible or include the running Macventory copy") }
            let authorization = try security.requiresAuthorization(prefix: prefix)
            let state = RemovalIdentity.digest(installed + data + Data((name + "|" + version + "|" + executableFingerprint).utf8))
            return ManagedRemovalEvidence(target: .macPorts(name: name, version: version, prefix: prefix), itemID: item.id, executable: executable, executableFingerprint: executableFingerprint, stateFingerprint: state, artifacts: artifacts, registryIdentities: records.map(\.id).sorted(), requiresAuthorization: authorization, preparedAt: Date())
        }
        guard let profile = item.attributes["Nix profile"], item.attributes["Nix profile mode"] == "modern-mutable", let element = item.packageID, RemovalIdentity.nixElement(element) else { throw ScanError.process("Exact named mutable profile evidence is unavailable; legacy/declarative profiles require their own workflow") }
        let profileIdentity = try security.profileFingerprint(profile)
        let version = String(decoding: try await boundary.query(.managerVersion(executable: executable)), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.supportsNix(version) else { throw ScanError.process("This Nix version is outside the supported named-profile removal contract (2.28–2.35)") }
        let data = try await boundary.query(.nix(executable: executable, profile: profile)), state = try Self.nixElements(data)
        guard let paths = state[element], !paths.isEmpty, item.path.map(paths.contains) ?? true else { throw ScanError.process("Selected Nix element or outputs changed") }
        let digest = RemovalIdentity.digest(try RemovalIdentity.canonicalJSON(data) + Data((profileIdentity + "|" + executableFingerprint + "|" + version).utf8))
        return .init(target: .nix(profile: profile, element: element, storePaths: paths, version: version), itemID: item.id, executable: executable, executableFingerprint: executableFingerprint, stateFingerprint: digest, artifacts: paths.map(ArtifactObservation.inspect), registryIdentities: state.keys.sorted(), requiresAuthorization: false, preparedAt: Date())
    }
    public static func supportsNix(_ version: String) -> Bool {
        let words = version.split(whereSeparator: \.isWhitespace)
        guard words.count == 3, words[0] == "nix", words[1] == "(Nix)" else { return false }
        let numbers = words[2].split(separator: ".")
        return numbers.count >= 2 && numbers[0] == "2" && Int(numbers[1]).map { (28...35).contains($0) } == true
    }
    public static func nixElements(_ data: Data) throws -> [String: [String]] {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let elements = object?["elements"] as? [String: [String: Any]], elements.count <= 20_000 else { throw ScanError.malformed("Named modern Nix profile JSON required") }
        var result: [String: [String]] = [:]
        for (key, record) in elements {
            guard RemovalIdentity.nixElement(key), let paths = record["storePaths"] as? [String], !paths.isEmpty, paths.allSatisfy({ $0.hasPrefix("/nix/store/") && !$0.dropFirst("/nix/store/".count).contains("/") && !$0.contains("..") }) else { throw ScanError.malformed("Unsupported Nix element identity or output") }
            result[key] = paths.sorted()
        }
        return result
    }
    private static func nixRecordSignatures(_ data: Data) throws -> [String: String] {
        _ = try nixElements(data)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let elements = object["elements"] as! [String: Any]
        return try elements.mapValues { digest in RemovalIdentity.digest(try JSONSerialization.data(withJSONObject: digest, options: [.sortedKeys])) }
    }
    public func validate(_ plan: UninstallPlan) async throws {
        guard let proof = plan.managerEvidence, proof.itemID == plan.item.id, plan.executable == proof.executable, plan.arguments == proof.arguments,
              plan.fingerprint == proof.stateFingerprint, (0..<300).contains(Date().timeIntervalSince(plan.createdAt)) else { throw ScanError.process("Invalid or expired exact manager plan") }
        let fresh = try await prepare(plan.item)
        guard fresh.target == proof.target, fresh.executableFingerprint == proof.executableFingerprint, fresh.stateFingerprint == proof.stateFingerprint, fresh.requiresAuthorization == proof.requiresAuthorization else { throw ScanError.process("Manager, profile, version, dependencies or installation changed. Prepare a new confirmation.") }
    }
    public func execute(_ plan: UninstallPlan) async throws -> UninstallOutcome {
        try await validate(plan)
        guard let proof = plan.managerEvidence else { throw ScanError.process("Missing manager proof") }
        var beforeNix: [String: String]?
        if case let .nix(profile, _, _, _) = proof.target { beforeNix = try await Self.nixRecordSignatures(boundary.query(.nix(executable: proof.executable, profile: profile))) }
        if proof.target.source == .macPorts {
            let running = await MainActor.run { NSWorkspace.shared.runningApplications.contains { app in
                app.bundleURL.map { url in proof.artifacts.contains { FileSystem.contained(url.path, in: $0.path) } } == true
            } }
            guard !running else { throw ScanError.process("Quit the selected port's owned applications before uninstalling") }
        }
        try Task.checkCancellation()
        let exit = try await boundary.remove(proof)
        if exit == LiveManagedRemovalBoundary.authorizationPending { return proof.requiresAuthorization && proof.target.source == .macPorts ? .authorizationRequired : .unknownResult }
        do {
            switch proof.target {
            case let .macPorts(name, version, prefix):
                let data = try await boundary.query(.ports(executable: proof.executable))
                let records = try MacPortsScanner.parse(String(decoding: data, as: UTF8.self), prefix: prefix)
                let selected = records.first { $0.packageID == name && $0.version == version }
                let selectedID = SoftwareItem.identity(path: nil, source: .macPorts, packageID: name) + ":" + version
                guard records.filter({ $0.id != selectedID }).map(\.id).sorted() == proof.registryIdentities.filter({ $0 != selectedID }) else { return .partialRemoval }
                let installed = selected != nil
                return RemovalVerification.managerOutcome(installed: installed, artifacts: proof.artifacts.map { ArtifactObservation.inspect($0.path) }, exitCode: exit)
            case let .nix(profile, element, _, _):
                _ = try security.profileFingerprint(profile)
                let afterData = try await boundary.query(.nix(executable: proof.executable, profile: profile))
                let after = try Self.nixElements(afterData)
                var others = beforeNix ?? [:]; others.removeValue(forKey: element)
                var remaining = try Self.nixRecordSignatures(afterData); remaining.removeValue(forKey: element)
                guard remaining == others else { return .partialRemoval }
                guard after[element] == nil else { return exit == 0 ? .partialRemoval : .failed }
                return exit == 0 ? .packageRegistrationRemoved : .partialRemoval
            }
        } catch { return .unknownResult }
    }
}
public struct LiveManagedRemovalBoundary: ManagedRemovalBoundary {
    public static let authorizationPending: Int32 = -7
    public init() {}
    public func query(_ command: InventoryCommand) async throws -> Data { try await ProcessRunner().run(command) }
    public func remove(_ evidence: ManagedRemovalEvidence) async throws -> Int32 {
        _ = try LiveManagedRemovalSecurity().executableFingerprint(evidence.executable, source: evidence.target.source)
        if evidence.requiresAuthorization { return try await MacPortsAuthorization.execute(evidence) }
        return try await RemovalProcess.run(executable: evidence.executable, arguments: evidence.arguments)
    }
}
public extension ManagedRemovalTarget {
    var source: InstallSource { switch self { case .macPorts: .macPorts; case .nix: .nix } }
}
/// Internal typed adapters supply arguments. This boundary never accepts a shell or password.
public enum RemovalProcess {
    static func run(executable: String, arguments: [String], timeout: Duration = .seconds(120)) async throws -> Int32 {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.environment = ["HOME": FileManager.default.homeDirectoryForCurrentUser.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8", "NIX_PATH": "", "NIX_CONFIG": "connect-timeout = 1\n"]
        process.standardInput = FileHandle.nullDevice; process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try Task.checkCancellation(); try process.run()
        let deadline = ContinuousClock.now.advanced(by: timeout)
        do {
            while process.isRunning {
                try Task.checkCancellation()
                guard ContinuousClock.now < deadline else { throw ScanError.timeout }
                try await Task.sleep(for: .milliseconds(30))
            }
            return process.terminationStatus
        } catch {
            if process.isRunning { process.terminate() }
            throw ScanError.process("Manager operation interrupted; changes may be partial. Refresh and prepare a new review. " + error.localizedDescription)
        }
    }
}
