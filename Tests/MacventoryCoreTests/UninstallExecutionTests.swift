import Foundation
import Testing
@testable import MacventoryCore

private struct FixtureManagerSecurity: ManagedRemovalSecurity {
    let executable: String
    let marker: String
    var profile: String? = nil
    var authorization = false
    func executableFingerprint(_ path: String, source: InstallSource) throws -> String {
        guard path == executable else { throw ScanError.process("Wrong manager executable") }
        return try RemovalIdentity.executableDigest(marker)
    }
    func profileFingerprint(_ path: String) throws -> String {
        guard path == profile else { throw ScanError.process("Wrong/declarative profile") }
        return "mutable:" + path + "|" + ((try? FileSystem.text(path)) ?? "generation-1")
    }
    func requiresAuthorization(prefix: String) -> Bool { authorization }
}
actor ManagerRegistry: ManagedRemovalBoundary, CommandRunning {
    enum Fault: String, CaseIterable, Sendable { case none, permission, timeout, cancellation, leaveSelected, changeOther, queryAfter, authorization, changeMetadata }
    var ports: [String: String] = ["tool": "1.0_0+ssl", "other": "2.0_0"]
    var elements: [String: [String]] = ["tool": ["/nix/store/fixture-tool"], "other": ["/nix/store/fixture-other"]]
    var dependents = ""
    var fault: Fault = .none
    var calls: [[String]] = []
    let root: String
    let payload: String
    init(root: String, payload: String) { self.root = root; self.payload = payload }
    func configure(_ fault: Fault = .none, dependents: String = "") { self.fault = fault; self.dependents = dependents }
    func query(_ command: InventoryCommand) throws -> Data {
        if !calls.isEmpty && fault == .queryAfter { throw ScanError.timeout }
        switch command {
        case .ports:
            return Data(ports.sorted { $0.key < $1.key }.map { "\($0.key) @\($0.value) (active)" }.joined(separator: "\n").utf8)
        case .portDependents: return Data(dependents.utf8)
        case .portContents(_, let name), .portExactContents(_, let name, _): return Data((name == "tool" ? payload : root + "/other.txt").utf8)
        case .managerVersion: return Data("nix (Nix) 2.34.9\n".utf8)
        case .nix:
            var values: [String: [String: Any]] = elements.mapValues { ["storePaths": $0] }
            if !calls.isEmpty && fault == .changeMetadata { values["other"]?["priority"] = 99 }
            return try JSONSerialization.data(withJSONObject: ["version": 3, "elements": values])
        default: throw ScanError.malformed("Unexpected fixture query")
        }
    }
    func run(_ command: InventoryCommand) throws -> Data { try query(command) }
    func remove(_ proof: ManagedRemovalEvidence) throws -> Int32 {
        switch fault {
        case .permission: throw ScanError.permission
        case .timeout: throw ScanError.timeout
        case .cancellation: throw CancellationError()
        case .authorization: return LiveManagedRemovalBoundary.authorizationPending
        default: break
        }
        calls.append(proof.arguments)
        switch proof.target {
        case .macPorts(let name, _, _):
            if fault != .leaveSelected { ports.removeValue(forKey: name) }
            if fault == .changeOther { ports.removeValue(forKey: "other") }
            if fault != .leaveSelected, FileSystem.contained(payload, in: root), FileSystem.exists(payload) { try FileManager.default.removeItem(atPath: payload) }
        case .nix(_, let element, _, _):
            if fault != .leaveSelected { elements.removeValue(forKey: element) }
            if fault == .changeOther { elements.removeValue(forKey: "other") }
        }
        return 0
    }
    var count: Int { calls.count }
}
private struct PreparedManagerValidator: UninstallValidating {
    let adapter: ManagedRemovalAdapter
    func validate(_ plan: UninstallPlan) async throws { try await adapter.validate(plan) }
}
private struct PreparedSteamValidator: UninstallValidating {
    let adapter: SteamRemovalAdapter
    func validate(_ plan: UninstallPlan) async throws { try adapter.validate(plan) }
}
private struct PreparedVendorValidator: UninstallValidating {
    let adapter: VendorRemovalAdapter
    func validate(_ plan: UninstallPlan) async throws { _ = try await adapter.validate(plan) }
}
private actor FixtureTrash: BundleTrashOperating {
    let root: String
    var calls = 0
    var leavePresent = false
    init(root: String, leavePresent: Bool = false) { self.root = root; self.leavePresent = leavePresent }
    func recycle(_ plan: UninstallPlan) throws {
        guard let path = plan.item.path, FileSystem.contained(path, in: root), path != root else { throw ScanError.permission }
        calls += 1
        // Only disposable fixtures. Never calls Finder/Trash or a real process.
        if !leavePresent { try FileManager.default.moveItem(atPath: path, toPath: root + "/Recoverable Fixture.app") }
    }
    var count: Int { calls }
}
private actor FixtureInteractiveOpen: InteractiveRemovalOpening {
    var urls: [URL] = []
    func open(application: String, url: URL) { urls.append(url) }
    var count: Int { urls.count }
}
private struct FixtureSteamIdentity: SteamClientChecking {
    let path: String
    func validateRoot(_ root: String) throws { guard root == (path as NSString).deletingLastPathComponent else { throw ScanError.permission } }
    func clientPath() -> String { path }
    func fingerprint(_ path: String) throws -> String {
        guard path == self.path else { throw ScanError.permission }; return "fixture-signature"
    }
}
private struct NoVendor: VendorUninstallerFinding {
    func find(for item: SoftwareItem) -> VendorUninstallerCandidate? { nil }
}
private struct FixtureVendor: VendorUninstallerFinding {
    let candidate: VendorUninstallerCandidate
    func find(for item: SoftwareItem) -> VendorUninstallerCandidate? { candidate }
}
private struct RejectBundle: StandaloneRemovalChecking {
    func check(_ item: SoftwareItem) throws -> StandaloneEligibility { throw ScanError.process("Not an independently owned standalone bundle") }
}
private actor FixtureVendorOpening: VendorToolOpening {
    var calls = 0
    func open(_ candidate: VendorUninstallerCandidate, for item: SoftwareItem) { calls += 1 }
    var count: Int { calls }
}
@Suite("Production uninstall adapters with isolated effect boundaries")
struct UninstallExecutionTests {
    private func managerFixture(_ box: Sandbox, nix: Bool = false) throws -> (ManagerRegistry, ManagedRemovalAdapter, String) {
        let executable = box.root.appendingPathComponent(nix ? "bin/nix" : "bin/port").path
        try box.write(nix ? "bin/nix" : "bin/port", "Inert manager file; never executed")
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable)
        try box.write("profiles/profile", "generation-1")
        try box.write("payload.txt", "Owned synthetic payload")
        try box.write("other.txt", "Other package")
        let registry = ManagerRegistry(root: box.root.path, payload: box.root.appendingPathComponent("payload.txt").path)
        let security = FixtureManagerSecurity(executable: executable, marker: executable, profile: box.root.appendingPathComponent("profiles/profile").path)
        return (registry, ManagedRemovalAdapter(boundary: registry, security: security), executable)
    }
    @Test func macPortsDiscoveryDirectProductionAdapterConfirmationVerificationAndRefresh() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let (registry, adapter, executable) = try managerFixture(box)
        try box.write("Home/Documents/personal.txt", "Preserve documents")
        let scanner = MacPortsScanner(executable: executable, runner: registry)
        let result = try await scanner.scan()
        let item = try #require(result.items.first { $0.packageID == "tool" })
        #expect(item.kind == .package && item.health?.status == .verified)
        let service = UninstallPreparationService(manager: adapter)
        let plan = await service.prepare(item)
        #expect(plan.executionLevel == .direct && plan.method == .macPorts)
        #expect(plan.arguments == ["-N", "uninstall", "tool", "@1.0_0+ssl"])
        #expect(plan.scope == .managerPackage && plan.verificationDescription.contains("manager"))
        let session = UninstallSession(executor: adapter, validator: PreparedManagerValidator(adapter: adapter))
        await session.prepare(plan)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: false) }
        #expect(await registry.count == 0)
        #expect(try await session.confirm(id: plan.id, acknowledged: true) == .verifiedRemoved)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        let after = try await scanner.scan()
        #expect(!after.items.contains { $0.packageID == "tool" })
        #expect(after.items.contains { $0.packageID == "other" })
        #expect(FileSystem.exists(box.root.appendingPathComponent("Home/Documents/personal.txt").path))
    }
    @Test func nixMutableProfileDiscoveryAndExactRemovalRetainsStoreAndOtherElements() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let (registry, adapter, executable) = try managerFixture(box, nix: true)
        let profile = box.root.appendingPathComponent("profiles/profile").path
        let security = FixtureManagerSecurity(executable: executable, marker: executable, profile: profile)
        let scanner = NixScanner(executable: executable, runner: registry, profile: profile, security: security, observedExists: { _ in true })
        let item = try #require(try await scanner.scan().items.first { $0.packageID == "tool" })
        #expect(item.health?.status == .verified && item.kind == .package)
        let plan = await UninstallPreparationService(manager: adapter).prepare(item)
        #expect(plan.executionLevel == .direct && plan.method == .nixProfile)
        #expect(plan.arguments == ["--offline", "profile", "remove", "--profile", profile, "--", "tool"])
        let session = UninstallSession(executor: adapter, validator: PreparedManagerValidator(adapter: adapter))
        await session.prepare(plan)
        #expect(try await session.confirm(id: plan.id, acknowledged: true) == .packageRegistrationRemoved)
        let after = try await scanner.scan()
        #expect(after.items.count == 1 && after.items[0].packageID == "other")
        #expect(FileSystem.exists(box.root.appendingPathComponent("other.txt").path))
    }
    @Test(arguments: [false, true]) func dependencyOrManagerChangePreventsMutation(changed: Bool) async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let (registry, adapter, executable) = try managerFixture(box)
        let item = try #require(try await MacPortsScanner(executable: executable, runner: registry).scan().items.first { $0.packageID == "tool" })
        let plan = await UninstallPreparationService(manager: adapter).prepare(item)
        if changed { try box.write("bin/port", "Replaced manager") }
        else { await registry.configure(dependents: "consumer depends on tool") }
        await #expect(throws: (any Error).self) { try await adapter.execute(plan) }
        #expect(await registry.count == 0)
    }
    @Test(arguments: ManagerRegistry.Fault.allCases) func managerResultsRemainHonest(fault: ManagerRegistry.Fault) async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let (registry, defaultAdapter, executable) = try managerFixture(box)
        let adapter = fault == .authorization ? ManagedRemovalAdapter(boundary: registry, security: FixtureManagerSecurity(executable: executable, marker: executable, authorization: true)) : defaultAdapter
        let item = try #require(try await MacPortsScanner(executable: executable, runner: registry).scan().items.first { $0.packageID == "tool" })
        let plan = await UninstallPreparationService(manager: adapter).prepare(item)
        await registry.configure(fault)
        if [.permission, .timeout, .cancellation].contains(fault) {
            await #expect(throws: (any Error).self) { try await adapter.execute(plan) }
        } else {
            let outcome = try await adapter.execute(plan)
            switch fault {
            case .leaveSelected, .changeOther: #expect(outcome == .partialRemoval)
            case .queryAfter: #expect(outcome == .unknownResult)
            case .authorization: #expect(outcome == .authorizationRequired)
                #expect(await registry.count == 0)
            default: #expect(outcome == .verifiedRemoved)
            }
        }
    }
    @Test func bundleProductionPathWithInjectedTrashVerifiesLimitedRemovalAndRetainsData() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let path = try standalone(box)
        let item = try NativeScanner.item(at: path)
        let checker = SimulatedStandaloneChecker(roots: [box.root.path]), trash = FixtureTrash(root: box.root.path)
        let service = UninstallPreparationService(bundles: checker, vendors: NoVendor())
        let plan = await service.prepare(item)
        #expect(plan.executionLevel == .direct && plan.scope == .bundleOnly)
        let session = UninstallSession(executor: BundleRemovalAdapter(checker: checker, trash: trash), validator: FreshUninstallValidator(standaloneChecker: checker))
        await session.prepare(plan)
        #expect(try await session.confirm(id: plan.id, acknowledged: true) == .appBundleRemoved)
        #expect(await trash.count == 1)
        #expect(!FileSystem.exists(path))
        #expect(FileSystem.exists(box.root.appendingPathComponent("Recoverable Fixture.app").path))
        #expect(try await NativeScanner(roots: [box.root.path]).scan().items.allSatisfy { $0.path != path })
        #expect(FileSystem.exists(box.root.appendingPathComponent("personal.txt").path))
    }
    @Test(arguments: ManagerRegistry.Fault.allCases) func nixFailureAndUnrelatedElementContracts(fault: ManagerRegistry.Fault) async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let (registry, adapter, executable) = try managerFixture(box, nix: true)
        let profile = box.root.appendingPathComponent("profiles/profile").path
        let scanner = NixScanner(executable: executable, runner: registry, profile: profile, security: FixtureManagerSecurity(executable: executable, marker: executable, profile: profile), observedExists: { _ in true })
        let item = try #require(try await scanner.scan().items.first { $0.packageID == "tool" })
        let plan = await UninstallPreparationService(manager: adapter).prepare(item)
        await registry.configure(fault)
        if [.permission, .timeout, .cancellation].contains(fault) { await #expect(throws: (any Error).self) { try await adapter.execute(plan) } }
        else {
            let outcome = try await adapter.execute(plan)
            switch fault {
            case .leaveSelected, .changeOther, .changeMetadata: #expect(outcome == .partialRemoval)
            case .queryAfter: #expect(outcome == .unknownResult)
            case .authorization: #expect(outcome == .unknownResult)
            default: #expect(outcome == .packageRegistrationRemoved)
            }
        }
    }
    @Test func nixGenerationSubstitutionRequiresNewPreview() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let (registry, adapter, executable) = try managerFixture(box, nix: true)
        let profile = box.root.appendingPathComponent("profiles/profile").path
        let scanner = NixScanner(executable: executable, runner: registry, profile: profile, security: FixtureManagerSecurity(executable: executable, marker: executable, profile: profile))
        let item = try #require(try await scanner.scan().items.first { $0.packageID == "tool" })
        let plan = await UninstallPreparationService(manager: adapter).prepare(item)
        try box.write("profiles/profile", "replacement generation")
        await #expect(throws: (any Error).self) { try await adapter.execute(plan) }
        #expect(await registry.count == 0)
        #expect(throws: (any Error).self) { try LiveManagedRemovalSecurity().profileFingerprint("/nix/var/nix/profiles/system") }
    }
    @Test func replacementBundleSymlinkCannotReachNativeEffectBoundary() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let path = try standalone(box), item = try NativeScanner.item(at: path)
        let checker = SimulatedStandaloneChecker(roots: [box.root.path]), trash = FixtureTrash(root: box.root.path)
        let plan = await UninstallPreparationService(bundles: checker, vendors: NoVendor()).prepare(item)
        try FileManager.default.moveItem(atPath: path, toPath: box.root.appendingPathComponent("Other.app").path)
        try FileManager.default.createSymbolicLink(atPath: path, withDestinationPath: box.root.appendingPathComponent("Other.app").path)
        await #expect(throws: (any Error).self) { try await BundleRemovalAdapter(checker: checker, trash: trash).execute(plan) }
        #expect(await trash.count == 0)
    }
    @Test func authorizationHandlerRevalidatesExactRequestThroughProductionAdapter() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let (registry, _, marker) = try managerFixture(box)
        let executable = "/opt/local/bin/port"
        let adapter = ManagedRemovalAdapter(boundary: registry, security: FixtureManagerSecurity(executable: executable, marker: marker))
        var item = SoftwareItem(name: "tool", kind: .package, source: .macPorts, packageID: "tool")
        item.version = "1.0_0+ssl"; item.attributes["Prefix"] = "/opt/local"; item.attributes["Manager executable"] = executable
        let proof = try await adapter.prepare(item), request = try MacPortsAuthorizedRequest(proof)
        #expect(try await MacPortsAuthorizedOperation(adapter: adapter, authorizer: FixtureAdminAuthorization(allowed: true)).execute(request, clientBundle: box.root.appendingPathComponent("Separate.app").path) == .verifiedRemoved)
        #expect(await registry.count == 1)
        #expect(!MacPortsAuthorization.isPackagedAndSigned) // Test host never qualifies for live authorization.
    }
    private func standalone(_ box: Sandbox) throws -> String {
        let path = try box.app()
        let url = URL(fileURLWithPath: path + "/Contents/Info.plist")
        var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as! [String: Any]
        info["CFBundleExecutable"] = "Example"
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: url)
        try box.write("Example.app/Contents/MacOS/Example", "Inert synthetic executable")
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path + "/Contents/MacOS/Example")
        try box.write("personal.txt", "Retain user data")
        return path
    }
    @Test func vendorInteractivePrecedesLimitedDeletionAndNeverClaimsRemovalOnLaunch() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try NativeScanner.item(at: standalone(box))
        let candidate = VendorUninstallerCandidate(path: box.root.appendingPathComponent("Trusted Uninstaller.app").path, team: "FIXTURE", fingerprint: "publisher and target proof")
        let plan = await UninstallPreparationService(bundles: RejectBundle(), vendors: FixtureVendor(candidate: candidate)).prepare(item)
        #expect(plan.executionLevel == .interactive && plan.method == .vendorTool && plan.scope == .vendorDefined)
        let opener = FixtureVendorOpening()
        let adapter = VendorRemovalAdapter(finder: FixtureVendor(candidate: candidate), opener: opener)
        let session = UninstallSession(executor: adapter, validator: PreparedVendorValidator(adapter: adapter))
        await session.prepare(plan)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: false) }
        #expect(await opener.count == 0)
        #expect(try await session.confirm(id: plan.id, acknowledged: true) == .waitingForUser)
        #expect(await opener.count == 1)
        #expect(InteractiveRemovalVerification.verify(plan) == .waitingForUser)
        #expect(!UninstallOutcome.waitingForUser.completionMessage.contains("verified removed"))
        try FileManager.default.moveItem(atPath: item.path!, toPath: box.root.appendingPathComponent("Recoverable Vendor Fixture.app").path)
        #expect(InteractiveRemovalVerification.verify(plan) == .appBundleRemoved)
        #expect(try await NativeScanner(roots: [box.root.path]).scan().items.allSatisfy { $0.path != item.path })
        #expect(FileSystem.exists(box.root.appendingPathComponent("personal.txt").path))
    }
    @Test func simulatedInteractiveWorkflowPreservesWaitingState() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let path = try box.app("Apps/Example.app", id: "example.vendor")
        let item = try NativeScanner.item(at: path)
        let candidate = VendorUninstallerCandidate(path: box.root.appendingPathComponent("Uninstaller.app").path, team: "FIXTURE", fingerprint: "fixture")
        let plan = UninstallPlanner.plan(for: item, vendor: candidate)
        let request = ManagementRequest(item: item, identity: ApplicationIdentity(item: item), uninstallPlan: plan, operations: [.uninstall])
        let result = try await ManagementSession(executor: SimulatedManagementExecutor(), simulated: true).confirm(request, acknowledged: true)
        #expect(result.title == "Waiting for User")
        #expect(result.steps.first?.status == .waitingForUser)
        #expect(result.steps.first?.status.title == "Waiting for User")
        #expect(FileSystem.exists(path))
    }
    @Test func pkgLimitedBundleScopeIsSeparateFromReceiptCleanup() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let path = try standalone(box)
        let info = try PropertyListSerialization.data(fromPropertyList: ["volume": box.root.path, "install-location": "", "pkg-version": "2.0"], format: .xml, options: 0)
        let runner = StubRunner(outputs: ["--pkgs": Data("org.example.pkg".utf8), "--pkg-info-plist org.example.pkg": info, "--files org.example.pkg": Data("Example.app/Contents/Info.plist".utf8)])
        let scanner = PKGScanner(runner: runner)
        let item = try #require(try await scanner.scan().items.first)
        #expect(item.path == path && item.primarySource == .pkg && item.installationHealth.status == .verified)
        let checker = SimulatedStandaloneChecker(roots: [box.root.path])
        let plan = await UninstallPreparationService(bundles: checker, vendors: NoVendor()).prepare(item)
        #expect(plan.executionLevel == .direct && plan.scope == .bundleOnly)
        #expect(plan.arguments.isEmpty && !plan.operation.contains("forget"))
        let session = UninstallSession(executor: BundleRemovalAdapter(checker: checker, trash: FixtureTrash(root: box.root.path)), validator: FreshUninstallValidator(standaloneChecker: checker))
        await session.prepare(plan)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: false) }
        #expect(try await session.confirm(id: plan.id, acknowledged: true) == .appBundleRemoved)
        let after = try #require(try await scanner.scan().items.first)
        #expect(after.kind == .package && after.path == nil && after.installationHealth.status == .historical)
        #expect(FileSystem.exists(box.root.appendingPathComponent("personal.txt").path))
    }
    @Test func steamTargetedProductionHandoffAndIndependentVerification() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("steamapps/libraryfolders.vdf", "\"libraryfolders\" { \"0\" { \"path\" \"\(box.root.path)\" \"apps\" { \"123\" \"10\" } } }")
        try box.write("steamapps/appmanifest_123.acf", "\"AppState\" { \"appid\" \"123\" \"name\" \"Fixture Game\" \"installdir\" \"Game\" }")
        try box.write("steamapps/common/Game/payload.txt", "Fixture payload")
        let item = try #require(try await SteamScanner(root: box.root.path).scan().items.first)
        let opener = FixtureInteractiveOpen()
        let adapter = SteamRemovalAdapter(client: FixtureSteamIdentity(path: box.root.appendingPathComponent("Steam.app").path), opener: opener)
        let plan = await UninstallPreparationService(steam: adapter).prepare(item)
        #expect(plan.executionLevel == .interactive && plan.method == .steamInteractive)
        #expect(plan.interactiveEvidence?.url.absoluteString == "steam://uninstall/123")
        let session = UninstallSession(executor: adapter, validator: PreparedSteamValidator(adapter: adapter))
        await session.prepare(plan)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: false) }
        #expect(await opener.count == 0)
        #expect(try await session.confirm(id: plan.id, acknowledged: true) == .waitingForUser)
        #expect(await opener.count == 1)
        #expect(SteamRemovalAdapter.verify(plan) == .waitingForUser)
        try FileManager.default.removeItem(atPath: box.root.appendingPathComponent("steamapps/common/Game").path)
        #expect(SteamRemovalAdapter.verify(plan) == .partialRemoval)
        try FileManager.default.removeItem(atPath: box.root.appendingPathComponent("steamapps/appmanifest_123.acf").path)
        #expect(SteamRemovalAdapter.verify(plan) == .partialRemoval) // Index still reports the App ID.
        try box.write("steamapps/libraryfolders.vdf", "\"libraryfolders\" { \"0\" { \"path\" \"\(box.root.path)\" \"apps\" {} } }")
        #expect(SteamRemovalAdapter.verify(plan) == .verifiedRemoved)
        #expect(try await SteamScanner(root: box.root.path).scan().items.isEmpty)
        let second = box.root.appendingPathComponent("MovedLibrary").path
        try box.write("steamapps/libraryfolders.vdf", "\"libraryfolders\" { \"1\" { \"path\" \"\(second)\" } }")
        #expect(SteamRemovalAdapter.verify(plan) == .unknownResult) // An offline library is not absence.
        try box.write("MovedLibrary/steamapps/appmanifest_123.acf", "Retained manifest in another library")
        #expect(SteamRemovalAdapter.verify(plan) == .partialRemoval)
    }
    @Test(arguments: InstallSource.allCases) func everySourceSelectsExplicitLevelOrSafetyOverride(source: InstallSource) async {
        let item = SoftwareItem(name: "Unverified fixture", kind: .package, source: source)
        let plan = await UninstallPreparationService(bundles: RejectBundle(), vendors: NoVendor()).prepare(item)
        #expect(plan.isBlocked ? plan.executionLevel == nil : UninstallExecutionLevel.allCases.contains(plan.executionLevel!))
        #expect(!plan.canExecute)
        #expect(!plan.explanation.isEmpty)
    }
    @Test func invalidPortSelectorsAndUnsupportedProfilesNeverBecomeCommands() {
        for name in ["all", "active", "installed", "depof:foo", "--force", "../x", "a;bad", "a b"] { #expect(!RemovalIdentity.portName(name)) }
        for version in ["--force", "1 *", "1/other", "1;bad"] { #expect(!RemovalIdentity.portVersion(version)) }
        for element in ["--all", "0", ".*", "/nix/store/x", "foo[bar]"] { #expect(!RemovalIdentity.nixElement(element)) }
        for version in ["nix (Nix) 2.20.1", "nix (Nix) 3.0.0", "nix (Nix) 2.99.0", "forged 2.34"] { #expect(!ManagedRemovalAdapter.supportsNix(version)) }
    }
    @Test func formulaServiceReviewBlocksRunningAndUnknownServices() throws {
        try HomebrewServiceReview.validate(Data("[{\"name\":\"tool\",\"status\":\"none\"}]".utf8), token: "tool")
        for status in ["started", "error", "unknown"] {
            #expect(throws: (any Error).self) { try HomebrewServiceReview.validate(Data("[{\"name\":\"tool\",\"status\":\"\(status)\"}]".utf8), token: "tool") }
        }
    }
}

private actor TrapBundleExecutor: UninstallExecuting {
    var calls = 0
    func execute(_ plan: UninstallPlan) throws -> UninstallOutcome { calls += 1; throw ScanError.process("Filesystem fallback must never run") }
    var count: Int { calls }
}
extension UninstallExecutionTests {
    @Test func failedManagerDispatchNeverFallsBackToBundleDeletion() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let (registry, adapter, executable) = try managerFixture(box)
        let item = try #require(try await MacPortsScanner(executable: executable, runner: registry).scan().items.first { $0.packageID == "tool" })
        let plan = await UninstallPreparationService(manager: adapter).prepare(item)
        let trap = TrapBundleExecutor(), validator = PreparedManagerValidator(adapter: adapter)
        let dispatcher = UninstallExecutionService(validator: validator, managed: adapter, bundles: trap)
        let session = UninstallSession(executor: dispatcher, validator: validator)
        await session.prepare(plan); await registry.configure(.permission)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
        #expect(await trap.count == 0)
        #expect(FileSystem.exists(box.root.appendingPathComponent("payload.txt").path))
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: true) }
    }
}
extension UninstallExecutionTests {
    @Test func installedManagerPermissionPolicyPreservesNixStoreSafety() {
        #expect(LiveManagedRemovalSecurity.permitsOwnership(path: "/nix/store", source: .nix, owner: 0, mode: 0o1775, group: "nixbld"))
        #expect(!LiveManagedRemovalSecurity.permitsOwnership(path: "/nix/store/package/bin/nix", source: .nix, owner: 0, mode: 0o1775, group: "nixbld"))
        #expect(!LiveManagedRemovalSecurity.permitsOwnership(path: "/nix/store", source: .nix, owner: 0, mode: 0o1777, group: "nixbld"))
        #expect(!LiveManagedRemovalSecurity.permitsOwnership(path: "/opt/local/bin/port", source: .macPorts, owner: 0, mode: 0o775, group: "staff"))
    }
}
private struct FixtureStoreSigning: VendorIdentityChecking {
    let allowed: String
    func teamIdentifier(at path: String) -> String? { path == allowed ? "FIXTURE_STORE_TEAM" : nil }
}
extension UninstallExecutionTests {
    @Test func appStoreEligibleNativePathPreservesAccountAndReceiptScope() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let path = try standalone(box)
        try box.write("Example.app/Contents/_MASReceipt/receipt", "Synthetic receipt; no purchase authentication claimed")
        let item = try NativeScanner.item(at: path)
        #expect(item.primarySource == .appStore && item.confidence == .inferred)
        let checker = SimulatedStandaloneChecker(roots: [box.root.path], signatures: FixtureStoreSigning(allowed: path))
        let plan = await UninstallPreparationService(bundles: checker).prepare(item)
        #expect(plan.executionLevel == .direct && plan.scope == .bundleOnly)
        let trash = FixtureTrash(root: box.root.path)
        let session = UninstallSession(executor: BundleRemovalAdapter(checker: checker, trash: trash), validator: FreshUninstallValidator(standaloneChecker: checker))
        await session.prepare(plan)
        await #expect(throws: (any Error).self) { try await session.confirm(id: plan.id, acknowledged: false) }
        #expect(try await session.confirm(id: plan.id, acknowledged: true) == .appBundleRemoved)
        #expect(try await NativeScanner(roots: [box.root.path]).scan().items.allSatisfy { $0.path != path })
        #expect(FileSystem.exists(box.root.appendingPathComponent("personal.txt").path))
    }
}
extension UninstallExecutionTests {
    @Test func steamDuplicateLibrariesCannotBeTargetedByAppIDOnly() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let second = box.root.appendingPathComponent("Second").path
        try box.write("steamapps/libraryfolders.vdf", "\"libraryfolders\" { \"0\" { \"path\" \"\(box.root.path)\" } \"1\" { \"path\" \"\(second)\" } }")
        let manifest = "\"AppState\" { \"appid\" \"123\" \"name\" \"Fixture\" \"installdir\" \"Game\" }"
        try box.write("steamapps/appmanifest_123.acf", manifest)
        try box.write("Second/steamapps/appmanifest_123.acf", manifest)
        let item = try #require(try await SteamScanner(root: box.root.path).scan().items.first)
        let opener = FixtureInteractiveOpen(), adapter = SteamRemovalAdapter(client: FixtureSteamIdentity(path: box.root.appendingPathComponent("Steam.app").path), opener: opener)
        let plan = await UninstallPreparationService(steam: adapter).prepare(item)
        #expect(plan.executionLevel == .guided && !plan.canExecute)
        #expect(plan.explanation.contains("multiple physical manifests"))
        #expect(await opener.count == 0)
    }
    @Test func finderCallbackAloneDoesNotProveBundleRemoval() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let item = try NativeScanner.item(at: standalone(box))
        let checker = SimulatedStandaloneChecker(roots: [box.root.path]), effect = FixtureTrash(root: box.root.path, leavePresent: true)
        let plan = await UninstallPreparationService(bundles: checker, vendors: NoVendor()).prepare(item)
        #expect(try await BundleRemovalAdapter(checker: checker, trash: effect).execute(plan) == .partialRemoval)
        #expect(FileSystem.exists(item.path!))
    }
}

private struct FixtureAdminAuthorization: MacPortsRequestAuthorizing {
    let allowed: Bool
    func validate(_ form: Data) throws { if !allowed { throw ScanError.permission } }
}
extension UninstallExecutionTests {
    @Test func helperDeniesMissingOrUnapprovedAuthorizationBeforeEffect() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let (registry, _, marker) = try managerFixture(box)
        let adapter = ManagedRemovalAdapter(boundary: registry, security: FixtureManagerSecurity(executable: "/opt/local/bin/port", marker: marker))
        var item = SoftwareItem(name: "tool", kind: .package, source: .macPorts, packageID: "tool")
        item.version = "1.0_0+ssl"; item.attributes["Prefix"] = "/opt/local"; item.attributes["Manager executable"] = "/opt/local/bin/port"
        let request = try MacPortsAuthorizedRequest(await adapter.prepare(item))
        await #expect(throws: (any Error).self) { try await MacPortsAuthorizedOperation(adapter: adapter, authorizer: FixtureAdminAuthorization(allowed: false)).execute(request, clientBundle: box.root.appendingPathComponent("Separate.app").path) }
        await #expect(throws: (any Error).self) { try await MacPortsAuthorizedOperation(adapter: adapter).execute(request, clientBundle: box.root.appendingPathComponent("Separate.app").path) }
        #expect(await registry.count == 0)
        #expect(throws: (any Error).self) { try MacPortsSystemAuthorizer().validate(Data(repeating: 0, count: 3)) }
        #expect(throws: (any Error).self) { try MacPortsAuthorization.peerRequirement(identifier: "other", team: "TEAM") }
        #expect(throws: (any Error).self) { try MacPortsAuthorization.peerRequirement(identifier: MacPortsAuthorization.serviceName, team: "TEAM\"") }
    }
    @Test(arguments: [false, true]) func macPortsPayloadIdentityChangesRequireNewPreview(wasMissing: Bool) async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let (registry, adapter, executable) = try managerFixture(box)
        let payload = box.root.appendingPathComponent("payload.txt").path
        if wasMissing { try FileManager.default.removeItem(atPath: payload) }
        let item = try #require(try await MacPortsScanner(executable: executable, runner: registry).scan().items.first { $0.packageID == "tool" })
        let plan = await UninstallPreparationService(manager: adapter).prepare(item)
        #expect(plan.canExecute)
        if !wasMissing { try FileManager.default.moveItem(atPath: payload, toPath: box.root.appendingPathComponent("Original.txt").path) }
        try box.write("payload.txt", "Replacement must never be removed by old confirmation")
        await #expect(throws: (any Error).self) { try await adapter.execute(plan) }
        #expect(await registry.count == 0)
        #expect(FileSystem.exists(payload))
    }
}

/// Simulates a right that expires while read-only manager preflight is suspended.
/// No Authorization Services prompt, XPC connection or privileged service is used.
private final class ExpiringFixtureAdminAuthorization: MacPortsRequestAuthorizing, @unchecked Sendable {
    private let lock = NSLock()
    private var attempts = 0
    var count: Int { lock.withLock { attempts } }
    func validate(_ form: Data) throws {
        let attempt = lock.withLock { attempts += 1; return attempts }
        if attempt > 1 { throw ScanError.process("Fixture administrator right expired after preflight") }
    }
}
extension UninstallExecutionTests {
    @Test func authorizationExpiringAfterPreflightCannotReachPrivilegedEffect() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let (registry, _, marker) = try managerFixture(box)
        let adapter = ManagedRemovalAdapter(boundary: registry, security: FixtureManagerSecurity(executable: "/opt/local/bin/port", marker: marker))
        var item = SoftwareItem(name: "tool", kind: .package, source: .macPorts, packageID: "tool")
        item.version = "1.0_0+ssl"; item.attributes["Prefix"] = "/opt/local"; item.attributes["Manager executable"] = "/opt/local/bin/port"
        let request = try MacPortsAuthorizedRequest(await adapter.prepare(item))
        let authorizer = ExpiringFixtureAdminAuthorization()
        await #expect(throws: (any Error).self) {
            try await MacPortsAuthorizedOperation(adapter: adapter, authorizer: authorizer).execute(request, clientBundle: box.root.appendingPathComponent("Separate.app").path)
        }
        #expect(authorizer.count == 2)
        #expect(await registry.count == 0)
        #expect(FileSystem.exists(box.root.appendingPathComponent("payload.txt").path))
    }
}
