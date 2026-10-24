import AppKit
import Darwin
import Foundation
import CoreServices

public struct AppDataAccessError: Error, LocalizedError, Sendable {
    public var path: String
    public var action: String
    public var detail: String?
    public init(path: String, action: String, detail: String? = nil) { self.path = path; self.action = action; self.detail = detail }
    public var errorDescription: String? {
        "Permission denied while \(action): \(path). " + (detail.map { $0 + " " } ?? "") + "Check folder permissions and macOS Privacy & Security access for Macventory. Nothing was confirmed moved."
    }
}

public enum AppDataSafety {
    public static func validateStructure(_ candidates: [AppDataCandidate]) throws {
        let paths = candidates.map(\.path)
        guard Set(paths).count == paths.count, !paths.contains(where: { path in paths.contains { $0 != path && path.hasPrefix($0 + "/") } }) else {
            throw ScanError.process("Selected targets are duplicated or nested. Review them separately.")
        }
    }
    public static func validateSelection(_ candidates: [AppDataCandidate]) throws {
        var seen = Set<String>()
        for candidate in candidates {
            try Task.checkCancellation()
            let path = candidate.path, root = candidate.allowedRoot
            guard candidate.eligibleForTrash, let identity = candidate.identity, identity.matches(path: path),
                  path == FileSystem.canonical(path), root == FileSystem.canonical(root), path != root,
                  FileSystem.contained(path, in: root), seen.insert(path).inserted,
                  !candidates.contains(where: { $0.path != path && path.hasPrefix($0.path + "/") }) else {
                throw ScanError.process("A selected target is protected, changed, missing, duplicated or nested. Refresh and review it again.")
            }
            var component = path
            while component != "/" {
                var value = stat()
                guard lstat(component, &value) == 0, (value.st_mode & S_IFMT) != S_IFLNK else { throw ScanError.process("A selected path is linked or inaccessible. Refresh and review it again.") }
                component = (component as NSString).deletingLastPathComponent
            }
            guard FileManager.default.isReadableFile(atPath: path) else { throw AppDataAccessError(path: path, action: "reading the selected location") }
            let parent = (path as NSString).deletingLastPathComponent
            guard FileManager.default.isWritableFile(atPath: parent) else { throw AppDataAccessError(path: parent, action: "checking whether the containing folder can be changed") }
        }
    }
}

/// A Finder request cannot be withdrawn once submitted. Timeout releases the modal UI
/// with an explicitly unknown outcome; late callbacks cannot resume a continuation twice.
@MainActor
public final class NativeTrashRequest {
    private var continuation: CheckedContinuation<Void, any Error>?
    private var timeout: Task<Void, Never>?
    private init(_ continuation: CheckedContinuation<Void, any Error>) { self.continuation = continuation }
    public static func recycle(_ url: URL) async throws {
        try Task.checkCancellation()
        try await perform(timeout: .seconds(30)) { completion in
            NSWorkspace.shared.recycle([url]) { moved, error in
                let result: Result<Void, any Error>
                if let error {
                    let cause = error as NSError
                    let denied = (cause.domain == NSCocoaErrorDomain && [NSFileWriteNoPermissionError, NSFileReadNoPermissionError].contains(cause.code)) || (cause.domain == NSPOSIXErrorDomain && [Int(EACCES), Int(EPERM)].contains(cause.code))
                    result = .failure(denied ? AppDataAccessError(path: url.path, action: "asking Finder to move the selected location to Trash", detail: "\(cause.localizedDescription) (\(cause.domain), \(cause.code)).") : ScanError.process("Move to Trash failed: " + error.localizedDescription))
                }
                else if moved[url] == nil { result = .failure(ScanError.process("Finder did not confirm moving the selected target to Trash.")) }
                else { result = .success(()) }
                Task { @MainActor in completion(result) }
            }
        }
    }
    /// Injectable submission is used only by tests, without ever constructing an NSWorkspace request.
    static func perform(timeout duration: Duration, submit: (@escaping @MainActor @Sendable (Result<Void, any Error>) -> Void) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let request = NativeTrashRequest(continuation)
            request.timeout = Task {
                do { try await Task.sleep(for: duration) }
                catch { return }
                request.finish(.failure(AppDataCleanupError.unknownOutcome))
            }
            submit { request.finish($0) }
        }
    }
    private func finish(_ result: Result<Void, any Error>) {
        guard let continuation else { return }
        self.continuation = nil; timeout?.cancel(); timeout = nil
        continuation.resume(with: result)
    }
}

public struct LiveManagementExecutor: ManagementExecuting {
    public init() {}
    public func validate(_ request: ManagementRequest) async throws {
        try ManagementValidation.validateSelection(request)
        // Standalone cleanup validates each independent target during execution so a
        // missing item cannot turn all the other selected items into false failures.
        if request.operations == [.clearData] { return }
        if !request.operations.contains(.forceQuit), request.operations.contains(.clearData) || request.operations.contains(.uninstall) {
            let cleanupIdentities = request.candidates.map { request.identity(for: $0) }
            for identity in Set(cleanupIdentities.isEmpty ? [request.identity] : cleanupIdentities) {
                guard await !ApplicationProcessController.isRunning(identity: identity) else { throw ScanError.process("Quit this application or include its verified Force Quit before cleaning data or uninstalling.") }
            }
        }
        if request.operations.contains(.forceQuit), let item = request.item {
            let fresh = await ApplicationProcessController.target(for: item)
            guard fresh == request.target else { throw ScanError.process("The reviewed process exited or restarted. Reopen for a new confirmation.") }
        }
        if request.operations.contains(.clearData) {
            let remaining = request.candidates.filter { NativeAppDataPresenceChecker().presence($0.path) != .missing }
            try AppDataSafety.validateSelection(remaining)
            for identity in Set(request.candidates.map { request.identity(for: $0) }) where request.item == nil {
                if let id = identity.bundleID {
                    let urls = LSCopyApplicationURLsForBundleIdentifier(id as CFString, nil)?.takeRetainedValue() as? [URL] ?? []
                    guard !urls.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) else { throw ScanError.process("This application is now installed. Use its inventory row to review active application data.") }
                }
            }
            for candidate in remaining where candidate.category != "Manually selected location" && candidate.category != "Personal Folder" {
                let fresh = AppDataDiscoveryService().discover(for: request.identity(for: candidate))
                guard fresh.candidates.contains(where: { $0.path == candidate.path && $0.identity == candidate.identity && $0.eligibleForTrash && (candidate.classification != .verified || $0.classification == .verified) }) else { throw ScanError.process("Data ownership evidence changed. Refresh and review again.") }
            }
        }
        if let plan = request.uninstallPlan, request.operations.contains(.uninstall) {
            // The planner may preview a running app for a combined operation; ownership and
            // bundle fingerprint are still rechecked before any process or data side effect.
            try await FreshUninstallValidator(allowRunningDuringPreflight: request.operations.contains(.forceQuit)).validate(plan)
        }
    }
    public func perform(_ operation: ManagementOperation, request: ManagementRequest) async throws -> ManagementStepResult {
        switch operation {
        case .forceQuit:
            guard let item = request.item, let target = request.target else { throw ScanError.process("No exact process identity.") }
            guard try await LiveQuitExecutor().execute(QuitPlan(item: item, target: target, mode: .force)) else { throw ScanError.process("Process exit was not confirmed. Later steps were skipped.") }
            return .init(operation, .completed, "The reviewed process exited; helpers or background services may remain.")
        case .clearData:
            let outcome = await AppDataCleanupRunner.run(request.candidates, validate: { candidate in
                let identity = request.identity(for: candidate)
                guard await !ApplicationProcessController.isRunning(identity: identity) else { throw ScanError.process("The application is running. This item was left untouched.") }
                if request.item == nil {
                    for id in Set([identity.bundleID, identity.parentBundleID].compactMap { $0 }) {
                        let urls = LSCopyApplicationURLsForBundleIdentifier(id as CFString, nil)?.takeRetainedValue() as? [URL] ?? []
                        guard !urls.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) else { throw ScanError.process("The application or its parent is installed again. Review its inventory row.") }
                    }
                }
                let service = AppDataDiscoveryService()
                if candidate.category == "Manually selected location" || candidate.category == "Personal Folder" {
                    guard service.manualCandidate(path: candidate.path)?.identity == candidate.identity else { throw ScanError.process("Personal folder identity or safety changed. Review it again.") }
                } else {
                    let fresh = service.discover(for: identity)
                    guard fresh.candidates.contains(where: { $0.path == candidate.path && $0.identity == candidate.identity && $0.eligibleForTrash }) else { throw ScanError.process("Data ownership evidence changed. Review this item again.") }
                }
            }, recycle: { candidate in
                try await LiveAppDataExecutor(applicationIdentity: request.identity(for: candidate)).recycle(candidate)
            })
            return .init(operation, outcome.stepStatus, outcome.summary, cleanupResults: outcome.results)
        case .uninstall:
            guard let plan = request.uninstallPlan else { throw ScanError.process("Missing reviewed uninstall plan.") }
            _ = try await LiveUninstallExecutor().execute(plan)
            return .init(operation, .completed, "Refresh the inventory to verify the remaining installation state.")
        }
    }
}
