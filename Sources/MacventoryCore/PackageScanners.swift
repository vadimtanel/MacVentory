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
                    item.isSystem = id.hasPrefix("com.apple.")
                    item.installedAt = FileSystem.date(info["install-time"])
                    item.evidence["installedAt"] = Evidence("pkgutil install-time", availability: item.installedAt == nil ? .notAvailable : .available)
                    item.attributes["Payload"] = existing == 0 ? "Receipt only; no existing payload verified" : "\(existing) existing paths; package footprint not measured"
                    item.attributes["Recorded location"] = installRoot
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
        guard FileSystem.exists(executable) else { return ScanResult(source, state: .notInstalled) }
        let text = String(decoding: try await runner.run(.ports(executable: executable)), as: UTF8.self)
        var items = try Self.parse(text, prefix: URL(fileURLWithPath: executable).deletingLastPathComponent().deletingLastPathComponent().path)
        for index in items.indices {
            try Task.checkCancellation()
            // Contents are evidence, not a reason to count the entire shared prefix as one package.
            if let id = items[index].packageID, items[index].attributes["Active"] == "Yes" {
                let data = try await runner.run(.portContents(executable: executable, name: id))
                let paths = String(decoding: data, as: UTF8.self).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("/") && FileSystem.exists($0) }
                items[index].relatedPaths = paths
                for path in paths where path.hasSuffix("/Contents/Info.plist") {
                    let app = String(path.dropLast("/Contents/Info.plist".count))
                    if var application = try? NativeScanner.item(at: app) {
                        application.sources = items[index].sources; application.primarySource = .macPorts
                        application.packageID = id; items.append(application)
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
            items.append(item)
        }
        return items
    }
}

public struct NixScanner: SoftwareScanner {
    public let source: InstallSource = .nix
    public var executable: String
    public var runner: any CommandRunning
    public init(executable: String = "/nix/var/nix/profiles/default/bin/nix", runner: any CommandRunning = ProcessRunner()) { self.executable = executable; self.runner = runner }
    public func scan() async throws -> ScanResult {
        let candidates = [executable, FileSystem.canonical("~/.nix-profile/bin/nix")]
        guard let executable = candidates.first(where: { FileSystem.exists($0) }) else { return ScanResult(source, state: .notInstalled) }
        do {
            let data = try await runner.run(.nix(executable: executable, profile: nil))
            return ScanResult(source, items: try Self.parse(data), message: "Current user's modern profile only; arbitrary profiles and system closures are not enumerated")
        } catch is CancellationError { throw CancellationError() }
        catch {
            let legacy = URL(fileURLWithPath: executable).deletingLastPathComponent().appendingPathComponent("nix-env").path
            guard FileSystem.exists(legacy) else { return ScanResult(source, state: .unsupported, message: "Modern profile query failed and no legacy query tool is available: \(error.localizedDescription)") }
            return ScanResult(source, items: try Self.parse(try await runner.run(.legacyNix(executable: legacy))), message: "Legacy current-user profile; modern query unavailable")
        }
    }
    public static func parse(_ data: Data, exists: (String) -> Bool = FileSystem.exists) throws -> [SoftwareItem] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ScanError.malformed("Invalid Nix JSON") }
        let records = object["elements"] as? [String: Any] ?? object
        var items: [SoftwareItem] = []
        for (key, raw) in records.sorted(by: { $0.key < $1.key }) {
            guard let record = raw as? [String: Any] else { throw ScanError.malformed("Unsupported Nix profile format") }
            let paths = record["storePaths"] as? [String] ?? (record["outputs"] as? [String: String]).map { Array($0.values) } ?? []
            guard !paths.isEmpty else { throw ScanError.malformed("Nix profile record has no store paths") }
            for path in paths {
                guard path.hasPrefix("/nix/store/"), !path.dropFirst("/nix/store/".count).contains("/"), exists(path) else { continue }
                var item = SoftwareItem(name: record["name"] as? String ?? key, kind: .package, source: .nix, path: path, packageID: key, evidence: Evidence("Nix installed profile JSON and existing store path"))
                item.version = record["version"] as? String
                item.attributes["Profile entry"] = key
                item.evidence["sizeBytes"] = Evidence("Referenced store object only; dependencies excluded", availability: .calculating)
                items.append(item)
            }
        }
        return items
    }
}
