import SwiftUI
import AppKit
import MacventoryCore

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
    @Published private(set) var configuration: ScanConfiguration
    private let service = InventoryService()
    private let cache: SnapshotStore
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
    private var uninstallTask: Task<Void, Never>?
    private let launchedAt = Date()
    private var firstWindowSeconds: Double?

    init() {
        runMode = InventoryRunMode(arguments: ProcessInfo.processInfo.arguments)
        fixtureMode = runMode.isolated
        qaProtected = !runMode.allowsLiveRemoval
        let executor: any UninstallExecuting = qaProtected ? SimulatedUninstallExecutor() : LiveUninstallExecutor()
        uninstallSession = UninstallSession(executor: executor, validator: FreshUninstallValidator(standaloneChecker: fixtureMode ? SimulatedStandaloneChecker(roots: [Self.fixtureRoot.path]) : nil))
        configuration = fixtureMode ? ScanConfiguration() : (UserDefaults.standard.data(forKey: "configuration").flatMap { try? JSONDecoder().decode(ScanConfiguration.self, from: $0) }) ?? ScanConfiguration()
        cache = SnapshotStore(directory: fixtureMode ? FileManager.default.temporaryDirectory.appendingPathComponent("Macventory-Isolated-" + UUID().uuidString) : nil)
        if fixtureMode {
            items = demoMode ? DemoInventory.items() : Self.fixtures(); progress = demoMode ? "Synthetic demonstration · local software is not scanned" : "Fixture inventory"
            if ProcessInfo.processInfo.arguments.contains("--ui-test-error") { error = "Simulated scanner failure — synthetic QA fixture. Existing inventory is retained." }
        }
        else {
            task = Task {
                do { snapshot = try await cache.load(); items = snapshot?.items ?? []; reports = snapshot?.reports ?? [] }
                catch { self.error = "Cache could not be loaded: \(error.localizedDescription)" }
                if configuration.scanOnLaunch { refresh() }
                else if !items.isEmpty { progress = "Cached inventory — refresh to verify" }
            }
        }
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
    func applySettings(_ commit: SettingsCommit) throws {
        guard commit.original == configuration else { throw ScanError.malformed("Settings changed in another window. Cancel and reopen Settings before applying.") }
        guard commit.hasChanges else { return }
        let data = try JSONEncoder().encode(commit.configuration)
        if !fixtureMode { UserDefaults.standard.set(data, forKey: "configuration") }
        configuration = commit.configuration; settingsCommitCount += 1
        if commit.requiresRescan { settingsRescanCount += 1; refresh() }
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
                if outcome == .completed { refresh() }
            } catch { uninstallMessage = "Operation did not complete: \(error.localizedDescription). Refresh before preparing a new confirmation." }
        }
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
        guard !fixtureMode else { progress = "Cache maintenance is disabled in isolated mode"; return }
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
    private static let fixtureRoot = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Macventory-UIFixture-" + UUID().uuidString)
    static func fixtures() -> [SoftwareItem] {
        let directory = fixtureRoot.appendingPathComponent("Example App.app/Contents")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let info: [String: String] = ["CFBundleName": "Example App", "CFBundleIdentifier": "org.example.app", "CFBundleShortVersionString": "1.2.3", "CFBundlePackageType": "APPL", "CFBundleExecutable": "Example"]
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
        var cli = SoftwareItem(name: "example-tool", kind: .package, source: .homebrewFormula, path: "/opt/homebrew/Cellar/example-tool/1.0", packageID: "example-tool")
        cli.version = "1.0"
        var protected = SoftwareItem(name: "Example System Component", source: .unmanaged, path: "/System/Applications/Example System Component.app")
        protected.isSystem = true; protected.bundleID = "com.apple.example.synthetic"
        return [app, cli, protected]
    }
}

enum Display {
    static func date(_ date: Date?, item: SoftwareItem, field: String) -> String { date?.formatted(date: .abbreviated, time: .omitted) ?? item.state(field) }
    static func size(_ item: SoftwareItem) -> String {
        item.sizeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? item.state("sizeBytes")
    }
    static func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
}
