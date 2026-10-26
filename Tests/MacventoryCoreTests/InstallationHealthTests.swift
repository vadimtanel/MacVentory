import Foundation
import Testing
@testable import MacventoryCore

private actor FixtureBrew: HomebrewRemovalOperating, CommandRunning {
    var registry: [String: [String]]
    var calls: [[String]] = []
    var exit: Int32 = 0
    var keepRegistration = false
    var queryFailureAfterRemoval = false
    var dependent = ""
    var cleanup: [String] = []
    var changeUnrelated = false
    let root: String
    init(root: String, token: String = "macventory", version: String = "1.0.0") { self.root = root; registry = [token: [version]] }
    func configure(exit: Int32 = 0, keep: Bool = false, queryFailure: Bool = false, dependent: String = "", cleanup: [String] = [], changeOther: Bool = false) {
        self.exit = exit; keepRegistration = keep; queryFailureAfterRemoval = queryFailure; self.dependent = dependent; self.cleanup = cleanup
        changeUnrelated = changeOther
        if changeOther { registry["unrelated"] = ["2.0"] }
    }
    func installed(executable: String, cask: Bool) throws -> [String: [String]] {
        if queryFailureAfterRemoval && !calls.isEmpty { throw ScanError.timeout }
        return registry
    }
    func dependents(executable: String, token: String) -> String { dependent }
    func remove(executable: String, arguments: [String]) throws -> Int32 {
        calls.append(arguments)
        if !keepRegistration { registry.removeValue(forKey: arguments.last!) }
        if changeUnrelated { registry.removeValue(forKey: "unrelated") }
        for path in cleanup {
            guard FileSystem.contained(path, in: root), path != root else { throw ScanError.permission }
            if FileSystem.exists(path) { try FileManager.default.removeItem(atPath: path) }
        }
        return exit
    }
    func run(_ command: InventoryCommand) throws -> Data {
        switch command {
        case .brewInstalled: return Data(registry.sorted { $0.key < $1.key }.map { ([$0.key] + $0.value).joined(separator: " ") }.joined(separator: "\n").utf8)
        default: throw ScanError.malformed("Unexpected synthetic query")
        }
    }
    func markAbsent() { registry = [:] }
    func setVersions(_ versions: [String]) { registry["macventory"] = versions }
    var count: Int { calls.count }
}
private struct FixtureManagerValidation: UninstallValidating {
    func validate(_ plan: UninstallPlan) throws {
        let fresh = UninstallPlanner.plan(for: plan.item)
        guard fresh.canExecute, fresh.method == plan.method, fresh.arguments == plan.arguments, fresh.fingerprint == plan.fingerprint else { throw ScanError.process("Synthetic preflight evidence changed") }
    }
}
@Suite("Unified installation health and source removal contracts")
struct InstallationHealthTests {
    private func cask(_ box: Sandbox, app: Bool = false, token: String = "macventory", appdir: String? = nil) throws -> String {
        let directory = appdir ?? box.root.appendingPathComponent("Applications").path
        let receipt: [String: Any] = ["source": ["version": "1.0.0"], "uninstall_artifacts": [["app": ["Macventory.app"]]]]
        try box.write("Caskroom/\(token)/.metadata/INSTALL_RECEIPT.json", String(decoding: try JSONSerialization.data(withJSONObject: receipt), as: UTF8.self))
        try box.write("Caskroom/\(token)/.metadata/config.json", String(decoding: try JSONSerialization.data(withJSONObject: ["explicit": ["appdir": directory]]), as: UTF8.self))
        try box.write("bin/brew", "Synthetic inert manager file; never executed")
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: box.root.appendingPathComponent("bin/brew").path)
        if app {
            let path = try box.app("Applications/Macventory.app", id: "org.vadimtanel.Macventory", name: "Macventory")
            let infoURL = URL(fileURLWithPath: path + "/Contents/Info.plist")
            var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil) as! [String: Any]
            info["CFBundleExecutable"] = "Macventory"
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)
            try box.write("Applications/Macventory.app/Contents/MacOS/Macventory", "Inert synthetic executable")
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path + "/Contents/MacOS/Macventory")
        }
        return directory + "/Macventory.app"
    }
    @Test func missingHomebrewMacventoryScansPlansConfirmsVerifiesAndReconciles() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let expected = try cask(box), manager = FixtureBrew(root: box.root.path)
        let scanner = HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager)
        let before = try await scanner.scan()
        let item = try #require(before.items.first)
        #expect(item.name == "macventory" && item.version == "1.0.0")
        #expect(item.packageID == "macventory" && item.kind == .package && item.path == nil)
        #expect(item.installationHealth.status == .attention)
        #expect(item.installationHealth.registration == .installed)
        #expect(item.installationHealth.artifacts == [.init(expected, .missing)])
        #expect(!ProtectionPolicy.isRunningCopy([expected], runningBundle: box.root.appendingPathComponent("Build/Macventory.app").path))
        let plan = UninstallPlanner.plan(for: item)
        #expect(plan.method == .homebrewCask && plan.actionTitle == "Remove Orphaned Installation")
        #expect(plan.arguments == ["uninstall", "--cask", "--", "macventory"])
        let adapter = HomebrewRemovalAdapter(operation: manager)
        let session = UninstallSession(executor: adapter, validator: FixtureManagerValidation())
        await session.prepare(plan)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: false) }
        #expect(await manager.count == 0)
        #expect(try await session.confirm(id: plan.id, acknowledged: true) == .verifiedRemoved)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        let after = try await scanner.scan()
        #expect(after.items.first?.installationHealth.status == .historical)
        #expect(after.items.first?.health?.registration == .absent)
        #expect(await manager.count == 1)
        #expect(FileSystem.exists(box.root.appendingPathComponent("Caskroom/macventory/.metadata/INSTALL_RECEIPT.json").path))
    }
    @Test(arguments: [false, true]) func healthyAndMissingCustomCaskArtifact(app: Bool) async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let expected = try cask(box, app: app)
        let manager = FixtureBrew(root: box.root.path)
        let item = try #require(try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager).scan().items.first)
        #expect(item.health?.status == (app ? .verified : .attention))
        #expect(item.health?.artifacts.first?.path == expected)
        #expect(UninstallPlanner.plan(for: item).canExecute)
    }
    @Test func targetRenameAndCustomAppDirectoryAreExact() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let directory = box.root.appendingPathComponent("Custom Apps").path
        _ = try cask(box, appdir: directory)
        try box.write("Caskroom/macventory/.metadata/INSTALL_RECEIPT.json", "{\"source\":{\"version\":\"1.0.0\"},\"uninstall_artifacts\":[{\"app\":[\"Archive/Product.app\",{\"target\":\"Renamed.app\"}]}]}")
        let item = try #require(try HomebrewScanner.cask(box.root.appendingPathComponent("Caskroom/macventory").path).first)
        #expect(item.health?.artifacts.first?.path == directory + "/Renamed.app")
        #expect(item.path == nil)
    }
    @Test(arguments: [Int32(0), Int32(1)]) func exitCodeDoesNotEstablishRemoval(exit: Int32) async throws {
        let box = try Sandbox.removal(); defer { box.clean() }; _ = try cask(box)
        let manager = FixtureBrew(root: box.root.path); await manager.configure(exit: exit, keep: true)
        let item = try #require(try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager).scan().items.first)
        let outcome = try await HomebrewRemovalAdapter(operation: manager).execute(UninstallPlanner.plan(for: item))
        #expect(outcome == (exit == 0 ? .partialRemoval : .failed))
    }
    @Test(arguments: ["font", "binary", "absoluteBinary", "appBinary", "multipleApps"]) func declarativeCaskArtifactsHaveExactDirectRemoval(kind: String) async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        _ = try cask(box)
        var artifacts: [[String: Any]]
        var targets: [String]
        if kind == "multipleApps" {
            _ = try cask(box, app: true)
            _ = try box.app("Applications/Companion.app", id: "example.companion")
            artifacts = [["app": ["Macventory.app"]], ["app": ["Companion.app"]]]
            targets = ["Applications/Macventory.app", "Applications/Companion.app"]
        } else if kind == "appBinary" {
            _ = try cask(box, app: true)
            let source = box.root.appendingPathComponent("Applications/Macventory.app/Contents/MacOS/Macventory").path
            try FileManager.default.createSymbolicLink(atPath: box.root.appendingPathComponent("bin/tool").path, withDestinationPath: source)
            artifacts = [["app": ["Macventory.app"]], ["binary": [source, ["target": "tool"]]]]
            targets = ["bin/tool", "Applications/Macventory.app"]
        } else if kind == "font" {
            try box.write("Fonts/Example.ttf", "Disposable font fixture")
            artifacts = [["font": ["Example.ttf"]]]; targets = ["Fonts/Example.ttf"]
        } else {
            try box.write("Caskroom/macventory/1.0.0/tool", "Inert tool fixture")
            try FileManager.default.createSymbolicLink(atPath: box.root.appendingPathComponent("bin/tool").path, withDestinationPath: "../Caskroom/macventory/1.0.0/tool")
            artifacts = [["binary": [kind == "absoluteBinary" ? box.root.appendingPathComponent("Caskroom/macventory/1.0.0/tool").path : "tool"]]]; targets = ["bin/tool"]
        }
        let metadata = "Caskroom/macventory/.metadata/"
        try box.write(metadata + "INSTALL_RECEIPT.json", String(decoding: try JSONSerialization.data(withJSONObject: ["source": ["version": "1.0.0"], "uninstall_artifacts": artifacts]), as: UTF8.self))
        let config = ["explicit": ["appdir": box.root.appendingPathComponent("Applications").path, "fontdir": box.root.appendingPathComponent("Fonts").path]]
        try box.write(metadata + "config.json", String(decoding: try JSONSerialization.data(withJSONObject: config), as: UTF8.self))
        try box.write("Unrelated/keep.txt", "Unrelated installation")
        let manager = FixtureBrew(root: box.root.path)
        await manager.configure(cleanup: targets.map { box.root.appendingPathComponent($0).path } + [box.root.appendingPathComponent("Caskroom/macventory").path])
        let scanner = HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager)
        let item = try #require(try await scanner.scan().items.first)
        #expect(item.installationHealth.status == .verified)
        let plan = UninstallPlanner.plan(for: item)
        #expect(plan.executionLevel == .direct && plan.method == .homebrewCask)
        #expect(plan.actionTitle == "Uninstall with Homebrew")
        #expect(plan.item.health?.artifacts.count == targets.count)
        let session = UninstallSession(executor: HomebrewRemovalAdapter(operation: manager), validator: FixtureManagerValidation())
        await session.prepare(plan)
        #expect(try await session.confirm(id: plan.id, acknowledged: true) == .verifiedRemoved)
        #expect(try await scanner.scan().items.isEmpty)
        #expect(FileSystem.exists(box.root.appendingPathComponent("Unrelated/keep.txt").path))
    }
    @Test func replacedCaskBinaryAndUnsafeTargetCannotAuthorizeRemoval() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("bin/tool", "Unrelated replaced file")
        let mapping = CaskMappedArtifact(kind: "binary", path: box.root.appendingPathComponent("bin/tool").path, caskRoot: box.root.appendingPathComponent("Caskroom/example").path)
        #expect(throws: (any Error).self) { try mapping.validateForRemoval() }
        for target in [".", "..", "../other", "/System", "nested/file"] {
            #expect(throws: (any Error).self) { try CaskMappedArtifact.read(receipt: ["uninstall_artifacts": [["font": ["Example.ttf", ["target": target]]]]], config: [:], root: box.root.appendingPathComponent("Caskroom/example").path) }
        }
        #expect(!ProtectionPolicy.protectedPath("/usr/local/bin/example"))
        #expect(ProtectionPolicy.protectedPath("/usr/bin/example"))
        #expect(ProtectionPolicy.protectedPath("/usr/locality/example"))
    }
    @Test func multipleCaskVersionsCannotBroadenTheReviewedOperation() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }; _ = try cask(box)
        let manager = FixtureBrew(root: box.root.path)
        await manager.setVersions(["1.0.0", "2.0.0"])
        let item = try #require(try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager).scan().items.first)
        await #expect(throws: (any Error).self) { try await HomebrewRemovalAdapter(operation: manager).execute(UninstallPlanner.plan(for: item)) }
        #expect(await manager.count == 0)
    }
    @Test func unrelatedHomebrewRegistryChangeCannotBeReportedAsCleanSuccess() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }; _ = try cask(box)
        let manager = FixtureBrew(root: box.root.path); await manager.configure(changeOther: true)
        let item = try #require(try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager).scan().items.first { $0.packageID == "macventory" })
        #expect(try await HomebrewRemovalAdapter(operation: manager).execute(UninstallPlanner.plan(for: item)) == .partialRemoval)
        #expect(await manager.count == 1)
    }
    @Test func postflightQueryFailureIsUnknown() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }; _ = try cask(box)
        let manager = FixtureBrew(root: box.root.path); await manager.configure(queryFailure: true)
        let item = try #require(try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager).scan().items.first)
        #expect(try await HomebrewRemovalAdapter(operation: manager).execute(UninstallPlanner.plan(for: item)) == .unknownResult)
    }
    @Test func healthyCaskSyntheticRemovalPreservesUnrelatedCopyAndUserData() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let expected = try cask(box, app: true)
        let unrelated = try box.app("Other/Macventory.app", id: "org.vadimtanel.Macventory")
        try box.write("Home/Documents/work.txt", "Keep personal work")
        let manager = FixtureBrew(root: box.root.path); await manager.configure(cleanup: [expected, box.root.appendingPathComponent("Caskroom/macventory").path])
        let scanner = HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager)
        let item = try #require(try await scanner.scan().items.first)
        #expect(try await HomebrewRemovalAdapter(operation: manager).execute(UninstallPlanner.plan(for: item)) == .verifiedRemoved)
        #expect(try await scanner.scan().items.isEmpty)
        #expect(FileSystem.exists(unrelated))
        #expect(FileSystem.exists(box.root.appendingPathComponent("Home/Documents/work.txt").path))
    }
    @Test func disappearingRegistrationWithRemainingAppCannotClaimAlreadyRemoved() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }; let path = try cask(box, app: true)
        let manager = FixtureBrew(root: box.root.path)
        let item = try #require(try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager).scan().items.first)
        let plan = UninstallPlanner.plan(for: item)
        await manager.markAbsent()
        #expect(try await HomebrewRemovalAdapter(operation: manager).execute(plan) == .partialRemoval)
        #expect(await manager.count == 0)
        #expect(FileSystem.exists(path))
    }
    @Test func replacedManagerOrMappingCannotUseOldPlan() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }; _ = try cask(box)
        let manager = FixtureBrew(root: box.root.path)
        let item = try #require(try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager).scan().items.first)
        let plan = UninstallPlanner.plan(for: item)
        try box.write("bin/brew", "Changed synthetic executable")
        await #expect(throws: (any Error).self) { try await HomebrewRemovalAdapter(operation: manager).execute(plan) }
        #expect(await manager.count == 0)
    }
    @Test func fakeExecutableCannotReachProductionPreflight() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }; _ = try cask(box)
        let manager = FixtureBrew(root: box.root.path)
        let item = try #require(try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager).scan().items.first)
        await #expect(throws: (any Error).self) { try await FreshUninstallValidator().validate(UninstallPlanner.plan(for: item)) }
        #expect(await manager.count == 0)
    }
    @Test func managerQueryFailureNeverBecomesVerifiedMissing() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }; _ = try cask(box)
        let result = try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: StubRunner(failure: true)).scan()
        #expect(result.report.state == .failed)
        #expect(result.items.first?.health?.status == .unverified)
        #expect(UninstallPlanner.plan(for: result.items[0]).method == .external)
    }
    @Test func historicalReceiptIsNotInstalledAndCannotUninstall() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }; _ = try cask(box)
        let result = try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: StubRunner(outputs: ["list --cask --versions": Data()])).scan()
        #expect(result.items.first?.health?.status == .historical)
        #expect(!UninstallPlanner.plan(for: result.items[0]).canExecute)
    }
    @Test func formulaChecksDependentsAndVersionBeforeMutation() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("Cellar/tool/1.0.0/INSTALL_RECEIPT.json", "{}")
        try box.write("bin/brew", "Inert synthetic manager")
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: box.root.appendingPathComponent("bin/brew").path)
        let manager = FixtureBrew(root: box.root.path, token: "tool")
        let item = try #require(try await HomebrewScanner(source: .homebrewFormula, prefixes: [box.root.path], runner: manager).scan().items.first)
        #expect(item.kind == .package && item.health?.status == .verified)
        let plan = UninstallPlanner.plan(for: item)
        #expect(plan.method == .homebrewFormula)
        await manager.configure(dependent: "dependent-package")
        await #expect(throws: (any Error).self) { try await HomebrewRemovalAdapter(operation: manager).execute(plan) }
        #expect(await manager.count == 0)
        await manager.configure()
        #expect(try await HomebrewRemovalAdapter(operation: manager).execute(plan) == .partialRemoval) // keg intentionally remains
    }
    @Test(arguments: InstallSource.allCases) func allSourcesHaveExplicitRemovalStrategy(source: InstallSource) {
        let item = SoftwareItem(name: "Synthetic", kind: .package, source: source, packageID: "example")
        let guide = SourceRemovalGuide.forItem(item)
        #expect(!guide.instructions.isEmpty)
        if source != .unknown { #expect(guide.documentation?.scheme == "https") }
        #expect(!UninstallPlanner.plan(for: item).canExecute)
    }
    @Test(arguments: [InstallSource.homebrewFormula, .macPorts, .nix]) func packageOnlyStateIsHealthy(source: InstallSource) {
        let item = SoftwareItem(name: "CLI", kind: .package, source: source, packageID: "cli")
        #expect(InstallationHealthClassifier.classify(item, registration: .installed).status == .verified)
    }
    @Test func protectionUsesLocationAndExactRunningCopy() {
        var system = SoftwareItem(name: "System", path: "/System/Applications/Example.app")
        #expect(system.installationHealth.status == .protected)
        #expect(!UninstallPlanner.plan(for: system).canExecute)
        system.path = "/Applications/Example.app"; system.bundleID = "com.apple.example"
        system.health = .init(.verified, "Synthetic user-removable Apple app")
        #expect(system.installationHealth.status != .protected)
        #expect(ProtectionPolicy.isRunningCopy(["/Build/Macventory.app"], runningBundle: "/Build/Macventory.app"))
        #expect(!ProtectionPolicy.isRunningCopy(["/Applications/Macventory.app"], runningBundle: "/Build/Macventory.app"))
    }
    @Test(arguments: ArtifactPresence.allFixtures) func inaccessibleAndBrokenObservationsAreDistinct(presence: ArtifactPresence) {
        let item = SoftwareItem(name: "Synthetic", kind: .package, source: .homebrewCask, packageID: "example")
        let health = InstallationHealthClassifier.classify(item, registration: .installed, artifacts: [.init("/synthetic/Example.app", presence)])
        #expect(health.status == (presence == .inaccessible ? .unverified : presence == .present ? .verified : .attention))
    }
    @Test func brokenLinkProbeAndFailedScanCacheAreConservative() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let link = box.root.appendingPathComponent("Broken.app").path
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: box.root.appendingPathComponent("Gone.app").path)
        #expect(ArtifactObservation.inspect(link).presence == .brokenLink)
        var old = SoftwareItem(name: "Deleted", path: box.root.appendingPathComponent("Deleted.app").path)
        old.health = .init(.verified, "Old observation")
        let previous = InventorySnapshot(items: [old], reports: [], observations: [InstallSource.unmanaged.rawValue: [old]])
        let failed = await InventoryService().scan(configuration: ScanConfiguration(), previous: previous, measureSizes: false, scanners: [StubScanner(source: .unmanaged, result: ScanResult(.unmanaged), fail: true)]) { _ in }
        #expect(failed.items.first?.stale == true)
        #expect(failed.items.first?.installationHealth.status == .unverified)
        let fresh = await InventoryService().scan(configuration: ScanConfiguration(), previous: failed, measureSizes: false, scanners: [StubScanner(source: .unmanaged, result: ScanResult(.unmanaged))]) { _ in }
        #expect(fresh.items.isEmpty)
    }
    @Test func nuiPhysicalCopiesAndHistoricalBuildPathStaySeparate() throws {
        let box = try Sandbox(); defer { box.clean() }
        var direct = try NativeScanner.item(at: box.app("Applications/nui-app.app", id: "org.example.nui", name: "nui-app"))
        var pkg = try NativeScanner.item(at: box.app("Users/runner/work/nui/nui/build/bin/nui-app.app", id: "org.example.nui", name: "nui-app"))
        direct.primarySource = .unmanaged; pkg.primarySource = .pkg; pkg.sources = [.init(.pkg, Evidence("Synthetic receipt payload"))]
        #expect(InventoryMerger.merge([direct, pkg]).count == 2)
        try FileManager.default.removeItem(atPath: direct.path!)
        var historical = SoftwareItem(name: "nui receipt", kind: .package, source: .pkg, packageID: "org.example.nui")
        historical.health = .init(.historical, "Build-time path is absent", registration: .receiptOnly)
        let result = InventoryMerger.merge([pkg, historical])
        #expect(result.count == 2)
        #expect(result.filter { $0.kind == .app }.count == 1)
        #expect(result.contains { $0.installationHealth.status == .historical })
    }
    @Test func healthFilteringSortingAttentionAndSnapshotMigration() throws {
        var attention = SoftwareItem(name: "Missing", kind: .package, source: .homebrewCask)
        attention.health = .init(.attention, "Verified mismatch", registration: .installed)
        var healthy = SoftwareItem(name: "Healthy", kind: .package, source: .macPorts)
        healthy.health = .init(.verified, "CLI-only package", registration: .installed)
        var filter = InventoryFilter(); filter.view = .attention
        #expect(filter.matches(attention, configuration: ScanConfiguration()))
        #expect(!filter.matches(healthy, configuration: ScanConfiguration()))
        filter.view = .all; filter.healthStatus = .verified
        #expect(filter.matches(healthy, configuration: ScanConfiguration()))
        #expect(!filter.matches(attention, configuration: ScanConfiguration()))
        #expect(InventorySort.sorted([healthy, attention], by: .health).first?.name == "Missing")
        let data = try JSONEncoder().encode(attention)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]; json.removeValue(forKey: "health")
        #expect(try JSONDecoder().decode(SoftwareItem.self, from: JSONSerialization.data(withJSONObject: json)).health == nil)
    }
    @Test(arguments: ["../Escape.app", "/System/Applications/App.app"]) func unsafeCaskMappingsRejected(target: String) throws {
        let box = try Sandbox(); defer { box.clean() }; _ = try cask(box)
        let object: [String: Any] = ["uninstall_artifacts": [["app": [target]]]]
        try box.write("Caskroom/macventory/.metadata/INSTALL_RECEIPT.json", String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self))
        #expect(throws: (any Error).self) { try HomebrewScanner.cask(box.root.appendingPathComponent("Caskroom/macventory").path) }
    }
    @Test(arguments: ["quit", "script", "launchctl"]) func caskHookReviewAllowsOnlyExactDeclarativeQuit(hook: String) async throws {
        let box = try Sandbox.removal(); defer { box.clean() }; _ = try cask(box, app: true)
        let object: [String: Any] = ["source": ["version": "1.0.0"], "uninstall_flight_blocks": false, "uninstall_artifacts": [["app": ["Macventory.app"]], ["uninstall": [[hook: "org.vadimtanel.Macventory"]]]]]
        try box.write("Caskroom/macventory/.metadata/INSTALL_RECEIPT.json", String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self))
        let manager = FixtureBrew(root: box.root.path)
        let item = try #require(try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager).scan().items.first)
        #expect(UninstallPlanner.plan(for: item).method == (hook == "quit" ? .homebrewCask : .external))
        let wrong: [String: Any] = ["uninstall_artifacts": [["app": ["Macventory.app"]], ["uninstall": [["quit": "org.other.app"]]]]]
        #expect(!CaskEffectReview.allowsAutomation(wrong, item: item))
    }
    @Test func stagedCaskroomCopyDoesNotSubstituteForMissingDeclaredApplication() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }; let expected = try cask(box)
        _ = try box.app("Caskroom/macventory/1.0.0/Macventory.app")
        let manager = FixtureBrew(root: box.root.path)
        let result = try await HomebrewScanner(source: .homebrewCask, prefixes: [box.root.path], runner: manager).scan()
        #expect(result.items.count == 1)
        #expect(result.items[0].path == nil && result.items[0].kind == .package)
        #expect(result.items[0].health?.artifacts.first?.path == expected)
        #expect(result.items[0].health?.status == .attention)
    }
    @Test func permissionDeniedAncestorIsNotVerifiedMissing() throws {
        let box = try Sandbox.removal()
        let denied = box.root.appendingPathComponent("Denied").path
        try box.write("Denied/App.app/Contents/Info.plist", "Synthetic")
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: denied); box.clean() }
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: denied)
        #expect(ArtifactObservation.inspect(denied + "/App.app").presence == .inaccessible)
    }
    @Test func numericHomebrewTokensAndSeparateManagerVersionAreSupported() {
        #expect(UninstallPlanner.validToken("1password"))
        #expect(UninstallPlanner.validToken("7zip"))
        var item = SoftwareItem(name: "Synthetic", source: .homebrewCask, packageID: "example")
        item.version = "2.0-self-updated"; item.attributes["Manager version"] = "1.0"
        #expect(HomebrewRemovalAdapter.expectedVersion(for: item) == "1.0")
    }
    @Test func verificationMatrixSeparatesRegistrationPayloadExitAndAccess() {
        #expect(RemovalVerification.managerOutcome(installed: true, artifacts: [], exitCode: 0) == .partialRemoval)
        #expect(RemovalVerification.managerOutcome(installed: false, artifacts: [], exitCode: 0) == .packageRegistrationRemoved)
        #expect(RemovalVerification.managerOutcome(installed: false, artifacts: [.init("/synthetic", .missing)], exitCode: 0) == .verifiedRemoved)
        #expect(RemovalVerification.managerOutcome(installed: false, artifacts: [.init("/synthetic", .present)], exitCode: 0) == .partialRemoval)
        #expect(RemovalVerification.managerOutcome(installed: false, artifacts: [.init("/synthetic", .inaccessible)], exitCode: 0) == .unknownResult)
        #expect(RemovalVerification.managerOutcome(installed: false, artifacts: [], exitCode: 1) == .partialRemoval)
    }
}
private extension ArtifactPresence { static let allFixtures: [Self] = [.present, .missing, .brokenLink, .inaccessible] }

private struct FixtureSigning: VendorIdentityChecking {
    let teams: [String: String]
    func teamIdentifier(at path: String) -> String? { teams[path] }
}
@Suite("Vendor trust and provider health boundaries")
struct VendorAndProviderHealthTests {
    @Test(arguments: [true, false]) func vendorAssociationRequiresVerifiedMatchingTeam(matching: Bool) throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let appPath = try box.app("Vendor/App.app")
        let appMetadata = URL(fileURLWithPath: appPath + "/Contents/Info.plist")
        var appInfo = try PropertyListSerialization.propertyList(from: Data(contentsOf: appMetadata), format: nil) as! [String: Any]
        appInfo["CFBundleExecutable"] = "App"
        try PropertyListSerialization.data(fromPropertyList: appInfo, format: .xml, options: 0).write(to: appMetadata)
        try box.write("Vendor/App.app/Contents/MacOS/App", "Inert target")
        let toolPath = try box.app("Vendor/App.app/Contents/Helpers/Uninstaller.app", id: "org.example.uninstaller")
        let metadata = URL(fileURLWithPath: toolPath + "/Contents/Info.plist")
        var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: metadata), format: nil) as! [String: Any]
        info["CFBundleExecutable"] = "Uninstaller"
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: metadata)
        try box.write("Vendor/App.app/Contents/Helpers/Uninstaller.app/Contents/MacOS/Uninstaller", "Inert fixture")
        var item = try NativeScanner.item(at: appPath); item.primarySource = .pkg
        let signing = FixtureSigning(teams: [FileSystem.canonical(appPath): "TEAM_A", FileSystem.canonical(toolPath): matching ? "TEAM_A" : "TEAM_B"])
        let candidate = VendorUninstallerDiscovery.discover(for: item, checker: signing)
        #expect((candidate != nil) == matching)
        if let candidate {
            let plan = UninstallPlanner.plan(for: item, vendor: candidate)
            #expect(plan.method == .vendorTool && plan.executable == toolPath)
            #expect(plan.operation.contains("interactive"))
            #expect(!plan.explanation.isEmpty)
        }
        #expect(VendorUninstallerDiscovery.discover(for: item) == nil) // unsigned inert fixture never trusted live
    }
    @Test func toolNameAloneNeverEstablishesPublisherTrust() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let appPath = try box.app("Vendor/App.app")
        _ = try box.app("Vendor/Uninstall App.app")
        let item = try NativeScanner.item(at: appPath)
        #expect(VendorUninstallerDiscovery.discover(for: item, checker: FixtureSigning(teams: [:])) == nil)
    }
    @Test func managerSymlinksCannotRedirectOperationsToAnotherPrefix() {
        #expect(HomebrewTrust.permitsResolution(executable: "/usr/local/bin/brew", resolved: "/usr/local/Homebrew/bin/brew"))
        #expect(!HomebrewTrust.permitsResolution(executable: "/usr/local/bin/brew", resolved: "/opt/homebrew/bin/brew"))
        #expect(!HomebrewTrust.permitsResolution(executable: "/opt/homebrew/bin/brew", resolved: "/usr/local/Homebrew/bin/brew"))
        #expect(!HomebrewTrust.permitsResolution(executable: "/tmp/bin/brew", resolved: "/opt/homebrew/bin/brew"))
    }
    @Test func documentationRejectsUntrustedSchemesHostsCredentialsAndRedirects() throws {
        let original = try #require(URL(string: "https://docs.brew.sh/Manpage"))
        for target in ["http://docs.brew.sh/Manpage", "https://docs.brew.sh.evil.example/", "https://other.example/", "https://user:secret@docs.brew.sh/", "file:///tmp/recipe", "https://docs.brew.sh:8443/"] {
            #expect(!OfficialRemovalDocumentation.permits(try #require(URL(string: target)), original: original))
        }
        #expect(OfficialRemovalDocumentation.permits(try #require(URL(string: "https://docs.brew.sh/Common-Issues")), original: original))
    }
    @Test func missingSteamPayloadRetainsManifestIdentityAndGuidance() async throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("steamapps/appmanifest_123.acf", "\"AppState\" { \"appid\" \"123\" \"name\" \"Synthetic Game\" \"installdir\" \"Missing Game\" }")
        let result = try await SteamScanner(root: box.root.path).scan()
        #expect(result.items.count == 1)
        #expect(result.items[0].packageID == "123")
        #expect(result.items[0].health?.status == .attention)
        #expect(UninstallPlanner.plan(for: result.items[0]).method == .external)
    }
    @Test func conflictingHomebrewPrefixesCannotMergeIntoRemovalPermission() {
        var first = SoftwareItem(name: "A", source: .homebrewCask, path: "/Applications/Synthetic.app", packageID: "example")
        first.attributes["Homebrew executable"] = "/opt/homebrew/bin/brew"
        var second = first; second.attributes["Homebrew executable"] = "/usr/local/bin/brew"
        let merged = InventoryMerger.merge([first, second])
        #expect(merged.count == 1)
        #expect(merged[0].primarySource == .unknown)
        #expect(merged[0].installationHealth.status == .unverified)
        #expect(!UninstallPlanner.plan(for: merged[0]).canExecute)
    }
    @Test func macPortsMissingAppIsNotDroppedAndCLIOnlyIsNotBroken() async throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("bin/port", "Inert synthetic tool; never executed")
        let executable = box.root.appendingPathComponent("bin/port").path
        let missing = box.root.appendingPathComponent("Applications/Missing.app/Contents/Info.plist").path
        let runner = StubRunner(outputs: ["-q installed": Data("gui @1.0 (active)\ncli @2.0 (active)".utf8), "-q contents gui": Data(missing.utf8), "-q contents cli": Data("No app artifacts".utf8)])
        let result = try await MacPortsScanner(executable: executable, runner: runner).scan()
        #expect(result.items.first { $0.packageID == "gui" }?.health?.status == .attention)
        #expect(result.items.first { $0.packageID == "cli" }?.health?.status == .verified)
    }
    @Test func freshObservationReplacesStaleSameIdentityAfterPartialScan() async {
        var old = SoftwareItem(name: "Old", source: .nix, packageID: "example"); old.stale = true
        var fresh = old; fresh.stale = false; fresh.name = "Fresh"
        fresh.health = .init(.verified, "Current manager evidence", registration: .installed)
        let previous = InventorySnapshot(items: [old], reports: [], observations: [InstallSource.nix.rawValue: [old]])
        let scanner = StubScanner(source: .nix, result: ScanResult(.nix, items: [fresh], state: .failed))
        let result = await InventoryService().scan(configuration: ScanConfiguration(), previous: previous, measureSizes: false, scanners: [scanner]) { _ in }
        #expect(result.items.count == 1 && result.items[0].name == "Fresh")
        #expect(!result.items[0].stale)
    }
}

struct InterruptedBrew: HomebrewRemovalOperating {
    enum Failure: String, CaseIterable, Sendable { case permission, timeout, authentication, cancellation }
    let failure: Failure
    func installed(executable: String, cask: Bool) -> [String: [String]] { ["macventory": ["1.0.0"]] }
    func dependents(executable: String, token: String) -> String { "" }
    func remove(executable: String, arguments: [String]) throws -> Int32 {
        switch failure {
        case .permission: throw ScanError.permission
        case .timeout: throw ScanError.timeout
        case .authentication: throw ScanError.process("Authentication required in official manager")
        case .cancellation: throw CancellationError()
        }
    }
}
@Suite("Interrupted manager operation contracts")
struct InterruptedManagerTests {
    @Test(arguments: InterruptedBrew.Failure.allCases) func interruptionsNeverClaimRemoval(failure: InterruptedBrew.Failure) async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("bin/brew", "Inert fixture")
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: box.root.appendingPathComponent("bin/brew").path)
        let receipt = "Caskroom/macventory/.metadata"
        try box.write(receipt + "/INSTALL_RECEIPT.json", "{\"source\":{\"version\":\"1.0.0\"},\"uninstall_artifacts\":[{\"app\":[\"Macventory.app\"]}]}")
        try box.write(receipt + "/config.json", String(decoding: try JSONSerialization.data(withJSONObject: ["explicit": ["appdir": box.root.appendingPathComponent("Applications").path]]), as: UTF8.self))
        var item = try #require(try HomebrewScanner.cask(box.root.appendingPathComponent("Caskroom/macventory").path).first)
        item.health = InstallationHealthClassifier.classify(item, registration: .installed, artifacts: item.health?.artifacts)
        let plan = UninstallPlanner.plan(for: item)
        #expect(plan.canExecute)
        let session = UninstallSession(executor: HomebrewRemovalAdapter(operation: InterruptedBrew(failure: failure)), validator: FixtureManagerValidation())
        await session.prepare(plan)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        #expect(FileSystem.exists(box.root.appendingPathComponent(receipt + "/INSTALL_RECEIPT.json").path))
    }
    @Test func vendorHandoffHasTerminalWaitingState() {
        let result = ManagementResult(steps: [.init(.uninstall, .waitingForUser, UninstallOutcome.waitingForUser.completionMessage)], simulated: false)
        #expect(result.title == "Waiting for User")
        #expect(!result.explanation.contains("application was removed"))
        #expect(UninstallOutcome.waitingForUser.completionMessage.contains("does not prove removal"))
    }
}
