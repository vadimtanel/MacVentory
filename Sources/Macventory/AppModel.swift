import SwiftUI
import AppKit
import MacventoryCore
import CoreServices

@MainActor
final class AppModel: ObservableObject {
    @Published var items: [SoftwareItem] = []
    @Published var reports: [SourceReport] = []
    @Published var scanning = false
    @Published var progress = "Ready to scan"
    @Published var error: String?
    @Published var uninstallPlan: UninstallPlan?
    @Published var uninstallMessage: String?
    @Published var uninstallWorking = false
    @Published var uninstallPreparing = false
    @Published var uninstallOutcome: UninstallOutcome?
    @Published var managementItem: SoftwareItem?
    @Published var managementDiscovery: AppDataDiscoveryResult?
    @Published var managementTarget: RunningApplicationTarget?
    @Published var managementUninstallPlan: UninstallPlan?
    @Published var managementMessage: String?
    @Published var managementWorking = false
    @Published var managementPreparing = false
    @Published var managementResult: ManagementResult?
    @Published var leftoverGroups: [AppDataDiscoveryResult] = []
    @Published var leftoverScanState: LeftoverScanState = .notScanned
    @Published var leftoverMessages: [String] = []
    @Published var leftoverIssues: [LeftoverScanIssue] = []
    @Published var leftoverRecords: [RemovedApplicationRecord] = []
    @Published var leftoverItemMessages: [String: String] = [:]
    @Published private(set) var configuration: ScanConfiguration
    private let service = InventoryService()
    private let cache: SnapshotStore
    private let identityStore: ApplicationIdentityStore
    private var identityIndex = ApplicationIdentityIndex()
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private(set) var snapshot: InventorySnapshot?
    let runMode: InventoryRunMode
    var demoMode: Bool { runMode == .demo }
    let fixtureMode: Bool
    private var settingsCommitCount = 0
    private var settingsRescanCount = 0
    let qaProtected: Bool
    private let uninstallSession: UninstallSession
    private let removedStore: RemovedApplicationStore
    private let managementSession: ManagementSession
    private var managementPreparation: Task<Void, Never>?
    private var managementExecution: Task<Void, Never>?
    private var managementID = UUID()
    private var leftoverScan: Task<Void, Never>?
    private var leftoverGeneration = UUID()
    private var simulatedRemovedPaths = Set<String>()
    private var refreshAfterManagement = false
    private var uninstallTask: Task<Void, Never>?
    private let launchedAt = Date()
    private var firstWindowSeconds: Double?

    init() {
        runMode = InventoryRunMode(arguments: ProcessInfo.processInfo.arguments, qaBundle: Bundle.main.object(forInfoDictionaryKey: "MacventoryQABundle") as? Bool == true)
        fixtureMode = runMode.isolated
        qaProtected = !runMode.allowsLiveRemoval
        let managementExecutor = ManagementExecutorFactory.make(mode: runMode, failure: ProcessInfo.processInfo.arguments.contains("--qa-management-failure") ? .forceQuit : nil, partialCleanup: ProcessInfo.processInfo.arguments.contains("--qa-partial-cleanup"), missingFirst: ProcessInfo.processInfo.arguments.contains("--qa-missing-cleanup"))
        managementSession = ManagementSession(executor: managementExecutor, simulated: qaProtected)
        let executor: any UninstallExecuting = qaProtected ? SimulatedUninstallExecutor() : LiveUninstallExecutor()
        uninstallSession = UninstallSession(executor: executor, validator: FreshUninstallValidator(standaloneChecker: fixtureMode ? SimulatedStandaloneChecker(roots: [Self.fixtureRoot.path]) : nil))
        removedStore = RemovedApplicationStore(directoryURL: fixtureMode ? FileManager.default.temporaryDirectory.appendingPathComponent("Macventory-Removed-" + UUID().uuidString, isDirectory: true) : nil)
        configuration = fixtureMode ? ScanConfiguration() : (UserDefaults.standard.data(forKey: "configuration").flatMap { try? JSONDecoder().decode(ScanConfiguration.self, from: $0) }) ?? ScanConfiguration()
        cache = SnapshotStore(directory: fixtureMode ? FileManager.default.temporaryDirectory.appendingPathComponent("Macventory-Isolated-" + UUID().uuidString) : nil)
        identityStore = ApplicationIdentityStore(directory: fixtureMode ? Self.fixtureRoot.appendingPathComponent("IdentityStore") : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Macventory"))
        if fixtureMode {
            items = demoMode ? DemoInventory.items() : Self.fixtures(); progress = demoMode ? "Synthetic demonstration · local software is not scanned" : "Fixture inventory"
            if ProcessInfo.processInfo.arguments.contains("--ui-test-error") { error = "Simulated scanner failure — synthetic QA fixture. Existing inventory is retained." }
        }
        else {
            task = Task {
                do { identityIndex = try await identityStore.load() }
                catch { self.error = "Application names could not be loaded: \(error.localizedDescription)" }
                do { snapshot = try await cache.load(); items = snapshot?.items ?? []; reports = snapshot?.reports ?? [] }
                catch { self.error = "Cache could not be loaded: \(error.localizedDescription)" }
                // Migrate already-observed names before a refresh drops absent applications.
                await retainApplicationIdentities(items, inspectBundles: false)
                if configuration.scanOnLaunch { refresh() }
                else if !items.isEmpty { progress = "Cached inventory — refresh to verify" }
            }
        }
        Task { await reloadLeftoverRecords() }
    }
    func refresh() {
        task?.cancel()
        generation = UUID(); let current = generation
        scanning = true; progress = demoMode ? "Refreshing demonstration records…" : "Discovering installed software…"; error = nil
        if fixtureMode {
            task = Task {
                try? await Task.sleep(for: .seconds(8))
                guard generation == current else { return }
                if Task.isCancelled { scanning = false; progress = "Fixture scan canceled"; return }
                items = demoMode ? DemoInventory.items() : Self.fixtures(); scanning = false; progress = demoMode ? "Demo refresh complete · no local software scanned" : "Fixture scan complete"; writeRuntimeReport()
            }
            return
        }
        let config = configuration, previous = snapshot
        reports = InstallSource.allCases.filter { $0 != .unknown }.map { SourceReport($0, .scanning) }
        task = Task {
            let result = await service.scan(configuration: config, previous: previous) { [self] event in
                await self.receive(event, generation: current)
            }
            guard generation == current else { return }
            snapshot = result; items = result.items; reports = result.reports; scanning = false
            await retainApplicationIdentities(result.items, inspectBundles: true)
            progress = Task.isCancelled ? "Scan canceled — partial results retained" : "\(items.count) records · refreshed \(Date().formatted(date: .omitted, time: .shortened))"
            do { try await cache.save(result) } catch { self.error = "Cache save failed: \(error.localizedDescription)" }
            writeRuntimeReport()
        }
    }
    private func receive(_ event: InventoryEvent, generation: UUID) {
        guard self.generation == generation else { return }
        switch event {
        case .items(let items): self.items = items
        case .progress(let text): progress = text
        case .report(let report): reports.removeAll { $0.source == report.source }; reports.append(report)
        }
    }
    private func retainApplicationIdentities(_ observed: [SoftwareItem], inspectBundles: Bool) async {
        let observations = await Task.detached(priority: .utility) {
            ApplicationIdentityIndex.observations(items: observed, inspectBundles: inspectBundles)
        }.value
        identityIndex.observe(observations)
        do { try await identityStore.save(identityIndex) }
        catch { self.error = "Application names could not be saved: \(error.localizedDescription)" }
    }
    func applySettings(_ commit: SettingsCommit) throws {
        guard commit.original == configuration else { throw ScanError.malformed("Settings changed in another window. Cancel and reopen Settings before applying.") }
        guard commit.hasChanges else { return }
        let data = try JSONEncoder().encode(commit.configuration)
        if !fixtureMode { UserDefaults.standard.set(data, forKey: "configuration") }
        configuration = commit.configuration; settingsCommitCount += 1
        if commit.requiresRescan { settingsRescanCount += 1; refresh() }
        if commit.requiresLeftoverRescan {
            leftoverScan?.cancel(); leftoverGeneration = UUID(); leftoverScanState = .notScanned
            if !configuration.discoverPersonalFolders {
                leftoverGroups = leftoverGroups.compactMap { original in var group = original; group.candidates.removeAll { $0.category == "Personal Folder" }; return group.candidates.isEmpty ? nil : group }
            }
            refreshLeftovers()
        }
        writeRuntimeReport()
    }
    func cancel() { task?.cancel(); progress = "Canceling…" }
    func prepareUninstall(_ item: SoftwareItem) {
        guard !scanning, !uninstallWorking, uninstallPlan == nil else { return }
        let running = NSWorkspace.shared.runningApplications.contains { $0.bundleURL.map { FileSystem.canonical($0.path) } == item.path }
        let plan = UninstallPlanner.plan(for: item, running: running)
        uninstallMessage = nil; uninstallOutcome = nil; uninstallPlan = plan
        uninstallPreparing = true
        uninstallTask = Task {
            var failure: String?
            var reviewed = plan
            if item.primarySource == .unmanaged, item.sources.allSatisfy({ $0.source == .unmanaged }), !item.isSystem, !running {
                do {
                    let checker: any StandaloneRemovalChecking = fixtureMode ? SimulatedStandaloneChecker(roots: [Self.fixtureRoot.path]) : StandaloneRemovalChecker(configuration: configuration)
                    let eligibility = try await checker.check(item)
                    try Task.checkCancellation()
                    reviewed = UninstallPlanner.plan(for: item, running: running, standaloneEligibility: eligibility)
                } catch is CancellationError { return }
                catch {
                    failure = "Move to Trash unavailable: " + error.localizedDescription
                }
            }
            guard !Task.isCancelled, uninstallPlan?.id == plan.id else { return }
            uninstallPreparing = false; uninstallMessage = failure
            uninstallPlan = reviewed
            await uninstallSession.prepare(reviewed)
        }
    }
    func cancelUninstall() {
        if uninstallWorking {
            uninstallTask?.cancel(); uninstallMessage = "Cancellation requested. An operation already started may have partially applied; refresh before retrying."
        } else {
            uninstallTask?.cancel(); uninstallPreparing = false
            Task { await uninstallSession.cancel() }; uninstallPlan = nil; uninstallMessage = nil; uninstallOutcome = nil
        }
    }
    func confirmUninstall(_ plan: UninstallPlan, acknowledged: Bool) {
        guard !uninstallWorking, uninstallOutcome == nil, uninstallMessage == nil, acknowledged, uninstallPlan?.id == plan.id else { return }
        uninstallWorking = true
        uninstallTask = Task {
            defer { uninstallWorking = false }
            do {
                let outcome = try await uninstallSession.confirm(id: plan.id, acknowledged: acknowledged)
                uninstallOutcome = outcome
                uninstallMessage = outcome.completionMessage
                if outcome == .completed { try? await removedStore.record(RemovedApplicationRecord(item: plan.item)); await reloadLeftoverRecords(); refresh() }
            } catch { uninstallMessage = "Operation did not complete: \(error.localizedDescription). Refresh before preparing a new confirmation." }
        }
    }
    func prepareManagement(_ item: SoftwareItem) {
        guard !managementWorking, managementItem == nil else { return }
        var item = item
        if fixtureMode { item.scannedAt = Date() }
        let reviewedItem = item
        managementPreparation?.cancel(); managementID = UUID(); let token = managementID
        managementItem = reviewedItem; managementMessage = nil; managementResult = nil; refreshAfterManagement = false
        managementPreparing = true; managementDiscovery = nil
        managementTarget = runningTarget(for: reviewedItem)
        managementUninstallPlan = UninstallPlanner.plan(for: reviewedItem)
        let service = dataDiscoveryService, configuration = configuration, isolated = fixtureMode, root = Self.fixtureRoot.path
        managementPreparation = Task {
            let discovery = await Task.detached(priority: .utility) { service.discover(for: ApplicationIdentity(item: reviewedItem)) }.value
            guard !Task.isCancelled, managementID == token else { return }
            managementDiscovery = discovery
            do {
                guard reviewedItem.primarySource == .unmanaged, reviewedItem.sources.allSatisfy({ $0.source == .unmanaged }) else { managementPreparing = false; return }
                let checker: any StandaloneRemovalChecking = isolated ? SimulatedStandaloneChecker(roots: [root]) : StandaloneRemovalChecker(configuration: configuration)
                let eligibility = try await checker.check(reviewedItem)
                guard !Task.isCancelled, managementID == token else { return }
                managementUninstallPlan = UninstallPlanner.plan(for: reviewedItem, running: false, standaloneEligibility: eligibility)
            } catch { if managementID == token { managementMessage = error.localizedDescription } }
            if managementID == token { managementPreparing = false }
        }
    }
    func closeManagement() {
        guard !managementWorking else { return }
        managementPreparation?.cancel(); managementID = UUID()
        managementItem = nil; managementDiscovery = nil; managementTarget = nil; managementUninstallPlan = nil; managementMessage = nil; managementResult = nil; managementPreparing = false
        if refreshAfterManagement { refreshAfterManagement = false; refresh() }
    }
    func cancelManagement() { managementExecution?.cancel() }
    var dataDiscoveryService: AppDataDiscoveryService {
        fixtureMode ? AppDataDiscoveryService(library: Self.fixtureRoot.appendingPathComponent("Home/Library"), home: Self.fixtureRoot.appendingPathComponent("Home")) : AppDataDiscoveryService()
    }
    func runningTarget(for item: SoftwareItem) -> RunningApplicationTarget? {
        if fixtureMode {
            guard !demoMode, !item.isSystem, item.attributes["QA process"] == "running", let path = item.path, let bundleID = item.bundleID else { return nil }
            return .init(processIdentifier: 999_999, bundleURL: path, bundleID: bundleID, launchedAt: Date(timeIntervalSince1970: 1))
        }
        return ApplicationProcessController.target(for: item)
    }
    func reloadLeftoverRecords() async {
        if fixtureMode {
            leftoverRecords = [RemovedApplicationRecord(name: "Empty Removed App", bundleID: "org.example.empty", ownershipEvidence: "Synthetic history without files"), RemovedApplicationRecord(name: "Retired Studio", bundleID: "org.example.retired", ownershipEvidence: "Synthetic fixture removal record")]
            identityIndex.observe([
                .init(bundleID: "org.example.retired", name: "Retired Studio", source: "Synthetic previously observed bundle"),
                .init(bundleID: "org.example.retired.share", name: "Studio Share", parentBundleID: "org.example.retired", source: "Synthetic embedded extension metadata"),
                .init(bundleID: "net.example.unobserved", name: "Orchard Notes", source: "Synthetic previous inventory bundle metadata")
            ])
        }
        else { do { leftoverRecords = try await removedStore.load() } catch { leftoverMessages = [error.localizedDescription] } }
    }
    func refreshLeftovers() {
        guard leftoverScanState != .scanning else { return }
        leftoverGeneration = UUID(); let token = leftoverGeneration
        leftoverScanState = .scanning
        let service = dataDiscoveryService, records = leftoverRecords, installed = items, isolated = fixtureMode, personal = configuration.discoverPersonalFolders
        let deniedPersonalFixture = isolated && ProcessInfo.processInfo.arguments.contains("--qa-personal-denied")
        leftoverScan = Task {
            if !isolated {
                do { identityIndex = try await identityStore.load() }
                catch { leftoverMessages = ["Application names could not be loaded: " + error.localizedDescription] }
            }
            let index = identityIndex
            let worker = Task.detached(priority: .utility) {
                LeftoverDiscoveryService(discovery: service, listing: QAPersonalLocationListing(denyDesktop: deniedPersonalFixture)).scan(records: records, installed: installed, identityIndex: index, discoverPersonalFolders: personal, registeredApplication: { id in
                    guard !isolated else { return false }
                    let urls = LSCopyApplicationURLsForBundleIdentifier(id as CFString, nil)?.takeRetainedValue() as? [URL] ?? []
                    return urls.contains { FileManager.default.fileExists(atPath: $0.path) }
                })
            }
            let result = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            guard token == leftoverGeneration else { return }
            leftoverScanState = result.state; leftoverMessages = result.messages; leftoverIssues = result.issues
            if result.state == .completed {
                leftoverGroups = result.groups
            } else {
                // Failed sources do not erase previously observed candidates or pretend they are fresh.
                var groups = Dictionary(uniqueKeysWithValues: leftoverGroups.map { ($0.identity.id, $0) })
                for group in result.groups { groups[group.identity.id] = group }
                leftoverGroups = Array(groups.values).sorted { $0.identity.name < $1.identity.name }
            }
            let observed = leftoverGroups
            let reconciled = await Task.detached(priority: .utility) { LeftoverReconciliation.reconcile(observed) }.value
            guard token == leftoverGeneration else { return }
            leftoverGroups = reconciled
            if isolated {
                leftoverGroups = leftoverGroups.compactMap { group in var group = group; group.candidates.removeAll { simulatedRemovedPaths.contains($0.path) }; return group.candidates.isEmpty ? nil : group }
            }
        }
    }
    func cancelLeftoverScan() { leftoverScan?.cancel() }
    /// A partial scan only blocks candidates under the location that could not be
    /// inspected. Every selected item is still freshly revalidated before Trash.
    func leftoverCleanupBlockReason(for candidate: AppDataCandidate) -> String? {
        guard candidate.eligibleForTrash else { return "This location is shared or protected and cannot be moved to Trash." }
        if let message = candidate.validationMessage { return message }
        switch leftoverScanState {
        case .completed: return nil
        case .partial:
            let rootName = URL(fileURLWithPath: candidate.allowedRoot).lastPathComponent
            let affected = candidate.category == "Personal Folder" ? URL(fileURLWithPath: candidate.path).deletingLastPathComponent().lastPathComponent : rootName
            if let issue = leftoverIssues.first(where: { $0.location == affected }) {
                return "\(issue.location) could not be fully scanned. Retry it before cleaning this item."
            }
            return nil
        case .notScanned: return "Scan supported locations before selecting cleanup."
        case .scanning: return "Wait for this scan to finish before selecting cleanup."
        case .failed: return "The scan did not complete. Retry failed locations before selecting cleanup."
        case .cancelled: return "The scan was cancelled. Refresh before selecting cleanup."
        }
    }
    func executeManagement(_ request: ManagementRequest, acknowledged: Bool) {
        guard acknowledged, !managementWorking, !managementPreparing, managementResult == nil else { return }
        managementWorking = true; managementMessage = nil
        managementExecution = Task {
            defer { managementWorking = false }
            let result: ManagementResult
            do { result = try await managementSession.confirm(request, acknowledged: acknowledged) }
            catch { result = ManagementResult(steps: [.init(request.operations.first ?? .clearData, .failed, error.localizedDescription)], simulated: qaProtected) }
            if result.steps.contains(where: { $0.operation == .uninstall && $0.status == .completed }), let item = request.item {
                if !qaProtected {
                    do { try await removedStore.record(RemovedApplicationRecord(item: item)); await reloadLeftoverRecords() }
                    catch { managementMessage = "The operation completed, but removal history could not be saved: \(error.localizedDescription)" }
                    refreshAfterManagement = true
                }
            }
            reconcileCleanupResult(result)
            managementResult = result
        }
    }
    func cleanupLeftovers(_ request: ManagementRequest) async -> ManagementResult {
        do {
            let result = try await managementSession.confirm(request, acknowledged: true)
            reconcileCleanupResult(result)
            return result
        } catch { return .init(steps: [.init(.clearData, .failed, error.localizedDescription)], simulated: qaProtected) }
    }
    private func reconcileCleanupResult(_ result: ManagementResult) {
        let items = result.steps.flatMap(\.cleanupResults)
        let resolved = Set(items.filter { $0.status == .moved || $0.status == .alreadyRemoved }.map(\.id))
        if fixtureMode { simulatedRemovedPaths.formUnion(resolved) }
        leftoverGroups = leftoverGroups.compactMap { original in var group = original; group.candidates.removeAll { resolved.contains($0.id) }; return group.candidates.isEmpty ? nil : group }
        for item in items where item.status != .moved && item.status != .alreadyRemoved { leftoverItemMessages[item.id] = item.status.rawValue + ": " + item.message }
    }
    func noteWindowAppearance() {
        guard firstWindowSeconds == nil else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            if NSApplication.shared.windows.contains(where: \.isVisible) { firstWindowSeconds = Date().timeIntervalSince(launchedAt); writeRuntimeReport() }
        }
    }
    /// Opt-in local verification artifact. Never emitted during ordinary use.
    func writeRuntimeReport() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--runtime-report"), arguments.indices.contains(index + 1) else { return }
        let output = URL(fileURLWithPath: arguments[index + 1])
        let windows = NSApplication.shared.windows.filter { $0.isVisible }
        let document: [String: Any] = [
            "officialIconLoaded": BrandAssets.applicationIcon?.isValid == true,
            "officialIconAssigned": MacventoryAppDelegate.officialIconAssigned,
            "application": "Macventory", "processID": ProcessInfo.processInfo.processIdentifier,
            "visibleWindowCount": windows.count, "windowTitles": windows.map(\.title),
            "windowWidths": windows.map { $0.frame.width }, "windowHeights": windows.map { $0.frame.height },
            "inventoryCount": items.count, "runMode": demoMode ? "demo" : fixtureMode ? "uiTesting" : qaProtected ? "safeQA" : "normal",
            "settingsCommitCount": settingsCommitCount, "settingsRescanCount": settingsRescanCount,
            "configuration": ["appearance": configuration.appearance, "recentlyInstalledDays": configuration.recentlyInstalledDays, "externalVolumes": configuration.externalVolumes], "scanFinished": !scanning,
            "elapsedSeconds": Date().timeIntervalSince(launchedAt),
            "firstVisibleWindowSeconds": firstWindowSeconds as Any? ?? NSNull(),
            "sourceStatuses": Dictionary(uniqueKeysWithValues: reports.map { ($0.source.rawValue, $0.state.rawValue) }),
            "error": error ?? NSNull()
        ]
        do { try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys]).write(to: output, options: .atomic) }
        catch { self.error = "Runtime report could not be written: \(error.localizedDescription)" }
    }
    func clearCache() {
        guard !qaProtected else { progress = "Cache maintenance is disabled in QA and isolated modes"; return }
        Task { do { try await cache.clear(); snapshot = nil; if !scanning { items = []; progress = "Cache cleared" } } catch { self.error = error.localizedDescription } }
    }
    func exportDiagnostics() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Macventory-diagnostics.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try Diagnostics.sanitized(snapshot).write(to: url, options: .atomic) } catch { self.error = error.localizedDescription }
    }
    func refreshMetadata(_ id: String) {
        guard !demoMode else { return }
        guard let index = items.firstIndex(where: { $0.id == id }), let path = items[index].path else { return }
        let original = items[index]
        let currentGeneration = generation
        Task {
            let update = await Task.detached(priority: .utility) { () -> SoftwareItem in
                var updated = original
                if let native = try? NativeScanner.item(at: path) {
                    updated.version = native.version; updated.lastOpenedAt = native.lastOpenedAt
                    updated.fileCreatedAt = native.fileCreatedAt; updated.fileModifiedAt = native.fileModifiedAt
                    updated.evidence["lastOpenedAt"] = native.evidence["lastOpenedAt"]
                }
                do {
                    let size = try SizeMeasurer.measure(path)
                    updated.sizeBytes = size.complete ? size.bytes : nil
                    updated.evidence["sizeBytes"] = Evidence("Filesystem logical size", availability: size.complete ? .available : .partial)
                } catch { updated.evidence["sizeBytes"] = Evidence("Filesystem", availability: .accessDenied, explanation: error.localizedDescription) }
                updated.scannedAt = Date()
                return updated
            }.value
            if !scanning, generation == currentGeneration, let current = items.firstIndex(where: { $0.id == id }) {
                items[current] = update
                if var saved = snapshot {
                    saved.items = items; saved.savedAt = Date(); snapshot = saved
                    do { try await cache.save(saved) } catch { self.error = "Metadata cache save failed: \(error.localizedDescription)" }
                }
            }
        }
    }
    // Keep strict removal-policy fixtures off macOS's /tmp -> /private/tmp alias.
    private static let fixtureRoot = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Macventory-UIFixture-" + UUID().uuidString)
    static func fixtures() -> [SoftwareItem] {
        let directory = fixtureRoot.appendingPathComponent("Example App.app/Contents")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let info: [String: String] = ["CFBundleName": "Example App", "CFBundleIdentifier": "org.example.app", "CFBundleShortVersionString": "1.2.3", "CFBundlePackageType": "APPL", "CFBundleExecutable": "Example", "CFBundleIconFile": "Fixture.icns"]
        let iconURL = directory.appendingPathComponent("Resources/Fixture.icns")
        try? FileManager.default.createDirectory(at: iconURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: iconURL.path), let source = Bundle.main.url(forResource: "Macventory", withExtension: "icns") { try? FileManager.default.copyItem(at: source, to: iconURL) }
        if let data = try? PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0) { try? data.write(to: directory.appendingPathComponent("Info.plist")) }
        var app = SoftwareItem(name: "Example App", path: directory.deletingLastPathComponent().path)
        app.sources = [.init(.unmanaged, Evidence("Synthetic QA fixture; not installed software", confidence: .inferred))]
        let binary = directory.appendingPathComponent("MacOS/Example")
        try? FileManager.default.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data("Synthetic fixture; never executed".utf8).write(to: binary)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: binary.path)
        app.version = "1.2.3"; app.bundleID = "org.example.app"; app.sizeBytes = 2_000_000_000
        app.lastOpenedAt = Date().addingTimeInterval(-200 * 86400)
        app.evidence["lastOpenedAt"] = Evidence("Fixture Spotlight", confidence: .inferred)
        // Synthetic data and process identity are scoped to this fixture root; no production
        // Library or running process is read by the isolated management path.
        let fixtureData = ["Caches/org.example.app/cache.txt", "Preferences/org.example.app.plist", "Application Support/Example App/project.txt", "Caches/org.example.running/cache.txt", "Preferences/org.example.running.plist", "Caches/org.example.retired/cache.txt", "Preferences/org.example.retired.plist", "Caches/org.example.retired.share/cache.txt", "Caches/net.example.unobserved/cache.txt", "Caches/net.example.unknown/cache.txt", "Caches/org.example.retired.similar/cache.txt"]
        for relative in fixtureData {
            let url = fixtureRoot.appendingPathComponent("Home/Library/" + relative)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) { try? Data("Synthetic app data; never moved during QA".utf8).write(to: url) }
        }
        for location in ["Documents", "Downloads", "Desktop"] {
            let folder = fixtureRoot.appendingPathComponent("Home/" + location + "/Orchard Notes")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? Data("Synthetic personal folder; never moved during QA".utf8).write(to: folder.appendingPathComponent("fixture.txt"))
        }
        if ProcessInfo.processInfo.arguments.contains("--qa-cleanup-scenarios") {
            try? FileManager.default.createDirectory(at: fixtureRoot.appendingPathComponent("Home/Library/Group Containers/org.example.retired"), withIntermediateDirectories: true)
        }
        var running = app
        let runningBundle = fixtureRoot.appendingPathComponent("Running Example.app")
        if !FileManager.default.fileExists(atPath: runningBundle.path) { try? FileManager.default.copyItem(at: directory.deletingLastPathComponent(), to: runningBundle) }
        var runningInfo = info; runningInfo["CFBundleName"] = "Running Example"; runningInfo["CFBundleIdentifier"] = "org.example.running"
        if let data = try? PropertyListSerialization.data(fromPropertyList: runningInfo, format: .xml, options: 0) { try? data.write(to: runningBundle.appendingPathComponent("Contents/Info.plist")) }
        running.name = "Running Example"; running.bundleID = "org.example.running"; running.path = FileSystem.canonical(runningBundle.path)
        running.id = SoftwareItem.identity(path: running.path, source: .unmanaged, packageID: "org.example.running"); running.attributes["QA process"] = "running"
        var cli = SoftwareItem(name: "example-tool", kind: .package, source: .homebrewFormula, path: "/opt/homebrew/Cellar/example-tool/1.0", packageID: "example-tool")
        cli.version = "1.0"
        var protected = SoftwareItem(name: "Example System Component", source: .unmanaged, path: "/System/Applications/Example System Component.app")
        protected.isSystem = true; protected.bundleID = "com.apple.example.synthetic"
        return [app, running, cli, protected]
    }
}

private struct QAPersonalLocationListing: AppDataDirectoryListing {
    let denyDesktop: Bool
    func children(_ path: String) throws -> [URL] { try NativeAppDataDirectoryListing().children(path) }
    func boundedChildren(_ path: String, limit: Int) throws -> [URL] {
        if denyDesktop && path.hasSuffix("/Desktop") { throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError) }
        return try NativeAppDataDirectoryListing().boundedChildren(path, limit: limit)
    }
}

enum Display {
    static func date(_ date: Date?, item: SoftwareItem, field: String) -> String { date?.formatted(date: .abbreviated, time: .omitted) ?? item.state(field) }
    static func size(_ item: SoftwareItem) -> String {
        item.sizeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? item.state("sizeBytes")
    }
    static func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
}
