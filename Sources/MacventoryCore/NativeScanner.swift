import Foundation
import CoreServices

public struct NativeScanner: SoftwareScanner {
    public let source: InstallSource = .unmanaged
    public var roots: [String]
    public var includeSystem: Bool
    public var allowExternal: Bool
    public init(roots: [String] = ["/Applications", "~/Applications"], includeSystem: Bool = false, allowExternal: Bool = false) {
        self.roots = roots; self.includeSystem = includeSystem; self.allowExternal = allowExternal
    }
    public func scan() async throws -> ScanResult {
        var items: [SoftwareItem] = [], errors: [String] = [], visited = Set<String>(), entries = 0
        var queue = (roots + (includeSystem ? ["/System/Applications", "/System/Library/CoreServices/Applications"] : [])).map { (FileSystem.canonical($0), 0) }
        while !queue.isEmpty {
            try Task.checkCancellation()
            let (path, depth) = queue.removeFirst()
            if !allowExternal && path.hasPrefix("/Volumes/") { continue }
            guard visited.insert(path).inserted else { continue }
            if path.lowercased().hasSuffix(".app") {
                do { items.append(try Self.item(at: path)) } catch { errors.append("Cannot read bundle: \(path)") }
                continue
            }
            guard FileSystem.exists(path) else { continue }
            do {
                for url in try FileSystem.children(path) {
                    entries += 1
                    guard entries <= 20_000 else { throw ScanError.limit("Application traversal limit reached") }
                    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isAliasFileKey, .volumeIsInternalKey])
                    // macOS reports some symlinks (including Safari) as aliases too.
                    // Resolve actual symlinks before attempting Finder bookmark/alias resolution.
                    if values.isSymbolicLink == true {
                        if url.pathExtension.lowercased() == "app" { queue.append((FileSystem.canonical(url.path), depth + 1)) }
                    } else if values.isAliasFile == true {
                        if let resolved = try? URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting]), resolved.pathExtension.lowercased() == "app" { queue.append((FileSystem.canonical(resolved.path), depth + 1)) }
                    } else if values.isDirectory == true {
                        if url.pathExtension.lowercased() == "app" || depth < 4 { queue.append((FileSystem.canonical(url.path), depth + 1)) }
                    }
                }
            } catch { errors.append("\(URL(fileURLWithPath: path).lastPathComponent): \(error.localizedDescription)") }
        }
        return ScanResult(source, items: items, state: errors.isEmpty ? nil : .failed, message: errors.joined(separator: "; "))
    }
    public static func item(at path: String) throws -> SoftwareItem {
        let canonical = FileSystem.canonical(path)
        let infoPath = URL(fileURLWithPath: canonical).appendingPathComponent("Contents/Info.plist")
        let attributes = try FileManager.default.attributesOfItem(atPath: infoPath.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max < 4 * 1024 * 1024 else { throw ScanError.limit("Bundle Info.plist exceeds 4 MiB") }
        let data = try Data(contentsOf: infoPath)
        guard let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { throw ScanError.malformed("Invalid app Info.plist") }
        let name = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? URL(fileURLWithPath: canonical).deletingPathExtension().lastPathComponent
        var item = SoftwareItem(name: name, path: canonical, evidence: Evidence("Bundle Info.plist", confidence: .inferred, explanation: "No verified manager ownership yet; exact download origin is unknown"))
        item.version = info["CFBundleShortVersionString"] as? String ?? info["CFBundleVersion"] as? String
        item.bundleID = info["CFBundleIdentifier"] as? String
        // Copyright text is not reliable publisher identity.
        item.vendor = nil
        if let copyright = info["NSHumanReadableCopyright"] as? String { item.attributes["Copyright"] = copyright }
        item.evidence["vendor"] = Evidence("Publisher identity unavailable", confidence: .unknown, availability: .notAvailable)
        item.isSystem = canonical.hasPrefix("/System/") || canonical.hasPrefix("/usr/")
        item.evidence["version"] = Evidence("CFBundleShortVersionString / CFBundleVersion", availability: item.version == nil ? .notAvailable : .available)
        item.evidence["name"] = Evidence("Bundle Info.plist")
        item.evidence["sizeBytes"] = Evidence("Filesystem", availability: .calculating)
        item.evidence["installedAt"] = Evidence("No installation record", confidence: .unknown, availability: .notAvailable)
        let values = try? URL(fileURLWithPath: canonical).resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        item.fileCreatedAt = values?.creationDate; item.fileModifiedAt = values?.contentModificationDate
        item.evidence["fileCreatedAt"] = Evidence("Filesystem creation date", explanation: "Not an installation date")
        if let md = MDItemCreate(kCFAllocatorDefault, canonical as CFString) {
            item.lastOpenedAt = MDItemCopyAttribute(md, kMDItemLastUsedDate) as? Date
        }
        if let date = item.lastOpenedAt, date > Date().addingTimeInterval(300) { item.lastOpenedAt = nil }
        item.evidence["lastOpenedAt"] = Evidence("Spotlight kMDItemLastUsedDate", confidence: item.lastOpenedAt == nil ? .unknown : .inferred,
            availability: item.lastOpenedAt == nil ? .notAvailable : .available, explanation: "Incomplete system observation; absence does not mean never used")
        let receipt = URL(fileURLWithPath: canonical).appendingPathComponent("Contents/_MASReceipt/receipt").path
        if FileSystem.exists(receipt) {
            item.sources.append(.init(.appStore, Evidence("Local App Store receipt", confidence: .inferred, explanation: "Receipt present; signature and purchase not authenticated")))
            item.primarySource = .appStore
        }
        return item
    }
}

public struct AppStoreScanner: SoftwareScanner {
    public let source: InstallSource = .appStore
    public var native: NativeScanner
    public init(native: NativeScanner) { self.native = native }
    public func scan() async throws -> ScanResult {
        let result = try await native.scan()
        return ScanResult(source, items: result.items.filter { $0.sources.contains { $0.source == .appStore } }, state: result.report.state == .failed ? .failed : nil, message: "Local receipt evidence only; no account access or receipt refresh. " + result.report.message)
    }
}
