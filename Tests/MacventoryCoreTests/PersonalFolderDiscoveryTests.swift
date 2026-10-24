import Foundation
import Testing
@testable import MacventoryCore

private struct PersonalDeniedListing: AppDataDirectoryListing {
    func children(_ path: String) throws -> [URL] {
        if path.hasSuffix("Documents") { throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError) }
        return try FileSystem.children(path)
    }
}
@Suite("Opt-in personal folders remain manual-only")
struct PersonalFolderDiscoveryTests {
    private var index: ApplicationIdentityIndex { .init(entries: [.init(bundleID: "net.fiction.orchard", name: "Orchard", source: "Fixture bundle")]) }
    @Test func defaultOffAndOldConfigurationDecodeWithoutEnablingDiscovery() throws {
        #expect(!ScanConfiguration().discoverPersonalFolders)
        let encoded = try JSONEncoder().encode(ScanConfiguration())
        #expect(try !JSONDecoder().decode(ScanConfiguration.self, from: encoded).discoverPersonalFolders)
        var draft = SettingsDraft(); draft.value.discoverPersonalFolders = true
        #expect(try draft.commit().requiresLeftoverRescan)
        #expect(try !draft.commit().requiresRescan)
        draft.cancel(); #expect(!draft.value.discoverPersonalFolders)
    }
    @Test func enabledDiscoversDirectNamedFolderButNeverDeepFoldersOrAutomaticSelection() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("Documents/orchard/work.txt", "fixture")
        try box.write("Documents/Unrelated/Orchard/file", "not a direct child")
        let engine = LeftoverDiscoveryService(discovery: .init(library: box.root.appendingPathComponent("Library"), home: box.root))
        #expect(engine.scan(records: [], installed: [], identityIndex: index).groups.isEmpty)
        let enabled = engine.scan(records: [], installed: [], identityIndex: index, discoverPersonalFolders: true)
        let group = try #require(enabled.groups.first)
        #expect(group.identity.name == "Orchard")
        #expect(group.candidates.count == 1)
        #expect(group.candidates.first?.classification == .possible)
        #expect(group.candidates.first?.isAutomaticSelection == false)
        #expect(group.candidates.first?.requiresExplicitSelection == true)
        try AppDataSafety.validateSelection(group.candidates)
    }
    @Test func permissionsAreReportedAndUnsafeOrAmbiguousFoldersStayProtected() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("Documents/Orchard/file", "fixture")
        let service = AppDataDiscoveryService(library: box.root.appendingPathComponent("Library"), home: box.root)
        let denied = LeftoverDiscoveryService(discovery: service, listing: PersonalDeniedListing()).scan(records: [], installed: [], identityIndex: index, discoverPersonalFolders: true)
        #expect(denied.issues.contains { $0.location == "Documents" && $0.permissionDenied })
        var ambiguous = index
        ambiguous.entries.append(.init(bundleID: "net.other.orchard", name: "Orchard", source: "Different bundle"))
        let result = LeftoverDiscoveryService(discovery: service).scan(records: [], installed: [], identityIndex: ambiguous, discoverPersonalFolders: true)
        #expect(result.groups.first?.candidates.first?.classification == .protected)
        try FileManager.default.createDirectory(at: box.root.appendingPathComponent("Downloads"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: box.root.appendingPathComponent("Downloads/Orchard").path, withDestinationPath: box.root.appendingPathComponent("Documents/Orchard").path)
        let linked = LeftoverDiscoveryService(discovery: service).scan(records: [], installed: [], identityIndex: index, discoverPersonalFolders: true)
        #expect(linked.groups.flatMap(\.candidates).contains { $0.path.contains("Downloads") && $0.classification == .protected })
    }
    @Test func nativePersonalListingStopsAtItsBound() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        for index in 0..<8 { try box.write("Documents/folder\(index)/file", "fixture") }
        #expect(try NativeAppDataDirectoryListing().boundedChildren(box.root.appendingPathComponent("Documents").path, limit: 3).count == 3)
    }
    @Test func identifierLeadCanSuggestFolderWithoutInventingNameOrOwnership() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("Library/Caches/net.fiction.meadowwriter/cache", "fixture")
        try box.write("Documents/meadow/work", "fixture")
        try box.write("Documents/cache/personal", "not a useful name association")
        let result = LeftoverDiscoveryService(discovery: .init(library: box.root.appendingPathComponent("Library"), home: box.root)).scan(records: [], installed: [], discoverPersonalFolders: true)
        let group = try #require(result.groups.first)
        #expect(group.identity.name == "net.fiction.meadowwriter")
        let personal = try #require(group.candidates.first { $0.category == "Personal Folder" })
        #expect(personal.classification == .possible && !personal.isAutomaticSelection)
        #expect(personal.explanation.contains("association is uncertain"))
        #expect(!group.candidates.contains { $0.path.hasSuffix("Documents/cache") })
    }
}
