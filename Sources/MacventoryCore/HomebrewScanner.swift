import Foundation

/// Reads installed receipts rather than executing recipes or allowing brew to fetch metadata.
public struct HomebrewScanner: SoftwareScanner {
    public var source: InstallSource
    public var prefixes: [String]
    public init(source: InstallSource, prefixes: [String] = ["/opt/homebrew", "/usr/local"]) {
        self.source = source; self.prefixes = prefixes
    }
    public func scan() async throws -> ScanResult {
        var items: [SoftwareItem] = [], warnings: [String] = [], found = false
        for prefix in Set(prefixes.map(FileSystem.canonical)).sorted() {
            try Task.checkCancellation()
            let root = prefix + (source == .homebrewCask ? "/Caskroom" : "/Cellar")
            guard FileSystem.exists(root) else { continue }
            found = true
            for package in try FileSystem.children(root) {
                try Task.checkCancellation()
                do {
                    if source == .homebrewFormula {
                        for keg in try FileSystem.children(package.path) where keg.hasDirectoryPath {
                            let receiptPath = keg.path + "/INSTALL_RECEIPT.json"
                            guard FileSystem.exists(receiptPath) else { continue }
                            let receipt = try FileSystem.json(receiptPath)
                            var item = SoftwareItem(name: package.lastPathComponent, kind: .package, source: source, path: keg.path, packageID: package.lastPathComponent, evidence: Evidence("Homebrew installed keg receipt"))
                            item.version = keg.lastPathComponent
                            item.installedAt = FileSystem.date(receipt["time"])
                            item.evidence["installedAt"] = Evidence("Homebrew INSTALL_RECEIPT.json time", availability: item.installedAt == nil ? .notAvailable : .available, explanation: "Installation of this keg/version; not necessarily first installation")
                            item.evidence["lastOpenedAt"] = Evidence("CLI usage unavailable", confidence: .unknown, availability: .notAvailable)
                            item.evidence["sizeBytes"] = Evidence("Keg filesystem", availability: .calculating)
                            item.attributes["Installed on request"] = (receipt["installed_on_request"] as? Bool).map(String.init) ?? "Unknown"
                            item.attributes["Linked"] = FileSystem.canonical(prefix + "/var/homebrew/linked/" + package.lastPathComponent) == FileSystem.canonical(keg.path) ? "Yes" : "No"
                            item.attributes["Opt-linked"] = FileSystem.canonical(prefix + "/opt/" + package.lastPathComponent) == FileSystem.canonical(keg.path) ? "Yes" : "No"
                            if let api = try? Self.cachedFormula(prefix: prefix, name: package.lastPathComponent), let kegOnly = api["keg_only"] as? Bool { item.attributes["Keg-only"] = String(kegOnly) }
                            else { item.attributes["Keg-only"] = "Unknown (not recorded in installed receipt)" }
                            items.append(item)
                        }
                    } else { items += try Self.cask(package.path) }
                } catch { warnings.append(package.lastPathComponent + ": " + error.localizedDescription) }
            }
        }
        return ScanResult(source, items: items, state: !found ? .notInstalled : warnings.isEmpty ? nil : .failed,
            message: "Read-only installed receipt adapter; no Homebrew command or network access. " + warnings.joined(separator: "; "))
    }
    private static func cachedFormula(prefix: String, name: String) throws -> [String: Any]? {
        // Optional metadata is read only from a per-keg JSON export when present; never evaluate Ruby.
        let path = prefix + "/opt/" + name + "/.brew/" + name + ".json"
        return FileSystem.exists(path) ? try FileSystem.json(path) : nil
    }
    public static func cask(_ root: String) throws -> [SoftwareItem] {
        let metadata = root + "/.metadata"
        let receipt = try FileSystem.json(metadata + "/INSTALL_RECEIPT.json")
        let config = try? FileSystem.json(metadata + "/config.json")
        let defaults = config?["default"] as? [String: Any] ?? [:]
        let explicit = config?["explicit"] as? [String: Any] ?? [:]
        let appDirectory = explicit["appdir"] as? String ?? defaults["appdir"] as? String ?? "/Applications"
        let source = receipt["source"] as? [String: Any]
        let token = URL(fileURLWithPath: root).lastPathComponent
        var items: [SoftwareItem] = []
        for artifact in receipt["uninstall_artifacts"] as? [[String: Any]] ?? [] {
            // Only the declarative app mapping is read. Uninstall/zap entries are never executed.
            for entry in artifact["app"] as? [Any] ?? [] {
                guard let relative = entry as? String, !relative.hasPrefix("/"), !relative.split(separator: "/").contains("..") else { continue }
                let path = URL(fileURLWithPath: appDirectory).appendingPathComponent(relative).path
                guard FileSystem.exists(path) else { continue }
                var item = try NativeScanner.item(at: path)
                item.primarySource = .homebrewCask
                item.sources = [.init(.homebrewCask, Evidence("Homebrew cask installed receipt and existing artifact"))]
                item.packageID = token
                item.attributes["Homebrew receipt"] = metadata + "/INSTALL_RECEIPT.json"
                item.attributes["Homebrew executable"] = URL(fileURLWithPath: root).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("bin/brew").path
                item.attributes["Manager version"] = source?["version"] as? String ?? "Unknown"
                item.installedAt = FileSystem.date(receipt["time"])
                item.evidence["installedAt"] = Evidence("Homebrew cask receipt time", availability: item.installedAt == nil ? .notAvailable : .available, explanation: "Recorded cask installation; app may subsequently self-update")
                items.append(item)
            }
        }
        if items.isEmpty {
            var item = SoftwareItem(name: token, kind: .package, source: .homebrewCask, packageID: FileSystem.canonical(root), evidence: Evidence("Homebrew cask receipt", explanation: "Receipt present; installed application payload not mapped"))
            item.version = source?["version"] as? String
            item.attributes["Payload"] = "Not verified; receipt record only"
            item.evidence["sizeBytes"] = Evidence("No verified payload", confidence: .unknown, availability: .notAvailable)
            items.append(item)
        }
        return items
    }
}
