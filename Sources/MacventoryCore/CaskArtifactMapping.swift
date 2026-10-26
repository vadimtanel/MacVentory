import Foundation
import Darwin

/// Declarative targets only. Executable uninstall directives are reviewed separately.
struct CaskMappedArtifact {
    var kind: String
    var path: String
    var caskRoot: String
    static func read(receipt: [String: Any], config: [String: Any], root: String) throws -> [Self] {
        let prefix = URL(fileURLWithPath: root).deletingLastPathComponent().deletingLastPathComponent().path
        let explicit = config["explicit"] as? [String: Any] ?? [:], defaults = config["default"] as? [String: Any] ?? [:]
        var result: [Self] = []
        for artifact in receipt["uninstall_artifacts"] as? [[String: Any]] ?? [] {
            for kind in ["app", "font", "binary"] {
                guard let entries = artifact[kind] as? [Any] else { continue }
                guard entries.compactMap({ $0 as? String }).count == 1, let source = entries.first as? String,
                      !source.isEmpty, source != ".", (kind == "binary" || !source.hasPrefix("/")), !source.split(separator: "/").contains("..") else { throw ScanError.malformed("Unsafe or unsupported cask artifact mapping") }
                let target = entries.dropFirst().compactMap { ($0 as? [String: Any])?["target"] as? String }.first ?? URL(fileURLWithPath: source).lastPathComponent
                guard !target.hasPrefix("/"), !target.contains("/"), target != ".", target != "..", !target.isEmpty else { throw ScanError.malformed("Unsafe cask target") }
                let key = kind == "app" ? "appdir" : kind == "font" ? "fontdir" : "binarydir"
                let fallback = kind == "app" ? "/Applications" : kind == "font" ? FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Fonts" : prefix + "/bin"
                let directory = explicit[key] as? String ?? defaults[key] as? String ?? fallback
                guard directory.hasPrefix("/"), kind != "app" || target.hasSuffix(".app"), kind != "binary" || directory == prefix + "/bin" else { throw ScanError.malformed("Unsupported cask artifact directory") }
                result.append(.init(kind: kind, path: URL(fileURLWithPath: directory).appendingPathComponent(target).standardizedFileURL.path, caskRoot: root))
            }
        }
        return result
    }
    func validateForRemoval(ownedAppRoots: [String] = []) throws {
        guard !ProtectionPolicy.protectedPath(path), !path.contains(".app/"), !ProtectionPolicy.isRunningCopy([path]) else { throw ScanError.process("Cask target is protected or includes the running Macventory copy") }
        let observation = ArtifactObservation.inspect(path)
        guard observation.presence != .inaccessible else { throw ScanError.permission }
        if kind == "binary", observation.presence != .missing {
            let a = try FileManager.default.attributesOfItem(atPath: path)
            guard a[.type] as? FileAttributeType == .typeSymbolicLink else { throw ScanError.process("The cask binary link was replaced by an unrelated file") }
            let link = try FileManager.default.destinationOfSymbolicLink(atPath: path)
            let target = link.hasPrefix("/") ? link : ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent(link)
            guard ([caskRoot] + ownedAppRoots).contains(where: { FileSystem.contained(target, in: $0) }) else { throw ScanError.process("The binary link no longer belongs to this exact cask") }
        } else {
            guard observation.presence != .brokenLink, path == FileSystem.canonical(path) else { throw ScanError.process("Cask artifact is linked or changed") }
        }
        if observation.presence == .present {
            var info = stat()
            guard lstat(path, &info) == 0, info.st_flags & UInt32(UF_IMMUTABLE | SF_IMMUTABLE | SF_RESTRICTED) == 0 else { throw ScanError.process("macOS protects this cask artifact") }
        }
    }
}
