import Foundation
import Darwin

public enum AppDataPresence: Sendable, Equatable { case present, missing, permissionDenied, inconclusive }
public protocol AppDataPresenceChecking: Sendable { func presence(_ path: String) -> AppDataPresence }
public struct NativeAppDataPresenceChecker: AppDataPresenceChecking {
    public init() {}
    public func presence(_ path: String) -> AppDataPresence {
        var value = stat()
        if lstat(path, &value) == 0 { return .present }
        let failure = errno
        if failure == EACCES || failure == EPERM { return .permissionDenied }
        guard failure == ENOENT else { return .inconclusive }
        // ENOENT through a dangling symlink is not proof that the reviewed target
        // disappeared. Inspect ancestors without following links or reading contents.
        var parent = (path as NSString).deletingLastPathComponent
        while !parent.isEmpty {
            if lstat(parent, &value) == 0 {
                guard (value.st_mode & S_IFMT) == S_IFDIR else { return .inconclusive }
                guard access(parent, X_OK) == 0 else { return .permissionDenied }
            } else if errno == EACCES || errno == EPERM { return .permissionDenied }
            else if errno != ENOENT { return .inconclusive }
            if parent == "/" { break }
            parent = (parent as NSString).deletingLastPathComponent
        }
        return .missing
    }
}

public enum AppDataItemStatus: String, Sendable {
    case moved = "Moved to Trash", alreadyRemoved = "No Longer Exists", permissionDenied = "Permission Denied"
    case changed = "Changed Since Scan", protected = "Shared/Protected Data", failed = "Cleanup Failed"
    case unknown = "Outcome Unknown", skipped = "Skipped"
}
public enum AppDataCleanupError: Error, LocalizedError {
    case unknownOutcome
    public var errorDescription: String? { "Finder has not confirmed the Trash request within 30 seconds. Its outcome is unknown; the request may still finish. Check Finder and refresh before any new attempt." }
}

public enum LeftoverReconciliation {
    public static func reconcile(_ groups: [AppDataDiscoveryResult], checking: any AppDataPresenceChecking = NativeAppDataPresenceChecker()) -> [AppDataDiscoveryResult] {
        groups.compactMap { original in
            var group = original
            group.candidates = group.candidates.compactMap { original in
                var candidate = original
                switch checking.presence(candidate.path) {
                case .missing: return nil
                case .permissionDenied: candidate.validationMessage = "Permission Denied — this location could not be checked."
                case .inconclusive: candidate.validationMessage = "Scan Failed — this location could not be verified."
                case .present:
                    candidate.validationMessage = candidate.identity?.matches(path: candidate.path) == false ? "Changed Since Scan — refresh and review this location again." : nil
                }
                return candidate
            }
            return group.candidates.isEmpty ? nil : group
        }
    }
}

/// Dependencies are injected in tests: this runner itself submits no native operations.
public enum AppDataCleanupRunner {
    public static func run(_ candidates: [AppDataCandidate], simulated: Bool = false,
                           checking: any AppDataPresenceChecking = NativeAppDataPresenceChecker(),
                           validate: @Sendable (AppDataCandidate) async throws -> Void = { _ in },
                           recycle: @Sendable (AppDataCandidate) async throws -> Void) async -> AppDataCleanupOutcome {
        do { try AppDataSafety.validateStructure(candidates) }
        catch { return .init(results: candidates.map { .init(candidate: $0, status: .failed, message: error.localizedDescription) }, simulated: simulated) }
        var results: [AppDataCleanupItemResult] = []
        var unknownOutcome = false
        for candidate in candidates {
            if unknownOutcome || Task.isCancelled {
                results.append(.init(candidate: candidate, status: .skipped, message: unknownOutcome ? "Not submitted after an unknown Trash outcome. Check Finder before a new review." : "Cancelled before submission.")); continue
            }
            guard candidate.eligibleForTrash else {
                results.append(.init(candidate: candidate, status: .protected, message: "Shared or protected data cannot be moved.")); continue
            }
            switch checking.presence(candidate.path) {
            case .missing: results.append(.init(candidate: candidate, status: .alreadyRemoved, message: "Already absent. Macventory did not remove this item.")); continue
            case .permissionDenied: results.append(.init(candidate: candidate, status: .permissionDenied, message: AppDataAccessError(path: candidate.path, action: "checking the selected location").localizedDescription)); continue
            case .inconclusive: results.append(.init(candidate: candidate, status: .failed, message: "The filesystem check was inconclusive. The observation is retained.")); continue
            case .present: break
            }
            var submitted = false
            do {
                try AppDataSafety.validateSelection([candidate])
                try await validate(candidate)
                try Task.checkCancellation()
                submitted = true
                try await recycle(candidate)
                results.append(.init(candidate: candidate, status: .moved, message: simulated ? "Simulated; no files changed." : "Finder confirmed moving this item to Trash."))
            } catch AppDataCleanupError.unknownOutcome {
                unknownOutcome = true
                results.append(.init(candidate: candidate, status: .unknown, message: AppDataCleanupError.unknownOutcome.localizedDescription))
            } catch {
                let status: AppDataItemStatus
                if submitted && checking.presence(candidate.path) == .missing { status = .unknown; unknownOutcome = true }
                else if !submitted && checking.presence(candidate.path) == .missing { status = .alreadyRemoved }
                else if error is CancellationError { status = .skipped }
                else if error is AppDataAccessError { status = .permissionDenied }
                else if case ScanError.permission = error { status = .permissionDenied }
                else if case ScanError.process(let reason) = error, reason.contains("changed") || reason.contains("linked") { status = .changed }
                else { status = .failed }
                let message = status == .alreadyRemoved ? "No longer exists; no removal is attributed to Macventory." : status == .unknown ? "The request may have finished, but confirmation failed. Check Finder before any new review." : error.localizedDescription
                results.append(.init(candidate: candidate, status: status, message: message))
            }
        }
        return .init(results: results, simulated: simulated)
    }
}
