import Foundation
import Testing
@testable import MacventoryCore

private struct DeniedListing: AppDataDirectoryListing {
    var denyAll = false
    func children(_ path: String) throws -> [URL] {
        if denyAll || path.hasSuffix("Preferences") { throw ScanError.permission }
        return try FileSystem.children(path)
    }
}
@Suite("Universal leftover discovery with isolated filesystem fixtures")
struct LeftoverDiscoveryTests {
    @Test func localManifestCorrelatesRenamedSupportDirectoryWithoutNameGuessing() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("Library/Application Support/Renamed Workspace/package.json", "{\"build\":{\"appId\":\"net.example.workspace\"}}")
        let result = engine(box).scan(records: [], installed: [])
        #expect(result.groups.count == 1)
        #expect(result.groups.first?.identity.bundleID == "net.example.workspace")
        #expect(result.groups.first?.candidates.contains { $0.path.hasSuffix("Application Support/Renamed Workspace") && $0.classification == .possible } == true)
    }
    @Test func cancelledScanHasAnExplicitState() async throws {
        let box = try Sandbox(); defer { box.clean() }
        let service = engine(box)
        let task = Task { () -> LeftoverScanResult in
            try? await Task.sleep(for: .milliseconds(5))
            return service.scan(records: [], installed: [])
        }
        task.cancel()
        #expect(await task.value.state == .cancelled)
    }
    private func engine(_ box: Sandbox) -> LeftoverDiscoveryService { .init(discovery: AppDataDiscoveryService(library: box.root.appendingPathComponent("Library"), home: box.root)) }
    @Test func emptyHistoryDoesNotCreateActionableGroup() throws {
        let box = try Sandbox(); defer { box.clean() }
        let record = RemovedApplicationRecord(name: "Xcodes fixture", bundleID: "org.example.empty", ownershipEvidence: "Historical synthetic record")
        let result = engine(box).scan(records: [record], installed: [])
        #expect(result.state == .completed)
        #expect(result.groups.isEmpty)
    }
    @Test func manualRemovalWithNoHistoryDiscoversAllExactSourcesAndProtectsGroups() throws {
        let box = try Sandbox(); defer { box.clean() }
        for location in ["Application Support/org.unknown.product/file", "Caches/org.unknown.product/cache", "Preferences/org.unknown.product.plist", "Containers/org.unknown.product/data", "Group Containers/org.unknown.product/shared", "Saved Application State/org.unknown.product.savedState/state"] { try box.write("Library/" + location, "fixture") }
        let result = engine(box).scan(records: [], installed: [])
        let group = try #require(result.groups.first)
        #expect(result.groups.count == 1)
        #expect(group.candidates.count == 6)
        #expect(group.candidates.filter { $0.category == "Group Container" }.allSatisfy { !$0.eligibleForTrash })
        #expect(group.candidates.allSatisfy { !$0.isAutomaticSelection })
    }
    @Test func currentAndReinstalledApplicationsAreExcludedEvenWithRemovalHistory() throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Library/Caches/net.example.editor/file", "fixture")
        var installed = SoftwareItem(name: "Renamed Editor", path: "/Applications/Editor.app"); installed.bundleID = "net.example.editor"
        let record = RemovedApplicationRecord(name: "Old Editor", bundleID: installed.bundleID, ownershipEvidence: "Synthetic removal")
        #expect(engine(box).scan(records: [record], installed: [installed]).groups.isEmpty)
        #expect(engine(box).scan(records: [], installed: [], registeredApplication: { $0 == "net.example.editor" }).groups.isEmpty)
    }
    @Test func staleHistoryCannotSelectVerifiedAndSimilarNamesRemainUnassociated() throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Library/Caches/net.example.editor/file", "fixture")
        try box.write("Library/Application Support/Editor-other/file", "unrelated")
        let record = RemovedApplicationRecord(name: "Editor", bundleID: "net.example.editor", ownershipEvidence: "Old synthetic record", removalDate: Date().addingTimeInterval(-40 * 86400))
        let result = engine(box).scan(records: [record], installed: [])
        #expect(result.groups.count == 1)
        #expect(result.groups.first?.candidates.count == 1)
        #expect(result.groups.first?.candidates.first?.classification == .possible)
    }
    @Test func permissionFailureIsDistinctFromEmptyAndPreservesFoundCandidates() throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Library/Caches/net.example.editor/file", "fixture")
        let service = LeftoverDiscoveryService(discovery: AppDataDiscoveryService(library: box.root.appendingPathComponent("Library")), listing: DeniedListing())
        let result = service.scan(records: [], installed: [])
        #expect(result.state == .partial)
        #expect(!result.groups.isEmpty)
        let denied = LeftoverDiscoveryService(discovery: AppDataDiscoveryService(library: box.root.appendingPathComponent("Library")), listing: DeniedListing(denyAll: true)).scan(records: [], installed: [])
        #expect(denied.state == .failed)
        #expect(!denied.messages.isEmpty)
    }
    @Test func deletedCandidateDisappearsOnRefreshWhileOtherGroupsRemain() throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Library/Caches/net.example.first/file", "fixture")
        try box.write("Library/Caches/net.example.second/file", "fixture")
        #expect(engine(box).scan(records: [], installed: []).groups.count == 2)
        // Remove only this disposable test fixture to model an external filesystem change.
        try FileManager.default.removeItem(at: box.root.appendingPathComponent("Library/Caches/net.example.first"))
        let result = engine(box).scan(records: [], installed: [])
        #expect(result.groups.count == 1)
        #expect(result.groups.first?.identity.bundleID == "net.example.second")
    }
    @Test func documentsDesktopDownloadsAreNeverEnumerated() throws {
        let box = try Sandbox(); defer { box.clean() }
        for root in ["Documents", "Desktop", "Downloads"] { try box.write(root + "/net.example.personal/file", "personal fixture") }
        #expect(engine(box).scan(records: [], installed: []).groups.isEmpty)
    }
    @Test func applicationGroupingUsesOnlyRecognizableEvidenceAndPreservesCandidateIdentities() {
        func candidate(_ path: String) -> AppDataCandidate {
            .init(path: path, category: "Caches", classification: .possible, explanation: "Fixture", sizeBytes: 12, sizeComplete: true, requiresExplicitSelection: true, allowedRoot: "/Library/Caches", identity: nil)
        }
        let kimi = ApplicationIdentity(name: "Kimi", bundleID: "com.example.kimi", evidence: "Recorded verified removal", installed: false)
        var helper = ApplicationIdentity(name: "Kimi", bundleID: "com.example.kimi.helper", evidence: "Recorded verified helper relationship", installed: false)
        helper.parentBundleID = kimi.bundleID; helper.parentApplicationName = kimi.name
        let unknownA = ApplicationIdentity(name: "com.example.unknown", bundleID: "com.example.unknown", evidence: "Exact identifier found in Caches", installed: false)
        let unknownB = ApplicationIdentity(name: "com.example.unknown.helper", bundleID: "com.example.unknown.helper", evidence: "Exact identifier found in Caches", installed: false)
        let results = [
            AppDataDiscoveryResult(identity: kimi, candidates: [candidate("/Library/Caches/com.example.kimi")]),
            AppDataDiscoveryResult(identity: helper, candidates: [candidate("/Library/Caches/com.example.kimi.helper")]),
            AppDataDiscoveryResult(identity: unknownA, candidates: [candidate("/Library/Caches/com.example.unknown")]),
            AppDataDiscoveryResult(identity: unknownB, candidates: [candidate("/Library/Caches/com.example.unknown.helper")])
        ]
        let application = LeftoverPresentationGroup.make(from: results, mode: .application)
        #expect(application.count == 3)
        let kimiGroup = application.first { $0.name == "Kimi" }
        #expect(kimiGroup?.candidates.count == 2)
        #expect(Set(kimiGroup?.candidates.map { $0.identity.bundleID } ?? []) == ["com.example.kimi", "com.example.kimi.helper"])
        #expect(LeftoverPresentationGroup.make(from: results, mode: .identifier).count == 4)
    }
    @Test func partialScanReportsStructuredLocationIssues() throws {
        let box = try Sandbox(); defer { box.clean() }
        try box.write("Library/Caches/net.example.editor/cache", "fixture")
        let service = LeftoverDiscoveryService(discovery: AppDataDiscoveryService(library: box.root.appendingPathComponent("Library")), listing: DeniedListing())
        let result = service.scan(records: [], installed: [])
        #expect(result.state == .partial)
        #expect(result.issues.contains { $0.location == "Preferences" && $0.retryable })
        #expect(result.groups.first?.candidates.first?.eligibleForTrash == true)
    }
}
