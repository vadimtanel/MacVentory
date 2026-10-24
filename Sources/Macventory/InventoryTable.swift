import SwiftUI
import MacventoryCore

@available(macOS 14, *)
struct CustomizableInventoryTable: View {
    @EnvironmentObject private var model: AppModel
    @State private var isolatedCustomization = TableColumnCustomization<SoftwareItem>()
    private var currentCustomization: Binding<TableColumnCustomization<SoftwareItem>> { model.fixtureMode ? $isolatedCustomization : $customization }
    let rows: [SoftwareItem]
    @Binding var selection: String?
    @Binding var sortOrder: [InventoryComparator]
    @SceneStorage("Macventory.inventory.columns") private var customization: TableColumnCustomization<SoftwareItem>
    @State private var showColumns = false
    @State private var tableRevision = 0
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Columns") { showColumns.toggle() }.accessibilityIdentifier("inventory.columns").controlHelp("Choose visible inventory columns")
                    .popover(isPresented: $showColumns) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Show Columns").font(.headline)
                            Toggle("Status", isOn: visibility("health")).controlHelp("Show or hide installation status")
                            Toggle("Version", isOn: visibility("version")).controlHelp("Show or hide the Version column")
                            Toggle("Source", isOn: visibility("source")).controlHelp("Show or hide the Source column")
                            Toggle("Size", isOn: visibility("size")).controlHelp("Show or hide the Size column")
                            Toggle("Installed", isOn: visibility("installed")).controlHelp("Show or hide the Installed column")
                            Toggle("Last Opened", isOn: visibility("opened")).controlHelp("Show or hide the Last Opened column")
                            Text("Drag table headers to change their order. Name stays visible.").font(.caption).foregroundStyle(.secondary)
                            Button("Reset Columns") { currentCustomization.wrappedValue = TableColumnCustomization(); tableRevision += 1 }.controlHelp("Restore default column visibility, width and order")
                        }.padding(18).frame(width: 250)
                    }
            }.padding(.horizontal, 10).padding(.vertical, 4)
            Table(rows, selection: $selection, sortOrder: $sortOrder, columnCustomization: currentCustomization) {
                TableColumn("Name", sortUsing: InventoryComparator(.name)) { item in HStack(spacing: 9) { AppIcon(path: item.path, demoSymbol: item.attributes["Demo symbol"]); Text(item.name).lineLimit(1).help(item.name); if item.stale { Image(systemName: "clock").help("Cached / Stale") } }.padding(.vertical, 3).pointingControl() }.width(min: 160, ideal: 220)
                TableColumn("Status", sortUsing: InventoryComparator(.health)) { InstallationHealthBadge(item: $0).frame(maxWidth: .infinity) }.width(min: 52, ideal: 58).customizationID("health")
                TableColumn("Version", sortUsing: InventoryComparator(.version)) { Text($0.version ?? "Not Available").lineLimit(1).help($0.version ?? "Version Not Available") }.width(min: 75, ideal: 100).customizationID("version")
                TableColumn("Source", sortUsing: InventoryComparator(.source)) { Text($0.primarySource.title).lineLimit(1).help($0.primarySource.title) }.width(min: 120, ideal: 165).customizationID("source")
                TableColumn("Size", sortUsing: InventoryComparator(.size)) { Text(Display.size($0)).monospacedDigit().help($0.sizeMetric) }.width(min: 85, ideal: 100).customizationID("size")
                TableColumn("Installed", sortUsing: InventoryComparator(.installed)) { Text(Display.date($0.installedAt, item: $0, field: "installedAt")).help($0.installedAt?.formatted(date: .complete, time: .standard) ?? "Not Available") }.width(min: 100, ideal: 115).customizationID("installed")
                TableColumn("Last Opened", sortUsing: InventoryComparator(.opened)) { Text(Display.date($0.lastOpenedAt, item: $0, field: "lastOpenedAt")).help($0.lastOpenedAt?.formatted(date: .complete, time: .standard) ?? "Not Available") }.width(min: 100, ideal: 115).customizationID("opened")
            // Recreate the native table after programmatic visibility changes: the macOS 27
            // runtime otherwise keeps the previous visible columns despite updated customization.
            }.id(tableRevision).accessibilityIdentifier("inventory.table").accessibilityHint("Select a row for details. Double-click or press Return to review uninstall eligibility; this never starts removal.")
        }
    }
    private func visibility(_ id: String) -> Binding<Bool> {
        Binding(get: { currentCustomization.wrappedValue[visibility: id] != .hidden }, set: { currentCustomization.wrappedValue[visibility: id] = $0 ? .visible : .hidden; tableRevision += 1 })
    }
}
