import Foundation
import Darwin

public enum FileSystem {
    public static func canonical(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL.resolvingSymlinksInPath().path
    }
    public static func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: path) }
    public static func children(_ path: String) throws -> [URL] {
        // Finder-hidden app links (notably Safari on recent macOS) remain inventory candidates.
        // Exclude dotfiles explicitly instead of dropping every NSURLIsHidden resource.
        try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [])
            .filter { !$0.lastPathComponent.hasPrefix(".") }.sorted { $0.path < $1.path }
    }
    public static func json(_ path: String, limit: Int = 16 * 1024 * 1024) throws -> [String: Any] {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= limit else { throw ScanError.limit("Manifest exceeds size limit") }
        guard let result = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as? [String: Any] else { throw ScanError.malformed("Expected JSON object: \(URL(fileURLWithPath: path).lastPathComponent)") }
        return result
    }
    public static func date(_ value: Any?) -> Date? {
        guard let number = value as? NSNumber, number.doubleValue > 0 else { return nil }
        let date = Date(timeIntervalSince1970: number.doubleValue)
        return date <= Date().addingTimeInterval(300) ? date : nil
    }
    public static func text(_ path: String, limit: Int = 4 * 1024 * 1024) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= limit else { throw ScanError.limit("Text manifest exceeds size limit") }
        return try String(contentsOfFile: path, encoding: .utf8)
    }
    public static func contained(_ path: String, in root: String) -> Bool {
        let path = canonical(path), root = canonical(root)
        return path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }
    public static func validPackageIdentifier(_ text: String) -> Bool {
        !text.isEmpty && text.count < 512 && text.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._+@/-")).contains($0) } && !text.hasPrefix("-") && !text.contains("..")
    }
}
public enum ScanError: Error, LocalizedError, Sendable {
    case malformed(String), limit(String), process(String), timeout, permission
    public var errorDescription: String? {
        switch self {
        case .malformed(let text), .limit(let text), .process(let text): text
        case .timeout: "Command timed out"
        case .permission: "Access denied"
        }
    }
}
public struct Footprint: Sendable {
    public var bytes: Int64
    public var complete: Bool
    public var files: [String: Int64]
}
public enum SizeMeasurer {
    public static func measure(_ path: String, maximumEntries: Int = 300_000) throws -> Footprint {
        let root = URL(fileURLWithPath: FileSystem.canonical(path))
        var files: [String: Int64] = [:], complete = true, count = 0
        func add(_ url: URL) {
            var info = stat()
            if lstat(url.path, &info) != 0 { complete = false; return }
            guard (info.st_mode & S_IFMT) == S_IFREG else { return }
            let key = "\(info.st_dev):\(info.st_ino)"
            files[key] = Int64(info.st_size)
        }
        let values = try root.resourceValues(forKeys: [.isDirectoryKey])
        if values.isDirectory != true { add(root) }
        else if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [], errorHandler: { _, _ in complete = false; return true }) {
            for case let url as URL in enumerator {
                try Task.checkCancellation()
                count += 1
                if count > maximumEntries { complete = false; break }
                if url.pathComponents.count - root.pathComponents.count > 64 { enumerator.skipDescendants(); complete = false; continue }
                add(url)
            }
        } else { complete = false }
        return Footprint(bytes: files.values.reduce(0, +), complete: complete, files: files)
    }
}
