import Foundation
import AppKit
import Testing
@testable import MacventoryCore

@Suite("Settings input and public links")
struct SettingsInputTests {
    @Test @MainActor func officialBrandResourcesRemainDecodable() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: root.appendingPathComponent("Resources/Info.plist")), format: nil) as! [String: Any]
        #expect(info["CFBundleIconFile"] as? String == "Macventory.icns")
        let icon = try #require(NSImage(contentsOf: root.appendingPathComponent("Resources/Macventory.icns")))
        #expect(icon.isValid && !icon.representations.isEmpty)
        let toolbar = try #require(NSImage(contentsOf: root.appendingPathComponent("Resources/ToolbarMark.png")))
        #expect(toolbar.isValid && toolbar.size.width > 0)
    }
    @Test func typedDaysStayWithinSmartViewBounds() {
        #expect(SettingsInput.days(28, within: 1...365) == 28)
        #expect(SettingsInput.days(0, within: 1...365) == 1)
        #expect(SettingsInput.days(Int.max, within: 1...365) == 365)
        #expect(SettingsInput.days(Int.min, within: 1...3650) == 1)
        #expect(SettingsInput.days(180, within: 1...3650) == 180)
    }
    @Test func pathListsTrimWithoutInventingLocations() {
        #expect(SettingsInput.paths(" /Applications \n\n ~/Applications \n", separator: "\n") == ["/Applications", "~/Applications"])
        #expect(SettingsInput.paths(" /opt/homebrew, , /usr/local,", separator: ",") == ["/opt/homebrew", "/usr/local"])
        #expect(SettingsInput.paths("", separator: ",").isEmpty)
    }
    @Test func linksAreExactOwnerSuppliedProfiles() {
        #expect(AppLinks.linkedIn.absoluteString == "https://www.linkedin.com/in/vadim-tanel/")
        #expect(AppLinks.githubProfile.absoluteString == "https://github.com/vadimtanel/")
        #expect(AppLinks.projectRepository.absoluteString == "https://github.com/vadimtanel/MacVentory")
    }
}
