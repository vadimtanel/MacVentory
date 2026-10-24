import Foundation
import Testing
@testable import MacventoryCore

@Suite("Application data and process-management safety")
struct ApplicationManagementTests {
    @Test func exactIdentifierLocationsAreVerifiedAndNameOnlyLocationsNeedReview() throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Library/Containers/com.example.kimi/data", "fixture")
        try box.write("Library/Preferences/com.example.kimi.plist", "fixture")
        try box.write("Library/Application Support/Kimi/project.txt", "fixture")
        let result = AppDataDiscoveryService(library: box.root.appendingPathComponent("Library")).discover(for: ApplicationIdentity(name: "Kimi", bundleID: "com.example.kimi", evidence: "fixture", installed: false))
        #expect(result.candidates.contains { $0.path.hasSuffix("Containers/com.example.kimi") && $0.classification == .verified && $0.isAutomaticSelection })
        #expect(result.candidates.contains { $0.path.hasSuffix("Preferences/com.example.kimi.plist") && $0.classification == .verified })
        #expect(result.candidates.contains { $0.path.hasSuffix("Application Support/Kimi") && $0.classification == .possible && $0.requiresExplicitSelection })
    }
    @Test func groupContainersAndManualDocumentsNeverAutoSelect() throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Library/Group Containers/com.example.kimi/shared", "fixture")
        try box.write("Documents/kimi/notes.md", "personal")
        let service = AppDataDiscoveryService(library: box.root.appendingPathComponent("Library"))
        let result = service.discover(for: ApplicationIdentity(name: "Kimi", bundleID: "com.example.kimi", evidence: "fixture", installed: false))
        #expect(result.candidates.first?.classification == .protected)
        // A service rooted at the test home is used solely to prove explicit manual-selection semantics.
        let manual = AppDataDiscoveryService(library: box.root.appendingPathComponent("Library"), home: box.root).manualCandidate(path: box.root.appendingPathComponent("Documents/kimi").path)
        #expect(manual?.classification == .possible)
        #expect(manual?.requiresExplicitSelection == true)
        #expect(manual?.isAutomaticSelection == false)
    }
    @Test func nestedAndDuplicateCandidatesAreNotAutoSelectedTwice() throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Library/Containers/com.example.kimi/child/file", "fixture")
        let service = AppDataDiscoveryService(library: box.root.appendingPathComponent("Library"))
        let result = service.discover(for: ApplicationIdentity(name: "Kimi", bundleID: "com.example.kimi", evidence: "fixture", installed: false))
        #expect(result.candidates.filter { $0.path.contains("Containers/com.example.kimi") }.count == 1)
    }
    @Test func missingAndUnsafeOrInvalidIdentifiersDoNotBecomeCleanupTargets() throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Library/Caches/com.example.kimi/cache", "fixture")
        let service = AppDataDiscoveryService(library: box.root.appendingPathComponent("Library"))
        #expect(service.discover(for: ApplicationIdentity(name: "Kimi", bundleID: "com.example/../kimi", evidence: "fixture", installed: false)).candidates.isEmpty)
        #expect(service.discover(for: ApplicationIdentity(name: "Kimi", bundleID: nil, evidence: "fixture", installed: false)).candidates.isEmpty)
    }
    @Test func symbolicLinkCandidatesAreExcludedBeforeClassification() throws {
        let box = try Sandbox(); defer { box.clean() }
        let containers = box.root.appendingPathComponent("Library/Containers")
        try FileManager.default.createDirectory(at: containers, withIntermediateDirectories: true)
        let target = box.root.appendingPathComponent("Library/Elsewhere")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: containers.appendingPathComponent("com.example.kimi").path, withDestinationPath: target.path)
        let result = AppDataDiscoveryService(library: box.root.appendingPathComponent("Library")).discover(for: ApplicationIdentity(name: "Kimi", bundleID: "com.example.kimi", evidence: "fixture", installed: false))
        #expect(!result.candidates.contains { $0.path.contains("Containers/com.example.kimi") })
    }
    @Test func retrospectiveIdentifiersNeedNoHardcodedHintOrHistory() throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Library/Caches/net.unknown.editor/cache", "fixture")
        let result = LeftoverDiscoveryService(discovery: AppDataDiscoveryService(library: box.root.appendingPathComponent("Library"))).scan(records: [], installed: [])
        #expect(result.groups.count == 1)
        #expect(result.groups.first?.identity.bundleID == "net.unknown.editor")
        #expect(result.groups.first?.identity.installed == false)
        #expect(result.groups.first?.candidates.allSatisfy { $0.classification == .possible && !$0.isAutomaticSelection } == true)
    }
    @Test func removedRecordKeepsOnlyMinimalIdentity() throws {
        var item = SoftwareItem(name: "Example", path: "/Applications/Example.app")
        item.bundleID = "org.example.app"; item.primarySource = .unmanaged
        let record = RemovedApplicationRecord(item: item)
        let encoded = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(RemovedApplicationRecord.self, from: encoded)
        #expect(decoded.bundleID == "org.example.app")
        #expect(decoded.name == "Example")
    }
    @Test func simulatedExecutorsNeverChangeFixtures() async throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Library/Caches/com.example.kimi/cache", "fixture")
        let candidate = try #require(AppDataDiscoveryService(library: box.root.appendingPathComponent("Library")).discover(for: ApplicationIdentity(name: "Kimi", bundleID: "com.example.kimi", evidence: "fixture", installed: false)).candidates.first)
        let outcome = await SimulatedAppDataExecutor().execute([candidate])
        #expect(outcome.simulated)
        #expect(FileSystem.exists(candidate.path))
        #expect(!outcome.results.contains(where: { !$0.completed }))
    }
    @Test func simulatedForceQuitUsesAnExactReviewedTargetWithoutTouchingProcesses() async throws {
        var item = SoftwareItem(name: "Fixture", path: "/Applications/Fixture.app")
        item.bundleID = "org.example.fixture"
        let plan = QuitPlan(item: item, target: RunningApplicationTarget(processIdentifier: 999_999, bundleURL: "/Applications/Fixture.app", bundleID: "org.example.fixture"), mode: .force)
        #expect(try await SimulatedQuitExecutor().execute(plan))
        item.isSystem = true
        #expect(await ApplicationProcessController.target(for: item) == nil)
    }
}
