import SwiftUI
import AppKit
import MacventoryCore

private struct InventorySettingsPresentation: Identifiable {
    let id = UUID()
    let tab: Int
}

struct InventoryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var navigation: Set<String> = ["view:all"]
    @State private var search = ""
    @State private var selected: String?
    @State private var filter = InventoryFilter()
    @State private var showFilters = false
    @State private var settingsPresentation: InventorySettingsPresentation?
    @State private var managementPresentation: ManagementPresentation?
    @State private var showDetails = true
    @State private var headerSort = [InventoryComparator()]

    private var tableSort: Binding<[InventoryComparator]> {
        Binding(get: { headerSort }, set: { proposed in
            guard let first = proposed.first else { return }
            headerSort = [InventoryComparator.headerSelection(first, after: headerSort.first)]
        })
    }
    private var activeFilter: InventoryFilter {
        var value = filter; value.search = search; value.showSystem = model.configuration.showSystem || filter.systemOnly
        return value
    }
    private var rows: [SoftwareItem] {
        let filtered = model.items.filter {
            guard activeFilter.matches($0, configuration: model.configuration) else { return false }
            return InventoryCategorySelection.matches($0, categories: navigation, configuration: model.configuration)
        }
        return InventorySort.sorted(filtered, by: headerSort.first?.key ?? .name, descending: headerSort.first?.order == .reverse)
    }
    // Separate opaque view types keep each SwiftUI builder small enough to type-check.
    // State stays in this view so navigation, selection and sheet lifetimes are unchanged.
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if navigation.contains("leftovers") {
                LeftoverDataView(onOpenScanningSettings: { settingsPresentation = .init(tab: 1) })
                    .inventoryNavigationTitle()
            } else {
                inventoryContent
                    .inventoryNavigationTitle()
                    .searchable(text: $search, prompt: "Search software, identifiers, paths…")
                    .toolbar { inventoryToolbar }
                    .sheet(item: $managementPresentation, onDismiss: { model.closeManagement() }) { presentation in
                        ManagementView(presentation: presentation, onReviewLeftovers: { managementPresentation = nil; model.closeManagement(); navigation = ["leftovers"] }).id(presentation.id)
                    }
                    .onAppear { headerSort = [InventoryComparator(InventorySortKey(rawValue: model.configuration.defaultSort) ?? .name)] }
                    .onChange(of: rows.map(\.id)) { ids in if let selected, !ids.contains(selected) { self.selected = nil } }
            }
        }
        .background(NativeControlHelp().frame(width: 0, height: 0))
        .sheet(item: $settingsPresentation) { presentation in
            SettingsView(onClose: { settingsPresentation = nil }, initialTab: presentation.tab).id(presentation.id)
                .frame(width: 760, height: SettingsView.presentationHeight)
        }
    }

    private var sidebar: some View {
        List(selection: Binding(get: { navigation }, set: { navigation = InventoryCategorySelection.normalized($0, previous: navigation) })) {
            Section("Library") { ForEach([LibraryView.all, .apps, .packages], id: \.rawValue) { libraryRow($0) } }
            Section("Smart Views") { ForEach([LibraryView.attention, .unused, .large, .recent, .unknown], id: \.rawValue) { libraryRow($0) } }
            Section("Cleanup") {
                Label("Leftover Data", systemImage: "externaldrive.badge.questionmark").tag("leftovers").pointingControl()
            }
            Section("Install Sources") {
                ForEach(visibleSources) { sourceRow($0) }
            }
        }.listStyle(.sidebar).navigationSplitViewColumnWidth(min: 220, ideal: 245)
            .accessibilityIdentifier("inventory.sidebar")
            .safeAreaInset(edge: .bottom, spacing: 0) { sidebarFooter }
    }

    private var visibleSources: [InstallSource] {
        InstallSource.allCases.filter { source in
            !model.configuration.hideAbsent || model.reports.first(where: { $0.source == source })?.state != .notInstalled
        }
    }

    private func sourceCount(_ source: InstallSource) -> Int {
        model.items.filter { item in
            (model.configuration.showSystem || !item.isSystem) &&
                (source == .unknown ? item.primarySource == .unknown : item.sources.contains { $0.source == source })
        }.count
    }

    private func sourceRow(_ source: InstallSource) -> some View {
        HStack {
            Text(source.title)
            Spacer()
            if let report = model.reports.first(where: { $0.source == source }), report.state == .failed || report.state == .unsupported {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).help(report.message)
            } else if model.reports.first(where: { $0.source == source })?.state == .scanning {
                ProgressView().controlSize(.mini)
            }
            Text("\(sourceCount(source))").foregroundStyle(.secondary).monospacedDigit()
        }.tag("source:" + source.rawValue).help("Show software associated with " + source.title).pointingControl()
    }

    private var sidebarFooter: some View {
        VStack(spacing: 10) {
            Divider()
            Text("Command-click to select multiple categories").font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 12)
            HStack(spacing: 18) {
                Button { settingsPresentation = .init(tab: 0) } label: { Label("Settings", systemImage: "gearshape") }.accessibilityIdentifier("inventory.settings").controlHelp("Show Settings")
                Button { showAbout(appearance: model.configuration.appearance) } label: { Label("About", systemImage: "info.circle") }.accessibilityIdentifier("inventory.about").controlHelp("About Macventory")
                Spacer(minLength: 0)
            }.buttonStyle(.plain).padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 18)
        }.background(.bar)
    }

    private var inventoryContent: some View {
        VStack(spacing: 0) {
            if model.demoMode { Text("Demo inventory · fictional software · removal disabled").font(.caption).foregroundStyle(.secondary).padding(8) }
            else if model.qaProtected { Label("QA protection: uninstall operations are simulated", systemImage: "shield.checkered").font(.caption).padding(8) }
            if showFilters { FilterView(filter: $filter).padding().background(.bar) }
            if let error = model.error { HStack { Image(systemName: "exclamationmark.triangle"); Text(error); Spacer(); Button("Dismiss") { model.error = nil }.controlHelp("Dismiss this error message") }.padding(10).background(.orange.opacity(0.1)) }
            inventorySplitView
            Divider()
            statusBar
        }
    }

    private var inventorySplitView: some View {
        GeometryReader { geometry in
            if showDetails, let item = model.items.first(where: { $0.id == selected }) {
                if geometry.size.width >= 960 {
                    HSplitView {
                        table.frame(minWidth: 640)
                        details(item).frame(minWidth: 270, idealWidth: 300, maxWidth: 380)
                    }
                } else {
                    // A native bottom pane preserves table width and sidebar access on
                    // compact displays, rather than expanding the entire split view.
                    VSplitView {
                        table.frame(minHeight: 150)
                        details(item, compact: true).frame(minHeight: 150, idealHeight: 210, maxHeight: 260)
                    }
                }
            } else {
                table
            }
        }
    }

    private func details(_ item: SoftwareItem, compact: Bool = false) -> some View {
        DetailsView(onUninstall: { reviewUninstall(item) }, item: item, unusedDays: model.configuration.unusedDays, compact: compact)
            .id(item.id)
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if model.scanning { ProgressView().controlSize(.small) }
            Text(model.progress).lineLimit(1)
            if navigation.count > 1 { Text("\(navigation.count) categories · matching any").help("Results combine the selected sidebar categories, then apply search and filters.") }
            Spacer()
            Text("\(rows.count) shown of \(model.items.count)").monospacedDigit()
                .help("Sidebar counts exclude hidden system software. Shown also reflects the selected category, search and filters.")
            if !model.configuration.showSystem, model.items.contains(where: \.isSystem) { Text("System apps hidden").help("Enable Show system applications in Settings to include them.") }
            if model.items.contains(where: \.stale) { Label("Cached / Stale", systemImage: "clock").help("Some observations have not been successfully refreshed") }
        }.font(.caption).foregroundStyle(.secondary).padding(10)
    }

    @ToolbarContentBuilder
    private var inventoryToolbar: some ToolbarContent {
        if #available(macOS 26, *) {
            ToolbarItem(placement: .navigation) { BrandHeader().background(NativeControlHelp().frame(width: 0, height: 0)) }.sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigation) { BrandHeader().background(NativeControlHelp().frame(width: 0, height: 0)) }
        }
        ToolbarItemGroup {
            Button { showFilters.toggle() } label: { Label("Filters", systemImage: "line.3.horizontal.decrease.circle") }.accessibilityIdentifier("inventory.filters").controlHelp("Filter Software").accessibilityLabel("Filter Software")
            Button { showDetails.toggle() } label: { Label("Details", systemImage: "sidebar.right") }.accessibilityIdentifier("inventory.toggleDetails").controlHelp(showDetails ? "Hide Details" : "Show Details").accessibilityLabel(showDetails ? "Hide Details" : "Show Details")
            if model.scanning { Button("Cancel") { model.cancel() }.accessibilityIdentifier("inventory.cancel").controlHelp("Cancel Scan") }
            else { Button { model.refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }.accessibilityIdentifier("inventory.refresh").controlHelp("Refresh Inventory").accessibilityLabel("Refresh Inventory") }
        }
    }

    private func reviewUninstall(_ item: SoftwareItem) {
        manage(item)
    }
    private func manage(_ item: SoftwareItem, forceQuit: Bool = false) {
        guard !model.scanning, !model.managementWorking, model.managementItem == nil, managementPresentation == nil else { return }
        model.prepareManagement(item)
        managementPresentation = ManagementPresentation(item: item, forceQuit: forceQuit)
    }
    private var table: some View {
        Group {
            if #available(macOS 14, *) { CustomizableInventoryTable(rows: rows, selection: $selected, sortOrder: tableSort) }
            else { legacyTable }
        }
        .onAppear { model.noteWindowAppearance() }

        .overlay {
            if rows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up").font(.largeTitle).foregroundStyle(.secondary)
                    Text(model.scanning ? "Discovering software…" : "No matching software").font(.headline)
                    Text("Refresh the inventory or adjust search and filters.").foregroundStyle(.secondary)
                }.padding(30).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if ids.count == 1, let id = ids.first, let item = rows.first(where: { $0.id == id }) {
                Button("Copy Identifier") { Display.copy(item.bundleID ?? item.packageID ?? item.id) }.controlHelp("Copy Software Identifier")
                if let path = item.path { Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }.controlHelp("Reveal in Finder"); Button("Copy Path") { Display.copy(path) }.controlHelp("Copy Installation Path") }
                if model.runningTarget(for: item) != nil {
                    Button("Force Quit") { selected = id; manage(item, forceQuit: true) }.disabled(model.scanning || model.managementWorking).controlHelp("Review the unsaved-work warning and exact running process before Force Quit")
                }
                Button("Uninstall…") { selected = id; manage(item) }.disabled(model.scanning || model.managementWorking).controlHelp("Review Force Quit, Clear App Data and source-aware Uninstall in one dialog")
            }
        } primaryAction: { ids in
            guard ids.count == 1, let id = ids.first, let item = rows.first(where: { $0.id == id }) else { return }
            selected = id
            reviewUninstall(item)
        }

    }
    private var legacyTable: some View {
        Table(rows, selection: $selected, sortOrder: tableSort) {
            TableColumn("Name", sortUsing: InventoryComparator(.name)) { item in
                HStack(spacing: 9) {
                    AppIcon(path: item.path, demoSymbol: item.attributes["Demo symbol"])
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).lineLimit(1).help(item.name)
                        if item.stale { Text("Cached / Stale").font(.caption2).foregroundStyle(.secondary) }
                    }
                }.padding(.vertical, 3).pointingControl()
            }.width(min: 160, ideal: 220)
            TableColumn("Status", sortUsing: InventoryComparator(.health)) { InstallationHealthBadge(item: $0).frame(maxWidth: .infinity) }.width(min: 52, ideal: 58)
            TableColumn("Version", sortUsing: InventoryComparator(.version)) { Text($0.version ?? "Not Available").help($0.version ?? "Version Not Available").foregroundStyle($0.version == nil ? .secondary : .primary).lineLimit(1) }.width(min: 75, ideal: 100)
            TableColumn("Source", sortUsing: InventoryComparator(.source)) { Text($0.primarySource.title).lineLimit(1).help($0.primarySource.title) }.width(min: 120, ideal: 165)
            TableColumn("Size", sortUsing: InventoryComparator(.size)) { Text(Display.size($0)).monospacedDigit().help($0.sizeMetric) }.width(min: 85, ideal: 100)
            TableColumn("Installed", sortUsing: InventoryComparator(.installed)) { Text(Display.date($0.installedAt, item: $0, field: "installedAt")).help($0.installedAt?.formatted(date: .complete, time: .standard) ?? "Not Available") }.width(min: 100, ideal: 115)
            TableColumn("Last Opened", sortUsing: InventoryComparator(.opened)) { Text(Display.date($0.lastOpenedAt, item: $0, field: "lastOpenedAt")).help($0.lastOpenedAt?.formatted(date: .complete, time: .standard) ?? "Not Available") }.width(min: 100, ideal: 115)
        }
        .accessibilityIdentifier("inventory.table").accessibilityHint("Select a row for details. Double-click or press Return to review uninstall eligibility; this never starts removal.")
    }
    private func libraryRow(_ view: LibraryView) -> some View {
        HStack { Text(view.rawValue); Spacer(); Text("\(model.items.filter { item in var filter = InventoryFilter(); filter.view = view; filter.showSystem = model.configuration.showSystem; return filter.matches(item, configuration: model.configuration) }.count)").foregroundStyle(.secondary).monospacedDigit() }.tag("view:" + view.id).help("Show " + view.rawValue).pointingControl()
    }
}

extension LibraryView { var id: String { switch self { case .attention: "attention"; case .all: "all"; case .apps: "apps"; case .packages: "packages"; case .unused: "unused"; case .large: "large"; case .recent: "recent"; case .unknown: "unknown" } } }

struct AppIcon: View {
    let path: String?
    var demoSymbol: String? = nil
    @State private var icon: NSImage?
    var body: some View {
        Group {
            if let demoSymbol { Image(systemName: demoSymbol).resizable().scaledToFit().foregroundStyle(.blue).padding(4) }
            else if let icon { Image(nsImage: icon).resizable().scaledToFit() }
            else { Image(systemName: "shippingbox").resizable().scaledToFit().foregroundStyle(.secondary).padding(4) }
        }.frame(width: 28, height: 28).accessibilityHidden(true)
            .task(id: path) {
                icon = nil
                guard demoSymbol == nil, let path, path.hasSuffix(".app"), FileSystem.exists(path) else { return }
                icon = ApplicationIconCache.shared.icon(for: path)
            }
    }
}

@MainActor
private final class ApplicationIconCache {
    static let shared = ApplicationIconCache()
    private let images = NSCache<NSString, NSImage>()
    func icon(for path: String) -> NSImage {
        let modified = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let key = (FileSystem.canonical(path) + "|\(modified)") as NSString
        if let cached = images.object(forKey: key) { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 64, height: 64)
        images.setObject(image, forKey: key)
        return image
    }
}

struct FilterView: View {
    @Binding var filter: InventoryFilter
    @State private var sizeMB = ""
    @State private var installedRange = false
    @State private var openedRange = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Source", selection: $filter.source) { Text("Any").tag(nil as InstallSource?); ForEach(InstallSource.allCases) { Text($0.title).tag(Optional($0)) } }.controlHelp("Filter by installation source")
                Picker("Kind", selection: $filter.kind) { Text("Any").tag(nil as SoftwareKind?); ForEach(SoftwareKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) } }.controlHelp("Filter applications, games or packages")
                Picker("Confidence", selection: $filter.confidence) { Text("Any").tag(nil as Confidence?); ForEach(Confidence.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) } }.controlHelp("Filter by metadata confidence")
            }
            Picker("Installation Status", selection: $filter.healthStatus) { Text("Any").tag(nil as InstallationStatus?); ForEach(InstallationStatus.allCases, id: \.self) { Text($0.title).tag(Optional($0)) } }.controlHelp("Filter by verified installation health")
            HStack {
                TextField("Minimum MB", text: $sizeMB).frame(width: 140).onChange(of: sizeMB) { filter.minimumSize = Int64($0).flatMap { $0 >= 0 && $0 <= Int64.max / 1_000_000 ? $0 * 1_000_000 : nil } }.controlHelp("Minimum logical size in megabytes")
                Toggle("Missing metadata", isOn: $filter.missingOnly).controlHelp("Show only software with missing metadata")
                Toggle("System only", isOn: $filter.systemOnly).controlHelp("Show only system software")
                Spacer()
                Button("Reset") { filter = InventoryFilter(); sizeMB = ""; installedRange = false; openedRange = false }.controlHelp("Reset all inventory filters")
            }
            HStack {
                Toggle("Installed range", isOn: $installedRange).onChange(of: installedRange) { enabled in filter.installedAfter = enabled ? Date().addingTimeInterval(-30 * 86400) : nil; filter.installedBefore = enabled ? Date() : nil }.controlHelp("Installed range")
                if installedRange {
                    DatePicker("From", selection: Binding(get: { filter.installedAfter ?? Date() }, set: { filter.installedAfter = $0 }), displayedComponents: .date).controlHelp("Start date for the selected filter range")
                    DatePicker("To", selection: Binding(get: { filter.installedBefore ?? Date() }, set: { filter.installedBefore = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: $0))?.addingTimeInterval(-0.001) }), displayedComponents: .date).controlHelp("End date for the selected filter range")
                }
            }
            HStack {
                Toggle("Last-opened range", isOn: $openedRange).onChange(of: openedRange) { enabled in filter.openedAfter = enabled ? Date().addingTimeInterval(-365 * 86400) : nil; filter.openedBefore = enabled ? Date() : nil }.controlHelp("Last-opened range")
                if openedRange {
                    DatePicker("From", selection: Binding(get: { filter.openedAfter ?? Date() }, set: { filter.openedAfter = $0 }), displayedComponents: .date).controlHelp("Start date for the selected filter range")
                    DatePicker("To", selection: Binding(get: { filter.openedBefore ?? Date() }, set: { filter.openedBefore = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: $0))?.addingTimeInterval(-0.001) }), displayedComponents: .date).controlHelp("End date for the selected filter range")
                }
            }
        }.controlSize(.small)
    }
}
