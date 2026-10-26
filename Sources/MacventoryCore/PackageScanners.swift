import Foundation

public struct PKGScanner: SoftwareScanner {
    public let source: InstallSource = .pkg
    public var runner: any CommandRunning
    public var includeSystem: Bool
    public init(runner: any CommandRunning = ProcessRunner(), includeSystem: Bool = false) { self.runner = runner; self.includeSystem = includeSystem }
    public func scan() async throws -> ScanResult {
        let ids = String(decoding: try await runner.run(.receipts), as: UTF8.self).split(separator: "\n").map(String.init)
        guard ids.count <= 3000 else { throw ScanError.limit("Receipt count exceeds audit limit") }
        var items: [SoftwareItem] = [], warnings: [String] = []
        for id in ids.prefix(3000) where includeSystem || !id.hasPrefix("com.apple.") {
            try Task.checkCancellation()
            do {
                let data = try await runner.run(.receiptInfo(id))
                guard let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { throw ScanError.malformed("Invalid receipt plist") }
                let volume = info["volume"] as? String ?? "/"
                let location = info["install-location"] as? String ?? ""
                let installRoot = URL(fileURLWithPath: volume).appendingPathComponent(location).path
                let files = String(decoding: try await runner.run(.receiptFiles(id)), as: UTF8.self).split(separator: "\n")
                guard files.count <= 100_000 else { throw ScanError.limit("Receipt payload exceeds audit limit") }
                var apps = Set<String>(), existing = 0
                for file in files.prefix(100_000) {
                    let candidate = URL(fileURLWithPath: installRoot).appendingPathComponent(String(file)).standardizedFileURL.path
                    guard FileSystem.contained(candidate, in: volume) else { continue }
                    if FileSystem.exists(candidate) { existing += 1 }
                    if installRoot.lowercased().hasSuffix(".app") { apps.insert(installRoot) }
                    else if let range = candidate.range(of: ".app/", options: .caseInsensitive) { apps.insert(String(candidate[..<range.lowerBound]) + ".app") }
                    else if candidate.lowercased().hasSuffix(".app") { apps.insert(candidate) }
                }
                var matched = false
                for path in apps.sorted() where FileSystem.exists(path) {
                    guard var item = try? NativeScanner.item(at: path) else { continue }
                    matched = true
                    item.packageID = id; item.primarySource = .pkg
                    item.sources = [.init(.pkg, Evidence("pkgutil receipt " + id + " and existing application payload"))]
                    item.attributes["Receipt version"] = info["pkg-version"] as? String ?? "Unknown"
                    item.installedAt = FileSystem.date(info["install-time"])
                    item.evidence["installedAt"] = Evidence("pkgutil install-time", availability: item.installedAt == nil ? .notAvailable : .available, explanation: "Receipt installation event; not necessarily first installation")
                    items.append(item)
                }
                if !matched {
                    var item = SoftwareItem(name: id, kind: .package, source: .pkg, packageID: id, evidence: Evidence("pkgutil receipt", explanation: "Receipt records an installer event, not proof all payload files remain"))
                    item.version = info["pkg-version"] as? String
                    item.isSystem = ProtectionPolicy.protectedPath(installRoot)
                    item.installedAt = FileSystem.date(info["install-time"])
                    item.evidence["installedAt"] = Evidence("pkgutil install-time", availability: item.installedAt == nil ? .notAvailable : .available)
                    item.attributes["Payload"] = existing == 0 ? "Receipt only; no existing payload verified" : "\(existing) existing paths; package footprint not measured"
                    item.attributes["Recorded location"] = installRoot
                    let payload = apps.sorted().map(ArtifactObservation.inspect)
                    item.health = .init(payload.contains { $0.presence == .inaccessible } ? .unverified : .historical, "Receipt records an installer event; payload is not an installed application. " + (item.attributes["Payload"] ?? ""), registration: .receiptOnly, artifacts: payload)
                    items.append(item)
                }
            } catch is CancellationError { throw CancellationError() }
            catch { warnings.append(id + ": " + error.localizedDescription) }
        }
        return ScanResult(source, items: items, state: warnings.isEmpty ? nil : .failed, message: warnings.joined(separator: "; "))
    }
}

public struct MacPortsScanner: SoftwareScanner {
    public let source: InstallSource = .macPorts
    public var executable: String
    public var runner: any CommandRunning
    public init(executable: String = "/opt/local/bin/port", runner: any CommandRunning = ProcessRunner()) { self.executable = executable; self.runner = runner }
    public func scan() async throws -> ScanResult {
        let executablePresence = ArtifactObservation.inspect(executable).presence
        if executablePresence == .inaccessible { throw ScanError.permission }
        if executablePresence == .brokenLink { return ScanResult(source, state: .unsupported, message: "Manager executable link is broken") }
        guard executablePresence == .present else { return ScanResult(source, state: .notInstalled) }
        let text = String(decoding: try await runner.run(.ports(executable: executable)), as: UTF8.self)
        var items = try Self.parse(text, prefix: URL(fileURLWithPath: executable).deletingLastPathComponent().deletingLastPathComponent().path)
        for index in items.indices {
            try Task.checkCancellation()
            // Contents are evidence, not a reason to count the entire shared prefix as one package.
            if let id = items[index].packageID, items[index].attributes["Active"] == "Yes" {
                let data = try await runner.run(.portContents(executable: executable, name: id))
                let paths = String(decoding: data, as: UTF8.self).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("/") && !$0.split(separator: "/").contains("..") }
                guard paths.count <= 100_000 else { throw ScanError.limit("MacPorts payload exceeds inspection limit") }
                items[index].relatedPaths = paths.filter(FileSystem.exists)
                let apps = Set(paths.compactMap { path -> String? in
                    if let range = path.range(of: ".app/") { return String(path[..<range.lowerBound]) + ".app" }
                    return path.hasSuffix(".app") ? path : nil
                })
                items[index].health = InstallationHealthClassifier.classify(items[index], registration: .installed, artifacts: apps.sorted().map(ArtifactObservation.inspect))
                for app in apps.sorted() {
                    if var application = try? NativeScanner.item(at: app) {
                        application.sources = items[index].sources; application.primarySource = .macPorts
                        application.packageID = id; application.attributes.merge(items[index].attributes) { current, _ in current }; items.append(application)
                    }
                }
            }
        }
        return ScanResult(source, items: items, message: "Documented port installed/contents queries; shared package footprints are not summed")
    }
    public static func parse(_ text: String, prefix: String) throws -> [SoftwareItem] {
        var items: [SoftwareItem] = []
        for line in text.split(separator: "\n") {
            let fields = line.split(whereSeparator: \.isWhitespace)
            if fields.isEmpty || line.contains("No ports are installed") { continue }
            guard fields.count >= 2, fields[1].hasPrefix("@"), FileSystem.validPackageIdentifier(String(fields[0])) else { throw ScanError.malformed("Unsupported MacPorts installed output") }
            let name = String(fields[0]), version = String(fields[1].dropFirst())
            var item = SoftwareItem(name: name, kind: .package, source: .macPorts, packageID: name, evidence: Evidence("port -q installed"))
            item.id += ":" + version; item.version = version
            item.attributes["Active"] = line.contains("(active)") ? "Yes" : "No"
            item.attributes["Prefix"] = prefix
            item.attributes["Manager executable"] = prefix + "/bin/port"
            item.attributes["MacPorts version"] = version
            item.health = InstallationHealthClassifier.classify(item, registration: .installed)
            items.append(item)
        }
        return items
    }
}

public struct NixScanner: SoftwareScanner {
    public let source: InstallSource = .nix
    public var executable: String
    public var runner: any CommandRunning
    public var profile: String?
    public var security: any ManagedRemovalSecurity
    public var observedExists: (@Sendable (String) -> Bool)?
    public init(executable: String = "/nix/var/nix/profiles/default/bin/nix", runner: any CommandRunning = ProcessRunner(), profile: String? = nil, security: any ManagedRemovalSecurity = LiveManagedRemovalSecurity(), observedExists: (@Sendable (String) -> Bool)? = nil) { self.executable = executable; self.runner = runner; self.profile = profile; self.security = security; self.observedExists = observedExists }
    public func scan() async throws -> ScanResult {
        let candidates = [executable, FileSystem.canonical("~/.nix-profile/bin/nix")]
        guard let executable = candidates.first(where: { FileSystem.exists($0) }) else {
            if candidates.contains(where: { ArtifactObservation.inspect($0).presence == .inaccessible }) { throw ScanError.permission }
            return ScanResult(source, state: .notInstalled)
        }
        do {
            let profile = self.profile ?? Self.defaultProfileSlot()
            let data = try await runner.run(.nix(executable: executable, profile: profile))
            var items = try Self.parse(data, exists: observedExists)
            let mode = profile.flatMap { try? security.profileFingerprint($0) } == nil ? "unverified" : "modern-mutable"
            for index in items.indices {
                items[index].attributes["Manager executable"] = executable
                if let profile { items[index].attributes["Nix profile"] = profile }
                items[index].attributes["Nix profile mode"] = mode
            }
            return ScanResult(source, items: items, message: "Current user's modern profile only; arbitrary profiles and system closures are not enumerated")
        } catch is CancellationError { throw CancellationError() }
        catch {
            let legacy = URL(fileURLWithPath: executable).deletingLastPathComponent().appendingPathComponent("nix-env").path
            guard FileSystem.exists(legacy) else { return ScanResult(source, state: .unsupported, message: "Modern profile query failed and no legacy query tool is available: \(error.localizedDescription)") }
            return ScanResult(source, items: try Self.parse(try await runner.run(.legacyNix(executable: legacy))), message: "Legacy current-user profile; modern query unavailable")
        }
    }
    public static func defaultProfileSlot() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let modern = home + "/.local/state/nix/profiles/profile"
        let legacySlot = "/nix/var/nix/profiles/per-user/" + NSUserName() + "/profile"
        // Prefer the actual user-selected ~/.nix-profile link, never its /nix/store resolution.
        if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: home + "/.nix-profile") {
            let path = target.hasPrefix("/") ? URL(fileURLWithPath: target).standardizedFileURL.path : URL(fileURLWithPath: home).appendingPathComponent(target).standardizedFileURL.path
            if [modern, legacySlot].contains(path) { return path }
            return nil // Unknown/declarative/default profile is not silently replaced by another.
        }
        return FileSystem.exists(modern) ? modern : FileSystem.exists(legacySlot) ? legacySlot : nil
    }
    public static func parse(_ data: Data, exists: ((String) -> Bool)? = nil) throws -> [SoftwareItem] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ScanError.malformed("Invalid Nix JSON") }
        let records = object["elements"] as? [String: Any] ?? object
        var items: [SoftwareItem] = []
        for (key, raw) in records.sorted(by: { $0.key < $1.key }) {
            guard let record = raw as? [String: Any] else { throw ScanError.malformed("Unsupported Nix profile format") }
            let paths = record["storePaths"] as? [String] ?? (record["outputs"] as? [String: String]).map { Array($0.values) } ?? []
            guard !paths.isEmpty else { throw ScanError.malformed("Nix profile record has no store paths") }
            for path in paths {
                guard path.hasPrefix("/nix/store/"), !path.dropFirst("/nix/store/".count).contains("/"), !path.contains("..") else { continue }
                var item = SoftwareItem(name: record["name"] as? String ?? key, kind: .package, source: .nix, path: path, packageID: key, evidence: Evidence("Nix installed profile JSON and existing store path"))
                item.version = record["version"] as? String
                item.attributes["Profile entry"] = key
                item.health = InstallationHealthClassifier.classify(item, registration: .installed, artifacts: [exists.map { ArtifactObservation(path, $0(path) ? .present : .missing) } ?? ArtifactObservation.inspect(path)])
                item.evidence["sizeBytes"] = Evidence("Referenced store object only; dependencies excluded", availability: .calculating)
                items.append(item)
            }
        }
        return items
    }
}
