import Foundation
import Testing
@testable import MacventoryCore

@Suite("Independent uninstall audit regressions")
struct FinalUninstallAuditTests {
    private func cask(_ box: Sandbox, kind: String = "app") throws -> HomebrewScanner {
        let prefix = box.root.path
        try box.write("bin/brew", "Inert fixture; never executed")
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: prefix + "/bin/brew")
        let value = kind == "app" ? "Example.app" : "Example.ttf"
        let object: [String: Any] = ["source": ["version": "1.0"], "uninstall_artifacts": [[kind: [value]]]]
        try box.write("Caskroom/example/.metadata/INSTALL_RECEIPT.json", String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self))
        try box.write("Caskroom/example/.metadata/config.json", String(decoding: try JSONSerialization.data(withJSONObject: ["explicit": ["appdir": prefix + "/Applications", "fontdir": prefix + "/Fonts"]]), as: UTF8.self))
        return HomebrewScanner(source: .homebrewCask, prefixes: [prefix], runner: StubRunner(outputs: ["list --cask --versions": Data("example 1.0".utf8)]))
    }
    @Test func caskMappingChangedBetweenDiscoveryAndReviewCannotTargetAnotherCopy() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let scanner = try cask(box)
        let item = try #require(try await scanner.scan().items.first)
        #expect(UninstallPlanner.plan(for: item).canExecute)
        let other = try box.app("Other/Example.app")
        try box.write("Caskroom/example/.metadata/config.json", String(decoding: try JSONSerialization.data(withJSONObject: ["explicit": ["appdir": box.root.path + "/Other"]]), as: UTF8.self))
        let rejected = UninstallPlanner.plan(for: item)
        #expect(rejected.isBlocked && rejected.explanation.contains("changed since discovery"))
        #expect(FileSystem.exists(other))
        let refreshed = try #require(try await scanner.scan().items.first)
        #expect(refreshed.path == other && UninstallPlanner.plan(for: refreshed).canExecute)
    }
    @Test func caskPresenceChangedBetweenDiscoveryAndReviewRequiresRefresh() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let scanner = try cask(box)
        let item = try #require(try await scanner.scan().items.first)
        _ = try box.app("Applications/Example.app")
        #expect(UninstallPlanner.plan(for: item).isBlocked)
    }
    @Test func retainedFontWithoutRegistrationIsAttentionRatherThanHistorical() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        var scanner = try cask(box, kind: "font")
        try box.write("Fonts/Example.ttf", "Keep this retained artifact visible")
        scanner.runner = StubRunner(outputs: ["list --cask --versions": Data()])
        let item = try #require(try await scanner.scan().items.first)
        #expect(item.path == nil && item.health?.registration == .absent)
        #expect(item.installationHealth.status == .attention)
        #expect(!UninstallPlanner.plan(for: item).canExecute)
    }
    @Test func interactiveVerificationPreservesPreviousStepsAndRejectsSkippedUninstall() {
        let prior = ManagementStepResult(.clearData, .completed, "Earlier confirmed cleanup")
        let waiting = ManagementResult(steps: [prior, .init(.uninstall, .waitingForUser, "Opened official workflow")], simulated: false)
        #expect(waiting.canVerifyInteractiveRemoval)
        let verified = waiting.verifyingInteractiveRemoval(.appBundleRemoved)
        #expect(verified.steps.count == 2 && verified.steps[0].detail == prior.detail)
        #expect(verified.steps[0].status == .completed && verified.steps[1].status == .completed)
        #expect(!verified.canVerifyInteractiveRemoval)
        let skipped = ManagementResult(steps: [.init(.clearData, .failed, "Denied"), .init(.uninstall, .skipped, "Never invoked")], simulated: false)
        #expect(!skipped.canVerifyInteractiveRemoval)
        #expect(skipped.verifyingInteractiveRemoval(.appBundleRemoved).steps[1].status == .skipped)
        #expect(waiting.verifyingInteractiveRemoval(.partialRemoval).steps[1].status == .partial)
        #expect(waiting.verifyingInteractiveRemoval(.unknownResult).steps[1].status == .unknown)
    }
    @MainActor @Test func exactNativeLaunchNeverSubstitutesAnotherRunningInstallation() {
        #expect(!ExactApplicationLaunch.configuration().allowsRunningApplicationSubstitution)
    }
    @Test func sameStoreOutputFromDifferentNixProfilesCannotChooseOneSilently() {
        var first = SoftwareItem(name: "Tool", kind: .package, source: .nix, path: "/nix/store/example-tool", packageID: "tool")
        first.attributes["Nix profile"] = "/synthetic/profiles/one"
        var second = first; second.attributes["Nix profile"] = "/synthetic/profiles/two"
        let result = InventoryMerger.merge([first, second])
        #expect(result.count == 1 && result[0].primarySource == .unknown)
        #expect(UninstallPlanner.plan(for: result[0]).isBlocked)
        for token in ["not", "and", "or", "xor", "installed", "all"] { #expect(!RemovalIdentity.portName(token)) }
    }
    @Test func privilegedTrustRejectsExtendedACLWriteGrants() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("anchor", "Disposable ACL fixture")
        let path = box.root.appendingPathComponent("anchor").path
        #expect(!LiveManagedRemovalSecurity.hasExtendedACL(path))
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+a", NSUserName() + " allow write", path]
        try process.run(); process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(LiveManagedRemovalSecurity.hasExtendedACL(path))
    }
    @Test func caskStagedRunningCopyIsPartOfRemovalScopeEvenForBinaryOnlyMapping() {
        let paths = HomebrewTrust.caskRemovalScope(executable: "/opt/homebrew/bin/brew", token: "example", artifacts: ["/opt/homebrew/bin/example"])
        #expect(ProtectionPolicy.isRunningCopy(paths, runningBundle: "/opt/homebrew/Caskroom/example/1.0/Example.app"))
        #expect(!ProtectionPolicy.isRunningCopy(paths, runningBundle: "/synthetic/Build/Example.app"))
    }
    private func vendorTool(_ box: Sandbox, relative: String) throws -> String {
        let path = try box.app(relative, id: "org.example.uninstaller")
        let url = URL(fileURLWithPath: path + "/Contents/Info.plist")
        var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as! [String: Any]
        info["CFBundleExecutable"] = "Tool"
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: url)
        try box.write(relative + "/Contents/MacOS/Tool", "Inert vendor tool version one")
        return path
    }
    @Test func siblingPublisherDoesNotEstablishProductAssociation() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let app = try vendorTool(box, relative: "Shared/App.app")
        let sibling = try vendorTool(box, relative: "Shared/Uninstaller.app")
        let item = try NativeScanner.item(at: app)
        #expect(VendorUninstallerDiscovery.discover(for: item, checker: AuditSigning(paths: [app, sibling])) == nil)
        let nested = try vendorTool(box, relative: "Shared/App.app/Contents/Helpers/Uninstaller.app")
        #expect(VendorUninstallerDiscovery.discover(for: item, checker: AuditSigning(paths: [app, nested]))?.path == nested)
    }
    @Test func changedVendorExecutableCannotReuseReviewedMetadataFingerprint() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let relative = "Vendor/App.app/Contents/Helpers/Uninstaller.app"
        let tool = try vendorTool(box, relative: relative)
        let first = try VendorUninstallerDiscovery.fingerprint(path: tool, team: "FIXTURE")
        try box.write(relative + "/Contents/MacOS/Tool", "Changed code with unchanged bundle metadata")
        #expect(try VendorUninstallerDiscovery.fingerprint(path: tool, team: "FIXTURE") != first)
    }
}
private struct AuditSigning: VendorIdentityChecking {
    let paths: [String]
    func teamIdentifier(at path: String) -> String? { paths.contains(path) ? "FIXTURE" : nil }
}
