import Foundation
import Darwin
import Testing
@testable import MacventoryCore

struct Sandbox {
    let root: URL
    init(directory: URL = FileManager.default.temporaryDirectory) throws {
        root = directory.appendingPathComponent("MacventoryTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    // Avoid macOS's /var -> /private/var ancestor link in strict removal-policy fixtures.
    static func removal() throws -> Sandbox {
        try Sandbox(directory: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("build/RemovalFixtures"))
    }
    func write(_ relative: String, _ text: String) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }
    func app(_ relative: String = "Example.app", id: String = "org.example.app", name: String = "Example") throws -> String {
        let info: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": name, "CFBundleShortVersionString": "2.0", "CFBundlePackageType": "APPL"]
        let url = root.appendingPathComponent(relative).appendingPathComponent("Contents/Info.plist")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: url)
        return root.appendingPathComponent(relative).path
    }
    func clean() { try? FileManager.default.removeItem(at: root) }
}

/// A compiled, test-owned process: no shell, installed manager or receipt dependency.
private struct NativeProcessFixture: Sendable {
    let executable: URL
    var started: URL { URL(fileURLWithPath: executable.path + ".started") }
    var command: InventoryCommand { .managerVersion(executable: executable.path) }
    private static func tool(_ path: String, _ arguments: [String], environment: [String: String]) throws -> String {
        let process = Process(), output = Pipe()
        defer {
            try? output.fileHandleForReading.close()
            try? output.fileHandleForWriting.close()
        }
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = output
        let context = "Native fixture tool \(path) \(arguments); DEVELOPER_DIR=\(environment["DEVELOPER_DIR"] ?? "<xcode-select>"); SDKROOT=\(environment["SDKROOT"] ?? "<resolve macosx>"); TOOLCHAINS=<unset> (lookup: default)"
        do { try process.run() }
        catch { throw ScanError.process("\(context): launch failed: \(error)") }
        try output.fileHandleForWriting.close()
        // Drain while running so compiler diagnostics cannot fill a pipe and deadlock.
        let diagnostics = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ScanError.process("\(context): exit \(process.terminationStatus)\n\(diagnostics)")
        }
        return diagnostics.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func compilerEnvironment(_ inherited: [String: String]) throws -> [String: String] {
        // Hosted XCTest omits DEVELOPER_DIR but supplies its Xcode framework paths.
        // Use those only to identify that Xcode; never inject its test libraries into tools.
        let hostDeveloper = inherited["DYLD_FRAMEWORK_PATH"]?.split(separator: ":").compactMap { path -> String? in
            let suffix = "/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
            guard path.hasSuffix(suffix) else { return nil }
            return String(path.dropLast(suffix.count)) + "/Contents/Developer"
        }.first
        // An allowlist also excludes stale SDKROOT/TOOLCHAINS, DYLD_* and __XPC_DYLD_*.
        var environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "C", "LC_ALL": "C"]
        let selected = try inherited["DEVELOPER_DIR"] ?? hostDeveloper ?? tool("/usr/bin/xcode-select", ["-p"], environment: environment)
        var developer = URL(fileURLWithPath: selected)
        if developer.pathExtension == "app" { developer.appendPathComponent("Contents/Developer") }
        developer = developer.resolvingSymlinksInPath().standardizedFileURL
        environment["DEVELOPER_DIR"] = developer.path
        let sdk = try tool("/usr/bin/xcrun", ["--sdk", "macosx", "--show-sdk-path"], environment: environment)
        let compiler = try tool("/usr/bin/xcrun", ["--sdk", "macosx", "--toolchain", "default", "--find", "clang"], environment: environment)
        let sdkURL = URL(fileURLWithPath: sdk).resolvingSymlinksInPath()
        let compilerURL = URL(fileURLWithPath: compiler).resolvingSymlinksInPath()
        guard sdkURL.path.hasPrefix(developer.path + "/"), compilerURL.path.hasPrefix(developer.path + "/"),
              FileManager.default.fileExists(atPath: sdkURL.appendingPathComponent("usr/include/stdio.h").path),
              FileManager.default.isExecutableFile(atPath: compilerURL.path) else {
            throw ScanError.process("Native fixture resolved inconsistent tools: developer=\(developer.path), compiler=\(compiler), SDK=\(sdk)")
        }
        environment["SDKROOT"] = sdkURL.path
        environment["CC"] = compilerURL.path
        return environment
    }
    init(_ box: Sandbox, slow: Bool = false, compilerEnvironment inherited: [String: String] = ProcessInfo.processInfo.environment) throws {
        let directory = box.root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        executable = directory.appendingPathComponent("nix")
        let source = directory.appendingPathComponent("fixture.c")
        try #"""
        #include <stdio.h>
        #include <unistd.h>
        #include <limits.h>
        int main(int argc, char **argv) {
            char marker[PATH_MAX], pending[PATH_MAX];
            snprintf(marker, sizeof(marker), "%s.started", argv[0]);
            snprintf(pending, sizeof(pending), "%s.starting", argv[0]);
            FILE *file = fopen(pending, "w");
            if (!file) return 2;
            fprintf(file, "%ld", (long)getpid()); fclose(file);
            rename(pending, marker);
            if (FIXTURE_SLOW) sleep(30);
            return write(STDOUT_FILENO, "fixture\n", 8) == 8 ? 0 : 3;
        }
        """#.write(to: source, atomically: true, encoding: .utf8)
        let environment = try Self.compilerEnvironment(inherited)
        let compiler = try #require(environment["CC"]), sdk = try #require(environment["SDKROOT"])
        print("Native fixture tools: DEVELOPER_DIR=\(environment["DEVELOPER_DIR"] ?? "<unset>"), clang=\(compiler), SDKROOT=\(sdk), TOOLCHAINS=<unset> (lookup: default)")
        _ = try Self.tool(compiler, ["-isysroot", sdk, source.path,
            "-DFIXTURE_SLOW=" + (slow ? "1" : "0"), "-o", executable.path], environment: environment)
    }
    func requireStoppedIfStarted() async throws {
        guard FileManager.default.fileExists(atPath: started.path) else { return }
        let pid = try #require(Int32(String(contentsOf: started, encoding: .utf8)))
        // Signal zero only observes this fixture PID; it does not send a signal.
        for _ in 0..<100 {
            if Darwin.kill(pid, 0) == -1 && errno == ESRCH { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("The test-created child must be gone after timeout/cancellation")
    }
}

struct StubRunner: CommandRunning {
    var outputs: [String: Data] = [:]
    var failure = false
    func run(_ command: InventoryCommand) async throws -> Data {
        if failure { throw ScanError.timeout }
        let key = try command.arguments().joined(separator: " ")
        guard let data = outputs[key] else { throw ScanError.malformed("Missing fixture: " + key) }
        return data
    }
}
struct StubScanner: SoftwareScanner {
    var source: InstallSource
    var result: ScanResult
    var fail = false
    func scan() async throws -> ScanResult { if fail { throw ScanError.timeout }; return result }
}
struct SlowScanner: SoftwareScanner {
    let source: InstallSource = .nix
    func scan() async throws -> ScanResult { try await Task.sleep(for: .seconds(30)); return ScanResult(source) }
}

@Suite("Installation identity and evidence")
struct IdentityTests {
    @Test func samePhysicalPathMergesAndKeepsEvidence() throws {
        let box = try Sandbox(); defer { box.clean() }
        let path = try box.app()
        var app = try NativeScanner.item(at: path)
        app.installedAt = nil
        var cask = app; cask.primarySource = .homebrewCask
        cask.sources = [.init(.homebrewCask, Evidence("receipt"))]
        cask.packageID = "example"
        let merged = InventoryMerger.merge([app, cask, app])
        #expect(merged.count == 1)
        #expect(merged[0].primarySource == .homebrewCask)
        #expect(merged[0].bundleID == "org.example.app")
        #expect(merged[0].packageID == "example")
        #expect(merged[0].installedAt == nil)
    }
    @Test func separateCopiesAndSameNamesStaySeparate() {
        var a = SoftwareItem(name: "Same", path: "/Applications/A.app")
        var b = SoftwareItem(name: "Same", path: "/Applications/B.app")
        a.bundleID = "same.id"; b.bundleID = "same.id"
        #expect(InventoryMerger.merge([a, b]).count == 2)
    }
    @Test func symlinkIdentity() throws {
        let box = try Sandbox(); defer { box.clean() }
        let path = try box.app("Space Ω.app")
        let alias = box.root.appendingPathComponent("Linked.app").path
        try FileManager.default.createSymbolicLink(atPath: alias, withDestinationPath: path)
        let items = InventoryMerger.merge([try NativeScanner.item(at: path), try NativeScanner.item(at: alias)])
        #expect(items.count == 1)
    }
    @Test func contradictoryOwnersAreAmbiguous() {
        var a = SoftwareItem(name: "A", source: .homebrewCask, path: "/Applications/A.app")
        a.sources.append(.init(.macPorts, Evidence("registry")))
        #expect(InventoryMerger.merge([a])[0].primarySource == .unknown)
    }
    @Test func installerMechanismDoesNotConflictWithManager() {
        var a = SoftwareItem(name: "A", source: .homebrewCask, path: "/Applications/A.app")
        a.sources.append(.init(.pkg, Evidence("receipt")))
        #expect(InventoryMerger.merge([a])[0].primarySource == .homebrewCask)
    }
    @Test func incompleteOwnershipIsNotDirectDownloadProof() {
        #expect(InventoryMerger.merge([SoftwareItem(name: "A")], uncertainOwnership: true)[0].primarySource == .unknown)
    }
    @Test func bundleCreationIsNotInstallation() throws {
        let box = try Sandbox(); defer { box.clean() }
        let item = try NativeScanner.item(at: box.app())
        #expect(item.installedAt == nil)
        #expect(item.fileCreatedAt != nil)
        #expect(item.evidence["installedAt"]?.availability == .notAvailable)
    }
    @Test func receiptPresenceIsInferred() throws {
        let box = try Sandbox(); defer { box.clean() }
        let path = try box.app()
        try box.write("Example.app/Contents/_MASReceipt/receipt", "not authenticated")
        let item = try NativeScanner.item(at: path)
        #expect(item.primarySource == .appStore)
        #expect(item.confidence == .inferred)
    }
    @Test func steamPayloadOwnsContainedApp() {
        var game = SoftwareItem(name: "Game", kind: .game, source: .steam, path: "/Games/Game")
        game.relatedPaths = ["/Games/Game/Game.app"]
        let app = SoftwareItem(name: "Game", path: "/Games/Game/Game.app")
        let result = InventoryMerger.merge([app, game])
        #expect(result.count == 1)
        #expect(result[0].primarySource == .steam)
        #expect(result[0].path == "/Games/Game")
    }
}

@Suite("Conservative smart views and filters")
struct FilterTests {
    let now = Date(timeIntervalSince1970: 1_750_000_000)
    @Test func missingUsageNeverMeansUnused() {
        var filter = InventoryFilter(); filter.view = .unused
        #expect(!filter.matches(SoftwareItem(name: "Unknown use"), configuration: ScanConfiguration(), now: now))
        var noEvidence = SoftwareItem(name: "No provenance"); noEvidence.lastOpenedAt = now.addingTimeInterval(-400 * 86400)
        #expect(!filter.matches(noEvidence, configuration: ScanConfiguration(), now: now))
    }
    @Test func excludesCLIAndSystemFromUnused() {
        var filter = InventoryFilter(); filter.view = .unused; filter.showSystem = true
        var item = SoftwareItem(name: "Old"); item.lastOpenedAt = now.addingTimeInterval(-366 * 86400)
        item.evidence["lastOpenedAt"] = Evidence("Spotlight", confidence: .inferred)
        #expect(filter.matches(item, configuration: ScanConfiguration(), now: now))
        item.kind = .cli
        #expect(!filter.matches(item, configuration: ScanConfiguration(), now: now))
        item.kind = .app; item.isSystem = true
        #expect(!filter.matches(item, configuration: ScanConfiguration(), now: now))
    }
    @Test func recentRequiresVerifiedInstallDate() {
        var filter = InventoryFilter(); filter.view = .recent
        var item = SoftwareItem(name: "New"); item.installedAt = now
        #expect(!filter.matches(item, configuration: ScanConfiguration(), now: now))
        item.evidence["installedAt"] = Evidence("receipt")
        #expect(filter.matches(item, configuration: ScanConfiguration(), now: now))
        item.installedAt = now.addingTimeInterval(500)
        #expect(!filter.matches(item, configuration: ScanConfiguration(), now: now))
    }
    @Test func unknownSizeDoesNotMatchLarge() {
        var filter = InventoryFilter(); filter.view = .large
        #expect(!filter.matches(SoftwareItem(name: "A"), configuration: ScanConfiguration()))
    }
    @Test func combinedSearchKindSourceSizeConfidenceAndDates() {
        var item = SoftwareItem(name: "Café Tool", kind: .package, source: .homebrewFormula, path: "/opt/homebrew/Cellar/cafe/2", packageID: "cafe")
        item.sizeBytes = 200; item.installedAt = now
        var filter = InventoryFilter(); filter.search = "CAFE"; filter.kind = .package; filter.source = .homebrewFormula
        filter.minimumSize = 100; filter.confidence = .verified; filter.installedAfter = now.addingTimeInterval(-1)
        #expect(filter.matches(item, configuration: ScanConfiguration(), now: now))
        filter.minimumSize = 201
        #expect(!filter.matches(item, configuration: ScanConfiguration(), now: now))
    }
    @Test func searchesAllSpecifiedFields() {
        var item = SoftwareItem(name: "App", source: .homebrewCask, path: "/Applications/Unusual.app", packageID: "special-token")
        item.bundleID = "org.example.unique"; item.version = "9.8.7"
        for term in ["unusual", "special-token", "unique", "9.8.7", "homebrew", "app"] {
            var filter = InventoryFilter(); filter.search = term
            #expect(filter.matches(item, configuration: ScanConfiguration()))
        }
    }
}

@Suite("Scanner fixtures")
struct ScannerTests {
    @Test func nativeNestedBundlesAndSymlinkCycles() async throws {
        let box = try Sandbox(); defer { box.clean() }
        _ = try box.app("Vendor/Example.app")
        _ = try box.app("Vendor/Example.app/Contents/Helper.app", id: "helper")
        try FileManager.default.createSymbolicLink(atPath: box.root.appendingPathComponent("cycle").path, withDestinationPath: box.root.path)
        let result = try await NativeScanner(roots: [box.root.path]).scan()
        #expect(result.items.count == 1)
    }
    @Test func symlinkedAppIsDiscoveredThroughParentDirectory() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let path = try box.app("Payload/Browser.app")
        try FileManager.default.createDirectory(at: box.root.appendingPathComponent("Applications"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: box.root.appendingPathComponent("Applications/Browser.app").path, withDestinationPath: path)
        let result = try await NativeScanner(roots: [box.root.appendingPathComponent("Applications").path]).scan()
        #expect(result.items.count == 1)
        #expect(result.items[0].path == FileSystem.canonical(path))
    }
    @Test func nixModernAndLegacyPositiveFixtures() throws {
        let modern = Data("{\"elements\":{\"hello\":{\"name\":\"hello\",\"storePaths\":[\"/nix/store/abcd-hello-1\"]}}}".utf8)
        let legacy = Data("{\"hello-1\":{\"name\":\"hello-1\",\"outputs\":{\"out\":\"/nix/store/abcd-hello-1\"}}}".utf8)
        #expect(try NixScanner.parse(modern, exists: { _ in true }).first?.packageID == "hello")
        #expect(try NixScanner.parse(legacy, exists: { _ in true }).first?.path == "/nix/store/abcd-hello-1")
    }
    @Test func homebrewAbsentAndEmptyAreDistinct() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let absent = try await HomebrewScanner(source: .homebrewFormula, prefixes: [box.root.path]).scan()
        #expect(absent.report.state == .notInstalled)
        try FileManager.default.createDirectory(at: box.root.appendingPathComponent("Cellar"), withIntermediateDirectories: true)
        let empty = try await HomebrewScanner(source: .homebrewFormula, prefixes: [box.root.path], runner: StubRunner(outputs: ["list --formula --versions": Data()])).scan()
        #expect(empty.report.state == .empty)
    }
    @Test func malformedNativeBundleDoesNotHideValidApps() async throws {
        let box = try Sandbox(); defer { box.clean() }
        _ = try box.app()
        try box.write("Broken.app/Contents/Info.plist", "not a plist")
        let result = try await NativeScanner(roots: [box.root.path]).scan()
        #expect(result.report.state == .failed)
        #expect(result.items.count == 2)
        #expect(result.items.contains { $0.name == "Broken" && $0.installationHealth.status == .attention })
    }
    @Test func missingAdditionalProvidersAreNotInstalled() async throws {
        let root = "/private/tmp/macventory-missing-" + UUID().uuidString
        #expect(try await MacPortsScanner(executable: root + "/port").scan().report.state == .notInstalled)
        #expect(try await NixScanner(executable: root + "/nix").scan().report.state == .notInstalled)
        #expect(try await SetappScanner(roots: [root]).scan().report.state == .notInstalled)
        #expect(try await SteamScanner(root: root).scan().report.state == .notInstalled)
    }
    @Test func multipleKegsAndMalformedReceiptIsolation() async throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Cellar/tool/1/INSTALL_RECEIPT.json", "{\"time\":1700000000,\"installed_on_request\":true}")
        try box.write("Cellar/tool/2/INSTALL_RECEIPT.json", "{\"time\":1710000000}")
        try box.write("Cellar/broken/1/INSTALL_RECEIPT.json", "broken")
        let result = try await HomebrewScanner(source: .homebrewFormula, prefixes: [box.root.path]).scan()
        #expect(result.items.count == 2)
        #expect(Set(result.items.map(\.id)).count == 2)
        #expect(result.report.state == .failed)
        #expect(result.items.allSatisfy { $0.installedAt != nil && $0.lastOpenedAt == nil })
    }
    @Test func caskArtifactWithSpacesAndMissingPayload() throws {
        let box = try Sandbox(); defer { box.clean() }
        let path = try box.app("Applications/Space Ω.app", name: "Renamed Display")
        let prefix = "Caskroom/example"
        try box.write(prefix + "/.metadata/INSTALL_RECEIPT.json", "{\"time\":1700000000,\"source\":{\"version\":\"1\"},\"uninstall_artifacts\":[{\"app\":[\"Space Ω.app\"]}]}")
        let config = ["default": ["appdir": box.root.appendingPathComponent("Applications").path]]
        let data = try JSONSerialization.data(withJSONObject: config)
        try box.write(prefix + "/.metadata/config.json", String(decoding: data, as: UTF8.self))
        let items = try HomebrewScanner.cask(box.root.appendingPathComponent(prefix).path)
        #expect(items.first?.path == FileSystem.canonical(path))
        #expect(items.first?.name == "Renamed Display")
        try FileManager.default.removeItem(atPath: path)
        let orphan = try HomebrewScanner.cask(box.root.appendingPathComponent(prefix).path)
        #expect(orphan.first?.path == nil)
        #expect(orphan.first?.kind == .package)
    }
    @Test func caskroomBundleFallbackKeepsApplicationPath() throws {
        let box = try Sandbox(); defer { box.clean() }
        let prefix = "Caskroom/fallback-app"
        let path = try box.app(prefix + "/1.0.0/Fallback.app", id: "org.example.fallback", name: "Fallback Display")
        try box.write(prefix + "/.metadata/INSTALL_RECEIPT.json", "{\"time\":1700000000,\"source\":{\"version\":\"1.0.0\"}}")

        let items = try HomebrewScanner.cask(box.root.appendingPathComponent(prefix).path)

        #expect(items.count == 1)
        #expect(items.first?.name == "Fallback Display")
        #expect(items.first?.path == FileSystem.canonical(path))
        #expect(items.first?.kind == .app)
        #expect(items.first?.primarySource == .homebrewCask)
        #expect(items.first?.attributes["Payload"] == "Caskroom application bundle")
    }
    @Test func appStoreEmptyWithoutReceipts() async throws {
        let box = try Sandbox(); defer { box.clean() }
        _ = try box.app()
        let result = try await AppStoreScanner(native: NativeScanner(roots: [box.root.path])).scan()
        #expect(result.report.state == .empty)
    }
    @Test func pkgReceiptWithMissingPayloadIsNotApp() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let plist: [String: Any] = ["pkgid": "org.test.pkg", "pkg-version": "1", "install-location": box.root.path, "volume": "/", "install-time": 1_700_000_000]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let runner = StubRunner(outputs: ["--pkgs": Data("org.test.pkg\n".utf8), "--pkg-info-plist org.test.pkg": data, "--files org.test.pkg": Data("Missing.app/Contents/Info.plist\n".utf8)])
        let result = try await PKGScanner(runner: runner).scan()
        #expect(result.items.count == 1)
        #expect(result.items[0].kind == .package)
        #expect(result.items[0].path == nil)
        #expect(result.items[0].attributes["Payload"]?.contains("Receipt only") == true)
    }
    @Test func macPortsVersionsAndMalformedOutput() throws {
        let result = try MacPortsScanner.parse("tool @1.0_0 (active)\n tool @0.9_0\n", prefix: "/opt/local")
        #expect(result.count == 2)
        #expect(Set(result.map(\.id)).count == 2)
        #expect(result[0].attributes["Active"] == "Yes")
        #expect(throws: (any Error).self) { try MacPortsScanner.parse("nonsense", prefix: "/opt/local") }
    }
    @Test func nixFormatsAndMalformedData() throws {
        #expect(try NixScanner.parse(Data("{\"elements\":{}}".utf8)).isEmpty)
        #expect(try NixScanner.parse(Data("{}".utf8)).isEmpty)
        #expect(throws: (any Error).self) { try NixScanner.parse(Data("{\"invalid\":42}".utf8)) }
        #expect(throws: (any Error).self) { try NixScanner.parse(Data("not json".utf8)) }
        let absent = try NixScanner.parse(Data("{\"elements\":{\"hello\":{\"storePaths\":[\"/nix/store/absent-test\"]}}}".utf8))
        #expect(absent.count == 1)
        #expect(absent.first?.installationHealth.status == .attention)
        #expect(absent.first?.health?.registration == .installed)
    }
    @Test func keyValuesEscapesNestingAndErrors() throws {
        let value = try KeyValues.parse("// Comment\n\"root\" { \"name\" \"Space Ω\" \"nested\" { \"x\" \"y\" } }")
        #expect(value["root"]?.object?["name"]?.text == "Space Ω")
        for malformed in ["\"x\" {", "\"x\"", "}", "\"x\" \"unterminated"] {
            #expect(throws: (any Error).self) { try KeyValues.parse(malformed) }
        }
    }
    @Test func steamManifestDoesNotInventProductVersionOrInstallDate() async throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("steamapps/appmanifest_123.acf", "\"AppState\" { \"appid\" \"123\" \"name\" \"Test Game\" \"installdir\" \"Test Game\" \"buildid\" \"42\" \"LastUpdated\" \"1700000000\" }")
        try box.write("steamapps/common/Test Game/game.bin", "game")
        let result = try await SteamScanner(root: box.root.path).scan()
        #expect(result.items.count == 1)
        #expect(result.items[0].version == nil)
        #expect(result.items[0].installedAt == nil)
        #expect(result.items[0].updatedAt != nil)
    }
    @Test func steamRejectsPathEscape() async throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("steamapps/appmanifest_1.acf", "\"AppState\" { \"appid\" \"1\" \"installdir\" \"../../escape\" }")
        #expect(try await SteamScanner(root: box.root.path).scan().items.isEmpty)
    }
    @Test func setappNeedsMoreThanFolderName() async throws {
        let box = try Sandbox(); defer { box.clean() }
        _ = try box.app()
        #expect(try await SetappScanner(roots: [box.root.path]).scan().items.isEmpty)
        try FileManager.default.createDirectory(at: box.root.appendingPathComponent("Example.app/Contents/Frameworks/Setapp.framework"), withIntermediateDirectories: true)
        let result = try await SetappScanner(roots: [box.root.path]).scan()
        #expect(result.items.count == 1)
        #expect(result.items[0].confidence == .inferred)
    }
    @Test func toolboxDoesNotClaimStandaloneJetBrainsIDE() async throws {
        let box = try Sandbox(); defer { box.clean() }
        _ = try box.app(id: "com.jetbrains.idea", name: "IntelliJ IDEA")
        #expect(try await ToolboxScanner(roots: [box.root.path]).scan().items.isEmpty)
    }
    @Test func toolboxLegacyProviderOwnedLayout() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let root = "JetBrains/Toolbox/apps"
        _ = try box.app(root + "/IDEA-U/ch-0/243.123/IntelliJ IDEA.app", id: "com.jetbrains.idea", name: "IntelliJ IDEA")
        let result = try await ToolboxScanner(roots: [box.root.appendingPathComponent(root).path]).scan()
        #expect(result.items.count == 1)
        #expect(result.items[0].primarySource == .toolbox)
        #expect(result.items[0].confidence == .inferred)
    }
}

@Suite("Cache, size, coordination and safety")
struct InfrastructureTests {
    @Test func unknownSortsLastInBothDirections() {
        var known = SoftwareItem(name: "Known", path: "/known"); known.sizeBytes = 2
        let unknown = SoftwareItem(name: "Unknown", path: "/unknown")
        for descending in [true, false] {
            #expect(InventorySort.sorted([unknown, known], by: .size, descending: descending).last?.name == "Unknown")
        }
    }
    @Test func equalSortValuesUseStableIdentity() {
        let a = SoftwareItem(name: "Same", path: "/a"), b = SoftwareItem(name: "Same", path: "/b")
        #expect(InventorySort.sorted([b, a]).map(\.id) == [a.id, b.id])
    }
    @Test func snapshotRoundTripAndUnsupportedVersion() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let store = SnapshotStore(directory: box.root)
        #expect(try await store.load() == nil)
        var snapshot = InventorySnapshot(items: [SoftwareItem(name: "A")], reports: [])
        try await store.save(snapshot)
        #expect(try await store.load()?.items.first?.stale == true)
        snapshot.schemaVersion = 99
        try await store.save(snapshot)
        await #expect(throws: (any Error).self) { try await store.load() }
        try await store.clear()
        #expect(try await store.load() == nil)
    }
    @Test func corruptCacheIsReported() async throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("inventory.json", "corrupt")
        await #expect(throws: (any Error).self) { try await SnapshotStore(directory: box.root).load() }
    }
    @Test func sizesDoNotFollowSymlinksOrDoubleCountHardlinks() throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("app/file", "12345")
        try FileManager.default.linkItem(at: box.root.appendingPathComponent("app/file"), to: box.root.appendingPathComponent("app/hardlink"))
        try box.write("outside", "1234567890")
        try FileManager.default.createSymbolicLink(atPath: box.root.appendingPathComponent("app/external").path, withDestinationPath: box.root.appendingPathComponent("outside").path)
        let footprint = try SizeMeasurer.measure(box.root.appendingPathComponent("app").path)
        #expect(footprint.bytes == 5)
        #expect(footprint.complete)
        #expect(try !SizeMeasurer.measure(box.root.appendingPathComponent("app").path, maximumEntries: 1).complete)
    }
    @Test func failureRetainsStaleSourceAndDoesNotBlockOthers() async {
        let old = SoftwareItem(name: "Old", source: .homebrewFormula, path: "/old")
        let new = SoftwareItem(name: "New", source: .unmanaged, path: "/new")
        let previous = InventorySnapshot(items: [old], reports: [], observations: [InstallSource.homebrewFormula.rawValue: [old]])
        let scanners: [any SoftwareScanner] = [StubScanner(source: .homebrewFormula, result: ScanResult(.homebrewFormula), fail: true), StubScanner(source: .unmanaged, result: ScanResult(.unmanaged, items: [new]))]
        let result = await InventoryService().scan(configuration: ScanConfiguration(), previous: previous, measureSizes: false, scanners: scanners) { _ in }
        #expect(result.items.count == 2)
        #expect(result.items.first(where: { $0.name == "Old" })?.stale == true)
        #expect(result.reports.contains { $0.state == .failed })
    }
    @Test func successRemovesOldSourceObservations() async {
        let old = SoftwareItem(name: "Old", source: .homebrewFormula)
        let previous = InventorySnapshot(items: [old], reports: [], observations: [InstallSource.homebrewFormula.rawValue: [old]])
        let result = await InventoryService().scan(configuration: ScanConfiguration(), previous: previous, measureSizes: false, scanners: [StubScanner(source: .homebrewFormula, result: ScanResult(.homebrewFormula))]) { _ in }
        #expect(result.items.isEmpty)
    }
    @Test func sanitizedDiagnosticsExcludePrivateText() throws {
        var item = SoftwareItem(name: "Private App", path: "/Users/private/secret.app"); item.packageID = "secret.identifier"
        let snapshot = InventorySnapshot(items: [item], reports: [.init(.pkg, .failed, "/Users/private/secret")])
        let text = String(decoding: try Diagnostics.sanitized(snapshot), as: UTF8.self)
        #expect(!text.contains("private")); #expect(!text.contains("secret")); #expect(!text.contains("Private App"))
    }
    @Test func commandArgumentsRejectInjectionAndAreReadOnly() throws {
        for text in ["-uninstall", "hello; rm -rf /", "$(curl bad)", "../escape", ""] {
            #expect(throws: (any Error).self) { try InventoryCommand.receiptInfo(text).arguments() }
        }
        let commands: [InventoryCommand] = [.receipts, .receiptInfo("org.example.pkg"), .receiptFiles("org.example.pkg"), .ports(executable: "/opt/local/bin/port"), .portContents(executable: "/opt/local/bin/port", name: "foo"), .nix(executable: "/nix/bin/nix", profile: nil), .legacyNix(executable: "/nix/bin/nix-env")]
        for command in commands {
            let arguments = try command.arguments()
            #expect(!arguments.contains { ["uninstall", "install", "update", "upgrade", "remove", "sudo"].contains($0) })
        }
    }
    @Test(arguments: [false, true]) func nativeFixtureCompilesWithConflictingHostEnvironment(explicitDeveloper: Bool) async throws {
        let box = try Sandbox(); defer { box.clean() }
        let baseline = try NativeProcessFixture.compilerEnvironment(ProcessInfo.processInfo.environment)
        let selected = try #require(baseline["DEVELOPER_DIR"])
        // Model a hosted Xcode identity using a test-owned alias to the installed tools.
        let contents = box.root.appendingPathComponent("FixtureXcode.app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let developer = contents.appendingPathComponent("Developer")
        try FileManager.default.createSymbolicLink(atPath: developer.path, withDestinationPath: selected)
        var inherited = ["SDKROOT": box.root.appendingPathComponent("Missing.sdk").path,
            "TOOLCHAINS": "missing-toolchain", "CC": "/missing/clang",
            "DYLD_FRAMEWORK_PATH": developer.path + "/Platforms/MacOSX.platform/Developer/Library/Frameworks",
            "DYLD_LIBRARY_PATH": "/missing/libraries", "DYLD_INSERT_LIBRARIES": "/missing/injection.dylib",
            "__XPC_DYLD_FRAMEWORK_PATH": "/missing/frameworks"]
        if explicitDeveloper {
            inherited["DEVELOPER_DIR"] = developer.path
            inherited["DYLD_FRAMEWORK_PATH"] = box.root.appendingPathComponent("UnavailableXcode.app").path + "/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
        }
        let sanitized = try NativeProcessFixture.compilerEnvironment(inherited)
        #expect(sanitized == baseline)
        let fixture = try NativeProcessFixture(box, compilerEnvironment: inherited)
        #expect(try await ProcessRunner(timeout: .seconds(5)).run(fixture.command) == Data("fixture\n".utf8))
        if explicitDeveloper {
            inherited["DEVELOPER_DIR"] = box.root.appendingPathComponent("MissingDeveloper").path
            do {
                _ = try NativeProcessFixture.compilerEnvironment(inherited)
                Issue.record("An invalid explicit developer directory must fail, not silently select another Xcode")
            } catch ScanError.process(let diagnostic) {
                #expect(diagnostic.contains("/usr/bin/xcrun") && diagnostic.contains("DEVELOPER_DIR=") && diagnostic.contains("exit "))
            }
        }
    }
    @Test func processOutputLimitAndTimeoutAreEnforced() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let fixture = try NativeProcessFixture(box)
        for timeout: Duration in [.zero, .seconds(-1), .nanoseconds(1)] {
            do { _ = try await ProcessRunner(timeout: timeout).run(fixture.command); Issue.record("Expired timeout succeeded") }
            catch ScanError.timeout {} catch { Issue.record("Expected ScanError.timeout, got \(error)") }
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.started.path))
        #expect(try await ProcessRunner(timeout: .seconds(5)).run(fixture.command) == Data("fixture\n".utf8))
        do { _ = try await ProcessRunner(outputLimit: 1).run(fixture.command); Issue.record("Output limit succeeded") }
        catch ScanError.limit {} catch { Issue.record("Expected ScanError.limit, got \(error)") }
        let slow = try NativeProcessFixture(box, slow: true)
        do { _ = try await ProcessRunner(timeout: .milliseconds(100)).run(slow.command); Issue.record("Slow fixture exceeded deadline") }
        catch ScanError.timeout {} catch { Issue.record("Expected ScanError.timeout, got \(error)") }
        try await slow.requireStoppedIfStarted()
    }
    @Test func canceledProcessDoesNotContinue() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let fixture = try NativeProcessFixture(box, slow: true)
        let task = Task { try await ProcessRunner().run(fixture.command) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        try await fixture.requireStoppedIfStarted()
    }
    @Test func processTimeoutIsDeterministicUnderConcurrency() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let fixture = try NativeProcessFixture(box)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<64 {
                group.addTask { () async throws -> Void in
                    for timeout: Duration in [.zero, .seconds(-1), .nanoseconds(1)] {
                        do { _ = try await ProcessRunner(timeout: timeout).run(fixture.command); Issue.record("Concurrent expired timeout succeeded") }
                        catch ScanError.timeout {} catch { Issue.record("Expected ScanError.timeout, got \(error)") }
                    }
                    #expect(try await ProcessRunner(timeout: .seconds(5)).run(fixture.command) == Data("fixture\n".utf8))
                }
            }
            try await group.waitForAll()
        }
    }
    @Test func cancelingStartedFixtureStopsChild() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let fixture = try NativeProcessFixture(box, slow: true)
        let task = Task { try await ProcessRunner().run(fixture.command) }
        for _ in 0..<500 where !FileManager.default.fileExists(atPath: fixture.started.path) {
            try await Task.sleep(for: .milliseconds(10))
        }
        task.cancel()
        #expect(FileManager.default.fileExists(atPath: fixture.started.path))
        await #expect(throws: CancellationError.self) { try await task.value }
        try await fixture.requireStoppedIfStarted()
    }
    @Test func canceledScanReportsCancellationAndKeepsOldData() async {
        let old = SoftwareItem(name: "Old", source: .nix, path: "/nix/store/old")
        let previous = InventorySnapshot(items: [old], reports: [], observations: [InstallSource.nix.rawValue: [old]])
        let task = Task { await InventoryService().scan(configuration: ScanConfiguration(), previous: previous, measureSizes: false, scanners: [SlowScanner()]) { _ in } }
        task.cancel()
        let result = await task.value
        #expect(result.reports.first?.state == .canceled)
        #expect(result.items.first?.stale == true)
    }
    @Test func processStructuredOutputIsDrainedCompletely() async throws {
        let receiptData = try await ProcessRunner().run(.receipts)
        let id = try #require(String(decoding: receiptData, as: UTF8.self).split(separator: "\n").map(String.init).first(where: FileSystem.validPackageIdentifier))
        for _ in 0..<3 {
            let data = try await ProcessRunner().run(.receiptInfo(id))
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            #expect(plist?["pkgid"] as? String == id)
        }
    }
}
