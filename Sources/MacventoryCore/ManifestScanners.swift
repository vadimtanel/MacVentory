import Foundation

/// Small bounded Valve KeyValues parser. Does not execute directives or resolve includes.
public enum KeyValues {
    public indirect enum Value: Sendable, Equatable { case string(String), object([String: Value])
        public var text: String? { if case .string(let text) = self { text } else { nil } }
        public var object: [String: Value]? { if case .object(let object) = self { object } else { nil } }
    }
    public static func parse(_ text: String) throws -> [String: Value] {
        guard text.utf8.count <= 4 * 1024 * 1024 else { throw ScanError.limit("VDF manifest too large") }
        let characters = Array(text); var cursor = 0, tokenCount = 0
        func token() throws -> String? {
            while cursor < characters.count {
                if characters[cursor].isWhitespace { cursor += 1; continue }
                if characters[cursor] == "/", cursor + 1 < characters.count, characters[cursor + 1] == "/" {
                    while cursor < characters.count && characters[cursor] != "\n" { cursor += 1 }; continue
                }
                break
            }
            guard cursor < characters.count else { return nil }
            tokenCount += 1; guard tokenCount < 100_000 else { throw ScanError.limit("Too many VDF tokens") }
            let first = characters[cursor]; cursor += 1
            if first == "{" || first == "}" { return String(first) }
            var result = ""
            if first == "\"" {
                while cursor < characters.count {
                    let char = characters[cursor]; cursor += 1
                    if char == "\"" { return result }
                    if char == "\\", cursor < characters.count { result.append(characters[cursor]); cursor += 1 }
                    else { result.append(char) }
                }
                throw ScanError.malformed("Unclosed VDF string")
            }
            result.append(first)
            while cursor < characters.count && !characters[cursor].isWhitespace && characters[cursor] != "{" && characters[cursor] != "}" { result.append(characters[cursor]); cursor += 1 }
            return result
        }
        func object(depth: Int, nested: Bool) throws -> [String: Value] {
            guard depth < 32 else { throw ScanError.limit("VDF nesting too deep") }
            var result: [String: Value] = [:]
            while let key = try token() {
                if key == "}" { if nested { return result }; throw ScanError.malformed("Unexpected VDF close") }
                guard key != "{", let value = try token(), value != "}" else { throw ScanError.malformed("Missing VDF value") }
                result[key] = value == "{" ? .object(try object(depth: depth + 1, nested: true)) : .string(value)
            }
            if nested { throw ScanError.malformed("Unclosed VDF object") }
            return result
        }
        return try object(depth: 0, nested: false)
    }
}

public struct SteamScanner: SoftwareScanner {
    public let source: InstallSource = .steam
    public var root: String
    public var allowExternal: Bool
    public init(root: String = "~/Library/Application Support/Steam", allowExternal: Bool = false) { self.root = FileSystem.canonical(root); self.allowExternal = allowExternal }
    public func scan() async throws -> ScanResult {
        guard FileSystem.exists(root) else { return ScanResult(source, state: .notInstalled) }
        var libraries = Set([root]), warnings: [String] = [], items: [SoftwareItem] = []
        let libraryFile = root + "/steamapps/libraryfolders.vdf"
        if FileSystem.exists(libraryFile) {
            let values = try KeyValues.parse(FileSystem.text(libraryFile))["libraryfolders"]?.object ?? [:]
            for value in values.values {
                if let path = value.object?["path"]?.text ?? value.text, path.hasPrefix("/") {
                    if !allowExternal && FileSystem.canonical(path).hasPrefix("/Volumes/") { warnings.append("External Steam library skipped (disabled)"); continue }
                    libraries.insert(FileSystem.canonical(path))
                }
            }
        }
        for library in libraries.sorted() {
            let steamapps = library + "/steamapps"
            guard FileSystem.exists(steamapps) else { continue }
            for file in try FileSystem.children(steamapps) where file.lastPathComponent.hasPrefix("appmanifest_") && file.pathExtension == "acf" {
                try Task.checkCancellation()
                do {
                    guard let record = try KeyValues.parse(FileSystem.text(file.path))["AppState"]?.object,
                          let id = record["appid"]?.text, id.allSatisfy(\.isNumber),
                          let directory = record["installdir"]?.text, !directory.isEmpty else { throw ScanError.malformed("Missing Steam app fields") }
                    let path = steamapps + "/common/" + directory
                    guard FileSystem.contained(path, in: steamapps + "/common"), FileSystem.exists(path) else { warnings.append("Manifest \(id): payload missing"); continue }
                    var item = SoftwareItem(name: record["name"]?.text ?? "Steam \(id)", kind: .game, source: .steam, path: path, packageID: id, evidence: Evidence("Steam local appmanifest and existing game directory"))
                    item.attributes["Steam build ID"] = record["buildid"]?.text ?? "Unknown"
                    if let timestamp = record["LastUpdated"]?.text.flatMap(Double.init), timestamp > 0 { item.updatedAt = Date(timeIntervalSince1970: timestamp) }
                    item.evidence["updatedAt"] = Evidence("Steam LastUpdated", confidence: .inferred, explanation: "Update timestamp, not an installation date")
                    item.evidence["sizeBytes"] = Evidence("Game directory logical footprint", availability: .calculating)
                    let apps = try await NativeScanner(roots: [path], allowExternal: allowExternal).scan().items
                    item.relatedPaths = apps.compactMap(\.path)
                    item.lastOpenedAt = apps.compactMap(\.lastOpenedAt).max()
                    item.evidence["lastOpenedAt"] = Evidence("Spotlight on contained game bundle", confidence: .inferred, availability: item.lastOpenedAt == nil ? .notAvailable : .available)
                    items.append(item)
                } catch is CancellationError { throw CancellationError() }
                catch { warnings.append(file.lastPathComponent + ": " + error.localizedDescription) }
            }
        }
        return ScanResult(source, items: items, state: warnings.isEmpty ? nil : .failed, message: "Experimental local manifest adapter; no Steam API or login. " + warnings.joined(separator: "; "))
    }
}

public struct SetappScanner: SoftwareScanner {
    public let source: InstallSource = .setapp
    public var roots: [String]
    public init(roots: [String] = ["/Applications/Setapp", "~/Applications/Setapp"]) { self.roots = roots }
    public func scan() async throws -> ScanResult {
        let available = roots.map(FileSystem.canonical).filter(FileSystem.exists)
        guard !available.isEmpty else { return ScanResult(source, state: .notInstalled) }
        let discoveries = try await NativeScanner(roots: available).scan()
        var items: [SoftwareItem] = [], unsupported = false
        for var item in discoveries.items {
            guard let path = item.path else { continue }
            // Combining provider root with the vendor integration framework avoids name-only classification.
            guard FileSystem.exists(path + "/Contents/Frameworks/Setapp.framework") else { unsupported = true; continue }
            item.sources = [.init(source, Evidence("Setapp installation root and embedded Setapp.framework", confidence: .inferred, explanation: "Setapp variant detected; active subscription/management not authenticated"))]
            item.primarySource = source; items.append(item)
        }
        return ScanResult(source, items: items, state: discoveries.report.state == .failed ? .failed : unsupported ? .unsupported : nil,
                          message: "Experimental Setapp variant detection; private databases and account state are not accessed")
    }
}

public struct ToolboxScanner: SoftwareScanner {
    public let source: InstallSource = .toolbox
    public var roots: [String]
    public var managementRoot: String
    public var scriptRoots: [String]?
    public init(roots: [String] = ["~/Applications", "~/Library/Application Support/JetBrains/Toolbox/apps"], managementRoot: String = "~/Library/Application Support/JetBrains/Toolbox", scriptRoots: [String]? = nil) {
        self.roots = roots; self.managementRoot = FileSystem.canonical(managementRoot); self.scriptRoots = scriptRoots
    }
    public func scan() async throws -> ScanResult {
        let settings = try? FileSystem.json(managementRoot + "/.settings.json")
        var discoveryRoots = roots
        if let location = settings?["install_location"] as? String, location.hasPrefix("/"), URL(fileURLWithPath: location).pathComponents.count > 2 { discoveryRoots.append(location) }
        let available = discoveryRoots.map(FileSystem.canonical).filter(FileSystem.exists)
        var items: [SoftwareItem] = []
        let discoveries = try await NativeScanner(roots: available).scan()
        for var item in discoveries.items {
            try Task.checkCancellation()
            guard let path = item.path, let bundle = item.bundleID, bundle.hasPrefix("com.jetbrains.") else { continue }
            // Legacy manager-owned layout is documented by JetBrains' IntelliJ Platform SDK:
            // Toolbox/apps/<product>/ch-<channel>/<build>/<app>.app.
            // Merely being in ~/Applications or carrying product-info.json proves no ownership.
            let components = URL(fileURLWithPath: path).pathComponents
            guard let toolbox = components.lastIndex(of: "Toolbox"), components.count > toolbox + 5,
                  components[toolbox + 1] == "apps", components[toolbox + 3].hasPrefix("ch-"),
                  components[toolbox + 4].first?.isNumber == true else { continue }
            item.sources = [.init(source, Evidence("JetBrains-documented legacy Toolbox installation layout and IDE bundle", confidence: .inferred, explanation: "Legacy layout only; current ~/Applications ownership has no supported local inventory API"))]
            item.primarySource = source; items.append(item)
        }
        var launcherRoots = scriptRoots ?? [managementRoot + "/scripts", "/usr/local/bin"]
        if scriptRoots == nil, let location = (settings?["shell_scripts"] as? [String: Any])?["location"] as? String, location.hasPrefix("/") { launcherRoots.append(location) }
        var launcherSeen = false
        for root in Set(launcherRoots.map(FileSystem.canonical)).sorted() where FileSystem.exists(root) {
            for script in try FileSystem.children(root).prefix(2000) {
                try Task.checkCancellation()
                guard let text = try? FileSystem.text(script.path, limit: 65_536) else { continue }
                for path in Self.launcherPaths(text) {
                    launcherSeen = true
                    guard var item = try? NativeScanner.item(at: path), item.bundleID?.hasPrefix("com.jetbrains.") == true else { continue }
                    item.primarySource = source
                    item.sources = [.init(source, Evidence("Toolbox-generated launcher: " + script.path, confidence: .inferred, explanation: "Explicit generated-script marker and exact existing IDE target; association is not authenticated ownership"))]
                    item.attributes["Toolbox detection"] = "Modern generated launcher"
                    items.append(item)
                }
            }
        }
        let present = FileSystem.exists(managementRoot) || FileSystem.exists("/Applications/JetBrains Toolbox.app") || !items.isEmpty
        return ScanResult(source, items: InventoryMerger.merge(items), state: !present && !launcherSeen ? .notInstalled : items.isEmpty ? .unsupported : nil,
            message: "Legacy layout and modern Toolbox-generated launcher association (inferred). Missing launchers/unknown script layouts remain unsupported; scripts are never executed.")
    }
    public static func launcherPaths(_ text: String) -> [String] {
        let prefix = String(text.prefix(512))
        guard prefix.range(of: #"(?m)^#\s*Generated by JetBrains Toolbox [0-9]"#, options: .regularExpression) != nil else { return [] }
        guard let expression = try? NSRegularExpression(pattern: #"["'](/[^"'\n]*?\.app)(?:/Contents/MacOS/[^"'\n]*)?["']"#) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            let path = String(text[range])
            guard !path.contains("$"), !path.contains("`"), !path.contains("\\"), !path.split(separator: "/").contains("..") else { return nil }
            return FileSystem.canonical(path)
        }
    }
}
