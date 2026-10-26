import Foundation
import Darwin

public enum InventoryCommand: Sendable {
    case receipts, receiptInfo(String), receiptFiles(String)
    case brewInstalled(executable: String, cask: Bool), brewDependents(executable: String, token: String), brewServices(executable: String)
    case ports(executable: String), portContents(executable: String, name: String)
    case portDependents(executable: String, name: String, version: String), portExactContents(executable: String, name: String, version: String), managerVersion(executable: String)
    case nix(executable: String, profile: String?), legacyNix(executable: String)

    public var executable: String {
        switch self {
        case .receipts, .receiptInfo, .receiptFiles: "/usr/sbin/pkgutil"
        case .brewInstalled(let path, _), .brewDependents(let path, _), .brewServices(let path): path
        case .ports(let path), .portContents(let path, _), .portDependents(let path, _, _), .portExactContents(let path, _, _), .managerVersion(let path), .nix(let path, _), .legacyNix(let path): path
        }
    }
    public func arguments() throws -> [String] {
        switch self {
        case .brewServices: return ["services", "list", "--json"]
        case .managerVersion: return ["--version"]
        case .portDependents(_, let name, let version), .portExactContents(_, let name, let version):
            guard RemovalIdentity.portName(name), RemovalIdentity.portVersion(version) else { throw ScanError.malformed("Invalid exact port identity") }
            if case .portDependents = self { return ["-q", "dependents", name, "@" + version] }
            return ["-q", "contents", name, "@" + version]
        case .brewInstalled(_, let cask): return ["list", cask ? "--cask" : "--formula", "--versions"]
        case .brewDependents(_, let token):
            guard UninstallPlanner.validToken(token) else { throw ScanError.malformed("Invalid formula token") }
            return ["uses", "--installed", "--recursive", "--", token]
        case .receipts: return ["--pkgs"]
        case .receiptInfo(let id):
            guard FileSystem.validPackageIdentifier(id) else { throw ScanError.malformed("Invalid package identifier") }
            return ["--pkg-info-plist", id]
        case .receiptFiles(let id):
            guard FileSystem.validPackageIdentifier(id) else { throw ScanError.malformed("Invalid package identifier") }
            return ["--files", id]
        case .ports: return ["-q", "installed"]
        case .portContents(_, let name):
            guard FileSystem.validPackageIdentifier(name) else { throw ScanError.malformed("Invalid port name") }
            return ["-q", "contents", name]
        case .nix(_, let profile): return ["--offline", "profile", "list", "--json"] + (profile.map { ["--profile", $0] } ?? [])
        case .legacyNix: return ["--query", "--installed", "--json", "--out-path"]
        }
    }
}
public protocol CommandRunning: Sendable {
    func run(_ command: InventoryCommand) async throws -> Data
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var overflow = false
    private var finished = false
    func append(_ chunk: Data, limit: Int) {
        lock.lock(); defer { lock.unlock() }
        if data.count + chunk.count > limit { overflow = true }
        if data.count < limit { data.append(chunk.prefix(limit - data.count)) }
    }
    func snapshot() -> (Data, Bool) { lock.lock(); defer { lock.unlock() }; return (data, overflow) }
    func finish() { lock.lock(); defer { lock.unlock() }; finished = true }
    var isFinished: Bool { lock.lock(); defer { lock.unlock() }; return finished }
}

/// Only the typed inventory queries above can reach Process. Never invokes a shell.
public struct ProcessRunner: CommandRunning {
    public var timeout: Duration
    public var outputLimit: Int
    public init(timeout: Duration = .seconds(30), outputLimit: Int = 16 * 1024 * 1024) {
        self.timeout = timeout; self.outputLimit = outputLimit
    }
    public func run(_ command: InventoryCommand) async throws -> Data {
        try Task.checkCancellation()
        let clock = ContinuousClock(), deadline = clock.now.advanced(by: timeout)
        guard timeout > .zero else { throw ScanError.timeout }
        let path = command.executable
        let expected: String
        switch command {
        case .brewInstalled, .brewDependents, .brewServices: expected = "brew"; try HomebrewTrust.validateExecutable(path)
        case .receipts, .receiptInfo, .receiptFiles: expected = "pkgutil"
        case .ports, .portContents, .portDependents, .portExactContents: expected = "port"
        case .nix, .managerVersion: expected = "nix"
        case .legacyNix: expected = "nix-env"
        }
        guard path.hasPrefix("/"), URL(fileURLWithPath: path).lastPathComponent == expected,
              FileManager.default.isExecutableFile(atPath: path) else { throw ScanError.process("Missing or invalid \(expected) executable") }
        let process = Process(), pipe = Pipe(), buffer = OutputBuffer()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = try command.arguments()
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                               "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8", "HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ANALYTICS": "1", "HOMEBREW_NO_AUTOREMOVE": "1", "HOMEBREW_NO_INSTALL_CLEANUP": "1", "HOMEBREW_NO_ENV_HINTS": "1", "NIX_PATH": "", "NIX_REMOTE": "", "NIX_CONFIG": "connect-timeout = 1\n"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        // Keep diagnostics out of structured stdout. Failure is reported with exit status.
        process.standardError = FileHandle.nullDevice
        let limit = outputLimit
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { buffer.finish(); handle.readabilityHandler = nil }
            else { buffer.append(data, limit: limit) }
        }
        do {
            try Task.checkCancellation()
            guard clock.now < deadline else { throw ScanError.timeout }
            try process.run()
            try pipe.fileHandleForWriting.close()
            while process.isRunning || !buffer.isFinished {
                if buffer.snapshot().1 { throw ScanError.limit("Command output exceeded limit") }
                if clock.now >= deadline { throw ScanError.timeout }
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(25))
            }
            pipe.fileHandleForReading.readabilityHandler = nil
            try? pipe.fileHandleForReading.close()
            let (output, overflow) = buffer.snapshot()
            if overflow { throw ScanError.limit("Command output exceeded limit") }
            // A fast child and its reader may finish before the loop is entered.
            // Success must still honor cancellation and the original deadline.
            try Task.checkCancellation()
            guard clock.now < deadline else { throw ScanError.timeout }
            guard process.terminationStatus == 0 else { throw ScanError.process("\(expected) query failed (exit \(process.terminationStatus))") }
            return output
        } catch {
            if process.isRunning {
                process.terminate()
                // Bound cleanup even when a child ignores SIGTERM.
                for _ in 0..<20 where process.isRunning { try? await Task.sleep(for: .milliseconds(10)) }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
            pipe.fileHandleForReading.readabilityHandler = nil
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
            throw error
        }
    }
}
