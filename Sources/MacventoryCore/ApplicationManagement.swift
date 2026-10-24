import AppKit
import Darwin
import Foundation

/// Minimal, non-sensitive identity retained after a confirmed Macventory removal.
/// It intentionally contains no inventory snapshot, document list, or application bundle.
public struct RemovedApplicationRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: String { bundleID ?? "removed:" + name.lowercased() }
    public var name: String
    public var bundleID: String?
    public var source: InstallSource
    public var ownershipEvidence: String
    public var removalDate: Date
    public var installationPath: String?
    public init(item: SoftwareItem, removalDate: Date = Date()) {
        name = item.name; bundleID = item.bundleID; source = item.primarySource
        ownershipEvidence = item.sources.map { $0.source.title + ": " + $0.evidence.origin }.joined(separator: "; ")
        self.removalDate = removalDate; installationPath = item.path
    }
    public init(name: String, bundleID: String?, source: InstallSource = .unknown, ownershipEvidence: String, removalDate: Date = Date(), installationPath: String? = nil) {
        self.name = name; self.bundleID = bundleID; self.source = source; self.ownershipEvidence = ownershipEvidence
        self.removalDate = removalDate; self.installationPath = installationPath
    }
}

public actor RemovedApplicationStore {
    public let url: URL
    public init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Macventory", isDirectory: true).appendingPathComponent("removed-applications.json")
    }
    public init(directoryURL: URL?) {
        self.url = (directoryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Macventory", isDirectory: true))
            .appendingPathComponent("removed-applications.json")
    }
    public func load() throws -> [RemovedApplicationRecord] {
        guard FileSystem.exists(url.path) else { return [] }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max < 1_048_576 else { throw ScanError.limit("Recently removed record exceeds 1 MiB") }
        return try JSONDecoder().decode([RemovedApplicationRecord].self, from: Data(contentsOf: url))
    }
    public func record(_ record: RemovedApplicationRecord) throws {
        var records = try load()
        records.removeAll { $0.id == record.id }
        records.append(record)
        records.sort { $0.removalDate > $1.removalDate }
        let data = try JSONEncoder().encode(records)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

public enum AppDataClassification: String, Codable, CaseIterable, Sendable {
    case verified, possible, protected
    public var title: String {
        switch self { case .verified: "Verified App Data"; case .possible: "Possible Related Files"; case .protected: "Shared or Protected Data" }
    }
}

public struct ApplicationIdentity: Codable, Hashable, Sendable, Identifiable {
    public var namingSource: String? = nil
    public var namingConfidence: String? = nil
    public var vendor: String? = nil
    public var parentBundleID: String? = nil
    public var parentApplicationName: String? = nil
    public var id: String { bundleID ?? "name:" + name.lowercased() }
    public var name: String
    public var bundleID: String?
    public var source: InstallSource
    public var installationPath: String?
    public var evidence: String
    public var installed: Bool
    public init(item: SoftwareItem) {
        name = item.name; bundleID = item.bundleID; source = item.primarySource; installationPath = item.path
        evidence = item.sources.map { $0.evidence.origin }.joined(separator: "; "); installed = true
    }
    public init(record: RemovedApplicationRecord) {
        name = record.name; bundleID = record.bundleID; source = record.source; installationPath = record.installationPath
        evidence = record.ownershipEvidence; installed = false
    }
    public init(name: String, bundleID: String?, source: InstallSource = .unknown, installationPath: String? = nil, evidence: String, installed: Bool) {
        self.name = name; self.bundleID = bundleID; self.source = source; self.installationPath = installationPath; self.evidence = evidence; self.installed = installed
    }
}

public struct FileIdentity: Codable, Hashable, Sendable {
    public var device: UInt64
    public var inode: UInt64
    public var modified: Double
    public init?(path: String) {
        var value = stat()
        guard lstat(path, &value) == 0 else { return nil }
        device = UInt64(value.st_dev); inode = UInt64(value.st_ino); modified = Double(value.st_mtimespec.tv_sec) + Double(value.st_mtimespec.tv_nsec) / 1_000_000_000
    }
    public func matches(path: String) -> Bool { FileIdentity(path: path) == self }
}

public struct AppDataCandidate: Codable, Identifiable, Hashable, Sendable {
    public var id: String { path }
    public var path: String
    public var category: String
    public var classification: AppDataClassification
    public var explanation: String
    public var sizeBytes: Int64?
    public var sizeComplete: Bool
    public var requiresExplicitSelection: Bool
    public var allowedRoot: String
    public var identity: FileIdentity?
    public var contentsSummary: String? = nil
    public var validationMessage: String? = nil
    public var classificationTitle: String { classification.title + (category == "Personal Folder" && classification == .possible ? " — Manual Review Required" : "") }
    public init(path: String, category: String, classification: AppDataClassification, explanation: String, sizeBytes: Int64?, sizeComplete: Bool, requiresExplicitSelection: Bool, allowedRoot: String, identity: FileIdentity?) {
        self.path = path; self.category = category; self.classification = classification; self.explanation = explanation
        self.sizeBytes = sizeBytes; self.sizeComplete = sizeComplete; self.requiresExplicitSelection = requiresExplicitSelection
        self.allowedRoot = allowedRoot; self.identity = identity
    }
    public var eligibleForTrash: Bool { classification != .protected }
    public var isAutomaticSelection: Bool { classification == .verified && eligibleForTrash && !requiresExplicitSelection }
}

public struct AppDataDiscoveryResult: Sendable {
    public var identity: ApplicationIdentity
    public var candidates: [AppDataCandidate]
    public var messages: [String]
    public init(identity: ApplicationIdentity, candidates: [AppDataCandidate], messages: [String] = []) { self.identity = identity; self.candidates = candidates; self.messages = messages }
}

/// Bounded, source-aware discovery. It performs exact direct-child checks only; it never
/// searches Documents, Desktop, Downloads, external volumes, or the whole home directory.
public struct AppDataDiscoveryService: Sendable {
    public var library: URL
    public var home: URL
    public init(library: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true), home: URL = FileManager.default.homeDirectoryForCurrentUser) { self.library = library; self.home = home }

    public func discover(for identity: ApplicationIdentity) -> AppDataDiscoveryResult {
        guard let bundleID = identity.bundleID, FileSystem.validPackageIdentifier(bundleID), !bundleID.contains("/"), !bundleID.hasPrefix("com.apple.") else {
            return AppDataDiscoveryResult(identity: identity, candidates: [], messages: ["A verified bundle identifier is required for automatic data discovery. Use manual review to inspect personal locations."])
        }
        let fm = FileManager.default
        var candidates: [AppDataCandidate] = [], messages: [String] = []
        func add(_ relative: String, category: String, classification: AppDataClassification, explanation: String, manual: Bool = false) {
            let root = library.appendingPathComponent(relative.split(separator: "/").first.map(String.init) ?? relative).path
            let path = library.appendingPathComponent(relative).path
            guard fm.fileExists(atPath: path) else { return }
            guard isSafe(path: path, inside: root) else { messages.append("Skipped unsafe or inaccessible candidate: \(path)"); return }
            let size = try? SizeMeasurer.measure(path, maximumEntries: 10_000)
            var candidate = AppDataCandidate(path: path, category: category, classification: classification, explanation: explanation, sizeBytes: size?.bytes, sizeComplete: size?.complete ?? false, requiresExplicitSelection: manual || classification != .verified, allowedRoot: root, identity: FileIdentity(path: path))
            candidate.contentsSummary = size.map { "\($0.files.count) regular file(s) measured" + ($0.complete ? "; logical size excludes external symlink targets." : "; contents summary and size are incomplete.") }
            candidates.append(candidate)
        }
        add("Containers/\(bundleID)", category: "App Container", classification: .verified, explanation: "Exact sandbox container identifier matches the application bundle identifier.")
        add("Application Support/\(bundleID)", category: "Application Support", classification: .verified, explanation: "Exact application-support directory matches the bundle identifier.")
        add("Caches/\(bundleID)", category: "Caches", classification: .verified, explanation: "Exact cache directory matches the bundle identifier.")
        add("Logs/\(bundleID)", category: "Logs", classification: .verified, explanation: "Exact log directory matches the bundle identifier.")
        add("WebKit/\(bundleID)", category: "WebKit", classification: .verified, explanation: "Exact WebKit directory matches the bundle identifier.")
        add("Saved Application State/\(bundleID).savedState", category: "Saved Application State", classification: .verified, explanation: "Exact saved-state identifier matches the bundle identifier.")
        add("Preferences/\(bundleID).plist", category: "Preferences", classification: .verified, explanation: "Exact preference filename matches the bundle identifier.")
        // Group containers can be shared by apps from the same developer; inspection is useful,
        // but they are never offered for automatic cleanup.
        add("Group Containers/\(bundleID)", category: "Group Container", classification: .protected, explanation: "An exact group-container name was found, but group containers may be shared and are protected.")
        // A direct, exact display-name directory is a review lead only. No substring matching.
        if !identity.name.isEmpty, !identity.name.contains("/") {
            add("Application Support/\(identity.name)", category: "Application Support", classification: .possible, explanation: "Exact display-name directory; it may contain user-created or shared data and requires individual review.", manual: true)
            add("Caches/\(identity.name)", category: "Caches", classification: .possible, explanation: "Exact display-name directory; name matching alone is not ownership proof.", manual: true)
        }
        return AppDataDiscoveryResult(identity: identity, candidates: deduplicate(candidates), messages: messages)
    }
    /// Adds an explicitly user-chosen file/folder as a review-only candidate. Callers must use
    /// a file picker; this method intentionally does not enumerate user-document locations.
    public func manualCandidate(path: String, maximumEntries: Int = 10_000) -> AppDataCandidate? {
        let canonical = FileSystem.canonical(path), homePath = home.path
        guard !["Library", "Documents", "Downloads", "Desktop", "Applications"].contains(URL(fileURLWithPath: canonical).lastPathComponent),
              !canonical.contains(".app/"), !canonical.hasSuffix(".app"),
              !FileSystem.contained(canonical, in: home.appendingPathComponent("Library").path),
              FileSystem.contained(canonical, in: homePath), canonical != homePath, isSafe(path: path, inside: homePath) else { return nil }
        let size = try? SizeMeasurer.measure(canonical, maximumEntries: maximumEntries)
        var candidate = AppDataCandidate(path: canonical, category: "Manually selected location", classification: .possible, explanation: "User-selected path. Personal files or projects may be included; review contents before moving it to Trash.", sizeBytes: size?.bytes, sizeComplete: size?.complete ?? false, requiresExplicitSelection: true, allowedRoot: homePath, identity: FileIdentity(path: canonical))
        candidate.contentsSummary = size.map { "\($0.files.count) regular file(s) measured" + ($0.complete ? "; inspect contents in Finder before confirming." : "; incomplete preview — inspect contents in Finder.") }
        return candidate
    }
    private func deduplicate(_ values: [AppDataCandidate]) -> [AppDataCandidate] {
        var result: [AppDataCandidate] = []
        for item in values.sorted(by: { $0.path.count < $1.path.count }) where !result.contains(where: { $0.path == item.path || item.path.hasPrefix($0.path + "/") }) { result.append(item) }
        return result.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
    private func isSafe(path: String, inside root: String) -> Bool {
        let fm = FileManager.default, unresolved = URL(fileURLWithPath: path).standardizedFileURL.path, unresolvedRoot = URL(fileURLWithPath: root).standardizedFileURL.path
        // Inspect the path as supplied before resolving it: a link which happens to point
        // back into Library is still not a safe cleanup candidate.
        var unresolvedComponent = unresolved
        while FileSystem.contained(unresolvedComponent, in: unresolvedRoot) {
            var value = stat(); guard lstat(unresolvedComponent, &value) == 0, (value.st_mode & S_IFMT) != S_IFLNK else { return false }
            if unresolvedComponent == unresolvedRoot { break }; unresolvedComponent = (unresolvedComponent as NSString).deletingLastPathComponent
        }
        let canonical = FileSystem.canonical(unresolved), root = FileSystem.canonical(root)
        guard FileSystem.contained(canonical, in: root), canonical != root, fm.isReadableFile(atPath: canonical) else { return false }
        var component = canonical
        while FileSystem.contained(component, in: root) {
            var value = stat(); guard lstat(component, &value) == 0, (value.st_mode & S_IFMT) != S_IFLNK else { return false }
            if component == root { break }; component = (component as NSString).deletingLastPathComponent
        }
        return true
    }
}

public struct AppDataCleanupItemResult: Sendable, Identifiable {
    public var id: String { candidate.path }
    public var candidate: AppDataCandidate
    public var message: String
    public var status: AppDataItemStatus
    public var completed: Bool { status == .moved }
    public init(candidate: AppDataCandidate, message: String, completed: Bool) { self.candidate = candidate; self.message = message; self.status = completed ? .moved : .failed }
    public init(candidate: AppDataCandidate, status: AppDataItemStatus, message: String) { self.candidate = candidate; self.status = status; self.message = message }
}
public struct AppDataCleanupOutcome: Sendable {
    public var results: [AppDataCleanupItemResult]
    public var simulated: Bool
    public var stepStatus: ManagementStepStatus {
        if results.allSatisfy({ $0.status == .moved || $0.status == .alreadyRemoved }), !results.isEmpty { return .completed }
        return results.contains { $0.status == .moved || $0.status == .alreadyRemoved } ? .partial : .failed
    }
    public var summary: String {
        let completed = results.filter(\.completed).count, absent = results.filter { $0.status == .alreadyRemoved }.count
        let unresolved = results.count - completed - absent
        if simulated { return "Simulation finished. No files changed. Simulated moves: \(completed); \(absent) already absent; \(unresolved) unresolved." }
        return "\(completed) moved to Trash; \(absent) already removed; \(unresolved) unresolved."
    }
}
public protocol AppDataExecuting: Sendable { func execute(_ candidates: [AppDataCandidate]) async -> AppDataCleanupOutcome }
public struct SimulatedAppDataExecutor: AppDataExecuting {
    public init() {}
    public func execute(_ candidates: [AppDataCandidate]) async -> AppDataCleanupOutcome { AppDataCleanupOutcome(results: candidates.map { AppDataCleanupItemResult(candidate: $0, message: "Simulated; no data changed.", completed: true) }, simulated: true) }
}
public struct LiveAppDataExecutor: AppDataExecuting {
    private let applicationIdentities: [ApplicationIdentity]
    public init(applicationIdentity: ApplicationIdentity? = nil) { self.applicationIdentities = applicationIdentity.map { [$0] } ?? [] }
    public init(applicationIdentities: [ApplicationIdentity]) { self.applicationIdentities = applicationIdentities }
    public func execute(_ candidates: [AppDataCandidate]) async -> AppDataCleanupOutcome {
        await AppDataCleanupRunner.run(candidates, recycle: { try await recycle($0) })
    }
    @MainActor func recycle(_ candidate: AppDataCandidate) async throws {
        try AppDataSafety.validateSelection([candidate])
        for identity in Set(applicationIdentities) where ApplicationProcessController.isRunning(identity: identity) {
            throw ScanError.process("The application or a bundled helper restarted. This item was left untouched.")
        }
        try await NativeTrashRequest.recycle(URL(fileURLWithPath: candidate.path))
    }
}

public enum QuitMode: String, Sendable { case normal, force }
public struct RunningApplicationTarget: Sendable, Hashable {
    public var processIdentifier: pid_t
    public var bundleURL: String
    public var bundleID: String
    public var launchedAt: Date?
    public init(processIdentifier: pid_t, bundleURL: String, bundleID: String, launchedAt: Date? = nil) { self.processIdentifier = processIdentifier; self.bundleURL = bundleURL; self.bundleID = bundleID; self.launchedAt = launchedAt }
}
public struct QuitPlan: Sendable, Identifiable {
    public var id = UUID(); public var item: SoftwareItem; public var target: RunningApplicationTarget; public var mode: QuitMode; public var createdAt = Date()
    public init(item: SoftwareItem, target: RunningApplicationTarget, mode: QuitMode) { self.item = item; self.target = target; self.mode = mode }
}
public enum ApplicationProcessController {
    @MainActor public static func target(for item: SoftwareItem) -> RunningApplicationTarget? {
        guard !item.isSystem, let path = item.path, let bundleID = item.bundleID, !bundleID.hasPrefix("com.apple."), bundleID != "org.vadimtanel.Macventory" else { return nil }
        return NSWorkspace.shared.runningApplications.first(where: { app in
            app.bundleIdentifier == bundleID && app.bundleURL.map { FileSystem.canonical($0.path) == path } == true && !app.isTerminated
        }).map { RunningApplicationTarget(processIdentifier: $0.processIdentifier, bundleURL: path, bundleID: bundleID, launchedAt: $0.launchDate) }
    }
    @MainActor public static func isRunning(identity: ApplicationIdentity) -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            guard !app.isTerminated else { return false }
            if let id = identity.bundleID, app.bundleIdentifier == id { return true }
            guard let root = identity.installationPath else { return false }
            return [app.bundleURL, app.executableURL].compactMap { $0 }.contains { FileSystem.contained($0.path, in: root) }
        }
    }
}
public protocol QuitExecuting: Sendable { func execute(_ plan: QuitPlan) async throws -> Bool }
public struct SimulatedQuitExecutor: QuitExecuting { public init() {}; public func execute(_ plan: QuitPlan) async throws -> Bool { true } }
public struct LiveQuitExecutor: QuitExecuting {
    public init() {}
    public func execute(_ plan: QuitPlan) async throws -> Bool {
        let requested = try await MainActor.run { () throws -> Bool in
            try Task.checkCancellation()
            guard !plan.item.isSystem, plan.item.bundleID == plan.target.bundleID, !plan.target.bundleID.hasPrefix("com.apple."),
                  plan.target.bundleID != "org.vadimtanel.Macventory", plan.target.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  plan.item.path == plan.target.bundleURL, Date().timeIntervalSince(plan.createdAt) < 300,
                  let app = NSRunningApplication(processIdentifier: plan.target.processIdentifier), app.bundleIdentifier == plan.target.bundleID,
                  app.launchDate == plan.target.launchedAt, app.bundleURL.map({ FileSystem.canonical($0.path) == plan.target.bundleURL }) == true, !app.isTerminated else { throw ScanError.process("The application exited, restarted, or no longer matches the reviewed bundle. Prepare a new confirmation.") }
            return plan.mode == .force ? app.forceTerminate() : app.terminate()
        }
        guard requested else { throw ScanError.process(plan.mode == .force ? "macOS declined Force Quit." : "macOS declined Quit.") }
        let deadline = ContinuousClock.now.advanced(by: .seconds(8))
        while ContinuousClock.now < deadline {
            let exited = await MainActor.run { NSRunningApplication(processIdentifier: plan.target.processIdentifier)?.isTerminated ?? true }
            if exited { return true }
            try await Task.sleep(for: .milliseconds(100))
        }
        return false
    }
}
