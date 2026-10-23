import Foundation
import Darwin

public enum InventoryCommand: Sendable {
    case receipts, receiptInfo(String), receiptFiles(String)
    case ports(executable: String), portContents(executable: String, name: String)
    case nix(executable: String, profile: String?), legacyNix(executable: String)

    public var executable: String {
        switch self {
        case .receipts, .receiptInfo, .receiptFiles: "/usr/sbin/pkgutil"
        case .ports(let path), .portContents(let path, _), .nix(let path, _), .legacyNix(let path): path
        }
    }
    public func arguments() throws -> [String] {
        switch self {
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
        let path = command.executable
        let expected: String
        switch command {
        case .receipts, .receiptInfo, .receiptFiles: expected = "pkgutil"
        case .ports, .portContents: expected = "port"
        case .nix: expected = "nix"
        case .legacyNix: expected = "nix-env"
        }
        guard path.hasPrefix("/"), URL(fileURLWithPath: path).lastPathComponent == expected,
              FileManager.default.isExecutableFile(atPath: path) else { throw ScanError.process("Missing or invalid \(expected) executable") }
        let process = Process(), pipe = Pipe(), buffer = OutputBuffer()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = try command.arguments()
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                               "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8", "NIX_PATH": "", "NIX_REMOTE": "", "NIX_CONFIG": "connect-timeout = 1\n"]
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
        let clock = ContinuousClock(), deadline = clock.now.advanced(by: timeout)
        do {
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
