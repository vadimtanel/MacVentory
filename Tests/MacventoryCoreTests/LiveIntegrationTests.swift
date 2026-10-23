import Foundation
import Testing
@testable import MacventoryCore

@Suite("Opt-in real-machine integration", .enabled(if: ProcessInfo.processInfo.environment["MACVENTORY_LIVE_TESTS"] == "1"))
struct LiveIntegrationTests {
    @Test func nativePayloadsAndVersionsExist() async throws {
        let result = try await NativeScanner().scan()
        #expect(result.report.state != .failed)
        for item in result.items {
            let path = try #require(item.path)
            #expect(FileSystem.exists(path + "/Contents/Info.plist"))
            #expect(item.installedAt == nil)
            let bundle = Bundle(path: path)
            let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            #expect(item.version == version)
        }
    }
    @Test func homebrewKegsAndCaskOwnership() async throws {
        let formulae = try await HomebrewScanner(source: .homebrewFormula).scan()
        for item in formulae.items {
            let path = try #require(item.path)
            #expect(FileSystem.exists(path + "/INSTALL_RECEIPT.json"))
            #expect(item.version == URL(fileURLWithPath: path).lastPathComponent)
        }
        let casks = try await HomebrewScanner(source: .homebrewCask).scan()
        let native = try await NativeScanner().scan()
        let merged = InventoryMerger.merge(native.items + casks.items)
        for item in casks.items where item.path != nil {
            let matches = merged.filter { $0.path == item.path }
            #expect(matches.count == 1)
            #expect(matches.first?.primarySource == .homebrewCask)
        }
    }
    @Test func repeatedFullScanIsIdempotent() async {
        let service = InventoryService(), configuration = ScanConfiguration()
        let first = await service.scan(configuration: configuration, previous: nil, measureSizes: false) { _ in }
        let second = await service.scan(configuration: configuration, previous: first, measureSizes: false) { _ in }
        #expect(Set(first.items.map(\.id)) == Set(second.items.map(\.id)))
        #expect(second.items.count == Set(second.items.map(\.id)).count)
        #expect(!second.reports.contains { $0.state == .failed })
    }
}
