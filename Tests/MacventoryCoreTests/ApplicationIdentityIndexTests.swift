import Foundation
import Testing
@testable import MacventoryCore

@Suite("Local application identity history independent of cleanup")
struct ApplicationIdentityIndexTests {
    private func identity(_ id: String) -> ApplicationIdentity { .init(name: id, bundleID: id, evidence: "Exact identifier found in Caches", installed: false) }

    @Test func removedOutsideMacventoryRetainsNameWithoutChangingCandidates() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("Library/Caches/net.fiction.orchard/cache", "fixture")
        try box.write("Library/Preferences/net.fiction.orchard.plist", "fixture")
        let engine = LeftoverDiscoveryService(discovery: .init(library: box.root.appendingPathComponent("Library"), home: box.root))
        let index = ApplicationIdentityIndex(entries: [.init(bundleID: "net.fiction.orchard", name: "Orchard Notes", source: "Previously observed bundle Info.plist")])
        let before = engine.scan(records: [], installed: [])
        let after = engine.scan(records: [], installed: [], identityIndex: index)
        #expect(after.groups.first?.identity.name == "Orchard Notes")
        #expect(before.groups.first?.candidates == after.groups.first?.candidates)
        #expect(after.groups.first?.candidates.allSatisfy { $0.classification == .possible && !$0.isAutomaticSelection } == true)
        var app = SoftwareItem(name: "Orchard Notes"); app.bundleID = "net.fiction.orchard"
        #expect(engine.scan(records: [], installed: [app], identityIndex: index).groups.isEmpty)
    }
    @Test func removalHistoryNamesAndBeforeInstallFallbackRemainDistinct() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("Library/Caches/net.fiction.harbor/cache", "fixture")
        let engine = LeftoverDiscoveryService(discovery: .init(library: box.root.appendingPathComponent("Library"), home: box.root))
        let known = engine.scan(records: [.init(name: "Harbor Editor", bundleID: "net.fiction.harbor", ownershipEvidence: "Synthetic removal")], installed: [])
        #expect(known.groups.first?.identity.name == "Harbor Editor")
        let unknown = engine.scan(records: [], installed: [])
        #expect(LeftoverPresentationGroup.make(from: unknown.groups, mode: .application).first?.name == "net.fiction.harbor")
    }
    @Test func sameNamesAndVendorPrefixesNeverEstablishParentage() {
        let entries: [ObservedApplicationIdentity] = [
            .init(bundleID: "net.fiction.harbor", name: "Studio", vendor: "Fiction", source: "Bundle"),
            .init(bundleID: "net.fiction.harbor.other", name: "Studio", vendor: "Fiction", source: "Bundle")
        ]
        let index = ApplicationIdentityIndex(entries: entries)
        #expect(index.resolve(identity(entries[1].bundleID)).parentBundleID == nil)
        let groups = entries.map { entry in
            AppDataDiscoveryResult(identity: index.resolve(identity(entry.bundleID)), candidates: [.init(path: "/synthetic/" + entry.bundleID, category: "Caches", classification: .possible, explanation: "Synthetic", sizeBytes: 1, sizeComplete: true, requiresExplicitSelection: true, allowedRoot: "/synthetic", identity: nil)])
        }
        #expect(LeftoverPresentationGroup.make(from: groups, mode: .application).count == 2)
    }
    @Test func embeddedExtensionEstablishesRelationshipAndIndexRoundTrips() async throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        let path = box.root.appendingPathComponent("Aurora.app").path
        try box.write("Aurora.app/Contents/Info.plist", "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>net.fiction.aurora</string><key>CFBundleName</key><string>Aurora</string></dict></plist>")
        try box.write("Aurora.app/Contents/PlugIns/Share.appex/Contents/Info.plist", "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>net.fiction.share</string><key>CFBundleName</key><string>Share</string></dict></plist>")
        let observations = ApplicationIdentityIndex.observations(items: [try NativeScanner.item(at: path)])
        var index = ApplicationIdentityIndex(); index.observe(observations)
        let store = ApplicationIdentityStore(directory: box.root)
        try await store.save(index)
        let loaded = try await store.load()
        let child = loaded.resolve(identity("net.fiction.share"))
        #expect(child.parentBundleID == "net.fiction.aurora")
        #expect(child.parentApplicationName == "Aurora")
        #expect(loaded.resolve(identity("net.fiction.aurora")).name == "Aurora")
    }
    @Test func renamedConflictingExpiredAndFutureMetadataAreConservative() {
        let now = Date(), id = "net.fiction.canvas"
        var index = ApplicationIdentityIndex(entries: [
            .init(bundleID: id, name: "Old Canvas", source: "Bundle", lastObserved: now.addingTimeInterval(-86400)),
            .init(bundleID: id, name: "Canvas", source: "Bundle", lastObserved: now)
        ])
        #expect(index.resolve(identity(id)).name == "Canvas")
        index.entries.append(.init(bundleID: id, name: "Conflict", source: "Bundle", lastObserved: now))
        #expect(index.resolve(identity(id)).name == id)
        index = .init(entries: [.init(bundleID: id, name: "Expired", source: "Bundle", lastObserved: now.addingTimeInterval(-731 * 86400))])
        #expect(index.resolve(identity(id)).name == id)
        index.observe([.init(bundleID: id, name: "Future", source: "Bundle", lastObserved: now.addingTimeInterval(86400))])
        #expect(index.entries.isEmpty)
    }
    @Test func qaBundleWithoutArgumentsFailsClosed() {
        #expect(InventoryRunMode(arguments: [], qaBundle: true).isolated)
        #expect(!InventoryRunMode(arguments: [], qaBundle: true).allowsLiveRemoval)
    }
    @Test func exactManifestSuppliesNameWithoutChangingOwnership() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("Library/Application Support/Workspace/package.json", "{\"build\":{\"appId\":\"net.fiction.workspace\",\"productName\":\"Cedar Workspace\"}}")
        let result = LeftoverDiscoveryService(discovery: .init(library: box.root.appendingPathComponent("Library"), home: box.root)).scan(records: [], installed: [])
        #expect(result.groups.first?.identity.name == "Cedar Workspace")
        #expect(result.groups.first?.candidates.allSatisfy { $0.classification == .possible && !$0.isAutomaticSelection } == true)
    }
    @Test func reinstalledParentExcludesItsRecordedExtension() throws {
        let box = try Sandbox.removal(); defer { box.clean() }
        try box.write("Library/Caches/net.fiction.share/cache", "fixture")
        let index = ApplicationIdentityIndex(entries: [
            .init(bundleID: "net.fiction.aurora", name: "Aurora", source: "Bundle"),
            .init(bundleID: "net.fiction.share", name: "Share", parentBundleID: "net.fiction.aurora", source: "Embedded extension")
        ])
        let engine = LeftoverDiscoveryService(discovery: .init(library: box.root.appendingPathComponent("Library"), home: box.root))
        var installed = SoftwareItem(name: "Aurora"); installed.bundleID = "net.fiction.aurora"
        #expect(engine.scan(records: [], installed: [installed], identityIndex: index).groups.isEmpty)
        #expect(engine.scan(records: [], installed: [], identityIndex: index, registeredApplication: { $0 == "net.fiction.aurora" }).groups.isEmpty)
    }
}
