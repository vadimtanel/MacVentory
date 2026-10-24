import Foundation

/// One read-only installed-state query per prefix/source, never one process per row.
public struct HomebrewScanner: SoftwareScanner {
    public var source: InstallSource
    public var prefixes: [String]
    public var runner: any CommandRunning
    public init(source: InstallSource, prefixes: [String] = ["/opt/homebrew", "/usr/local"], runner: any CommandRunning = ProcessRunner()) {
        self.source = source; self.prefixes = prefixes; self.runner = runner
    }
    public static func installedTokens(_ data: Data) throws -> [String: [String]] {
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
        guard lines.count <= 20_000 else { throw ScanError.limit("Homebrew package count") }
        var result: [String: [String]] = [:]
        for line in lines {
            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let token = fields.first, UninstallPlanner.validToken(token), fields.count >= 2 else { throw ScanError.malformed("Unsupported Homebrew installed output") }
            result[token] = Array(fields.dropFirst())
        }
        return result
    }
    public func scan() async throws -> ScanResult {
        var items: [SoftwareItem] = [], warnings: [String] = [], found = false
        for prefix in Set(prefixes.map(FileSystem.canonical)).sorted() {
            try Task.checkCancellation()
            let root = prefix + (source == .homebrewCask ? "/Caskroom" : "/Cellar"), executable = prefix + "/bin/brew"
            let rootPresence = ArtifactObservation.inspect(root).presence
            if rootPresence == .inaccessible { throw ScanError.permission }
            if rootPresence == .brokenLink { throw ScanError.process("Homebrew inventory root is a broken link") }
            guard rootPresence == .present else { continue }
            found = true
            var installed: [String: [String]]?
            do { installed = try Self.installedTokens(try await runner.run(.brewInstalled(executable: executable, cask: source == .homebrewCask))) }
            catch is CancellationError { throw CancellationError() }
            catch { warnings.append("Manager state unavailable: " + error.localizedDescription) }
            var prefixItems: [SoftwareItem] = []
            for package in try FileSystem.children(root) where !package.lastPathComponent.hasPrefix(".") {
                try Task.checkCancellation()
                do {
                    if source == .homebrewCask { prefixItems += try Self.cask(package.path) }
                    else {
                        for keg in try FileSystem.children(package.path) where keg.hasDirectoryPath {
                            let receiptPath = keg.path + "/INSTALL_RECEIPT.json"
                            guard FileSystem.exists(receiptPath) else { continue }
                            let receipt = try FileSystem.json(receiptPath)
                            var item = SoftwareItem(name: package.lastPathComponent, kind: .package, source: source, path: keg.path, packageID: package.lastPathComponent, evidence: Evidence("Homebrew installed keg receipt"))
                            item.version = keg.lastPathComponent; item.installedAt = FileSystem.date(receipt["time"])
                            item.attributes["Homebrew receipt"] = receiptPath
                            item.attributes["Homebrew executable"] = executable
                            if let metadata = try? FileSystem.json(prefix + "/opt/" + package.lastPathComponent + "/.brew/" + package.lastPathComponent + ".json"), let kegOnly = metadata["keg_only"] as? Bool { item.attributes["Keg-only"] = String(kegOnly) }
                            else { item.attributes["Keg-only"] = "Unknown (not recorded in installed receipt)" }
                            item.attributes["Installed on request"] = (receipt["installed_on_request"] as? Bool).map(String.init) ?? "Unknown"
                            item.attributes["Linked"] = FileSystem.canonical(prefix + "/var/homebrew/linked/" + package.lastPathComponent) == FileSystem.canonical(keg.path) ? "Yes" : "No"
                            item.attributes["Opt-linked"] = FileSystem.canonical(prefix + "/opt/" + package.lastPathComponent) == FileSystem.canonical(keg.path) ? "Yes" : "No"
                            item.evidence["installedAt"] = Evidence("Homebrew receipt time", availability: item.installedAt == nil ? .notAvailable : .available)
                            item.evidence["sizeBytes"] = Evidence("Keg filesystem", availability: .calculating)
                            prefixItems.append(item)
                        }
                    }
                } catch { warnings.append(package.lastPathComponent + ": " + error.localizedDescription) }
            }
            // Preserve manager-only records even when their receipt cannot be mapped.
            for (token, versions) in installed ?? [:] where !prefixItems.contains(where: { $0.packageID == token }) {
                var item = SoftwareItem(name: token, kind: .package, source: source, packageID: token, evidence: Evidence("Homebrew installed-state query"))
                item.id += ":" + prefix; item.version = versions.joined(separator: ", ")
                item.attributes["Homebrew executable"] = executable
                prefixItems.append(item)
            }
            for var item in prefixItems {
                let state: ManagerRegistration = installed.map { $0[item.packageID ?? ""] == nil ? .absent : .installed } ?? .unknown
                item.attributes["Manager state"] = state.rawValue
                let prior = item.health
                item.health = InstallationHealthClassifier.classify(item, registration: state, artifacts: prior?.artifacts)
                if let path = item.path, let bundle = try? NativeScanner.item(at: path), [.attention, .unverified].contains(bundle.installationHealth.status) {
                    item.health = .init(bundle.installationHealth.status, bundle.installationHealth.explanation, registration: state, artifacts: (prior?.artifacts ?? []) + (bundle.health?.artifacts.filter { $0.path != path } ?? []))
                }
                if state == .absent && item.path == nil {
                    item.health = .init(.historical, "Caskroom metadata remains, but Homebrew no longer reports this token installed.", registration: .absent, artifacts: item.health?.artifacts ?? [])
                }
                items.append(item)
            }
        }
        return ScanResult(source, items: items, state: !found ? .notInstalled : warnings.isEmpty ? nil : .failed, message: "Read-only receipts and installed-state query. " + warnings.joined(separator: "; "))
    }
    public static func cask(_ root: String) throws -> [SoftwareItem] {
        let metadata = root + "/.metadata", receipt = try FileSystem.json(metadata + "/INSTALL_RECEIPT.json")
        let config = try? FileSystem.json(metadata + "/config.json")
        let token = URL(fileURLWithPath: root).lastPathComponent
        let executable = URL(fileURLWithPath: root).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("bin/brew").path
        let version = (receipt["source"] as? [String: Any])?["version"] as? String
        let mappings = try CaskMappedArtifact.read(receipt: receipt, config: config ?? [:], root: root)
        let paths = mappings.filter { $0.kind == "app" }.map(\.path)
        let allTargets = mappings.map(\.path)
        let expected = allTargets.map(ArtifactObservation.inspect)
        var items: [SoftwareItem] = []
        for observation in expected where observation.presence == .present && paths.contains(observation.path) {
            if let item = try? NativeScanner.item(at: observation.path) { items.append(item) }
        }
        // Only inspect staged bundles when the receipt does not declare an app target.
        // A staged bundle never substitutes for a declared but missing installed app.
        if mappings.isEmpty {
            for directory in try FileSystem.children(root) where directory.hasDirectoryPath && !directory.lastPathComponent.hasPrefix(".") {
                for candidate in try FileSystem.children(directory.path) where candidate.pathExtension.lowercased() == "app" {
                    if var item = try? NativeScanner.item(at: candidate.path) { item.attributes["Payload"] = "Caskroom application bundle"; items.append(item) }
                }
            }
        }
        if items.isEmpty {
            var item = SoftwareItem(name: token, kind: .package, source: .homebrewCask, packageID: token, evidence: Evidence("Homebrew cask receipt", explanation: "Registration metadata is separate from application presence"))
            item.id += ":" + FileSystem.canonical(root)
            item.version = version
            items = [item]
        }
        for i in items.indices {
            items[i].primarySource = .homebrewCask; items[i].packageID = token
            items[i].sources = [.init(.homebrewCask, Evidence("Homebrew cask receipt and artifact observation"))]
            items[i].attributes["Homebrew receipt"] = metadata + "/INSTALL_RECEIPT.json"
            items[i].attributes["Homebrew executable"] = executable
            items[i].attributes["Caskroom metadata"] = root
            items[i].attributes["Expected application paths"] = paths.joined(separator: "\n")
            items[i].attributes["Manager version"] = version ?? "Unknown"
            items[i].installedAt = FileSystem.date(receipt["time"])
            items[i].evidence["installedAt"] = Evidence("Homebrew receipt time", availability: items[i].installedAt == nil ? .notAvailable : .available)
            items[i].health = InstallationHealthClassifier.classify(items[i], registration: .unknown, artifacts: expected.isEmpty ? nil : expected)
            if let defect = expected.first(where: { paths.contains($0.path) && $0.presence == .present && ArtifactObservation.inspect($0.path + "/Contents/Info.plist").presence != .present }) {
                items[i].health = .init(.unverified, "The app directory exists, but required bundle metadata is unavailable.", artifacts: expected + [ArtifactObservation.inspect(defect.path + "/Contents/Info.plist")])
            }
        }
        return items
    }
}
