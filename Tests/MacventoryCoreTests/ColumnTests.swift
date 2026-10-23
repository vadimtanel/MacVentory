import Foundation
import SwiftUI
import Testing
import MacventoryCore

@Suite("Native column persistence")
struct ColumnTests {
    @Test func visibilitySurvivesRoundTripAndOrderReset() throws {
        if #available(macOS 14, *) {
            var columns = TableColumnCustomization<SoftwareItem>()
            columns[visibility: "version"] = .hidden
            columns[visibility: "size"] = .visible
            let restored = try JSONDecoder().decode(TableColumnCustomization<SoftwareItem>.self, from: JSONEncoder().encode(columns))
            #expect(restored[visibility: "version"] == .hidden)
            #expect(restored[visibility: "size"] == .visible)
            columns.resetOrder()
            #expect(columns[visibility: "version"] == .hidden)
        }
    }
}
