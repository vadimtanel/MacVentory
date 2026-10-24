// A standalone synthetic diagnostic, not part of the application or a replacement
// for XCUITest. Compile with the app sources (excluding MacventoryApp.swift).
import SwiftUI
import AppKit
import MacventoryCore

private struct ProbeRow: Identifiable {
    let id: String
    let name: String
    let version: String
    let source: String
    let size: String
    let installed: String
    let opened: String
}
private struct ProbeComparator: SortComparator {
    var key: String
    var order: SortOrder = .forward
    func compare(_ lhs: ProbeRow, _ rhs: ProbeRow) -> ComparisonResult {
        let path: KeyPath<ProbeRow, String>
        switch key {
        case "version": path = \.version
        case "source": path = \.source
        case "size": path = \.size
        case "installed": path = \.installed
        case "opened": path = \.opened
        default: path = \.name
        }
        let result = lhs[keyPath: path].localizedStandardCompare(rhs[keyPath: path])
        return order == .forward || result == .orderedSame ? result : result == .orderedAscending ? .orderedDescending : .orderedAscending
    }
}
@MainActor private final class ProbeState: ObservableObject {
    @Published var selection: String?
    @Published var standardSort = [KeyPathComparator(\ProbeRow.name)]
    @Published var customSort = [ProbeComparator(key: "name")]
    let rows = [
        ProbeRow(id: "example", name: "Example App", version: "1.2.3", source: "Direct / Unmanaged", size: "2 GB", installed: "Unknown", opened: "April"),
        ProbeRow(id: "tool", name: "example-tool", version: "1.0", source: "Homebrew Formulae", size: "Unknown", installed: "Unknown", opened: "Unknown")
    ]
    var normalizedSort: Binding<[ProbeComparator]> {
        Binding(get: { self.customSort }, set: { proposed in
            guard var first = proposed.first else { return }
            if first.key != self.customSort.first?.key { first.order = .forward }
            self.customSort = [first]
        })
    }
}
private struct ProbeTable: View {
    @ObservedObject var state: ProbeState
    let mode: String
    @State private var customization = TableColumnCustomization<ProbeRow>()
    var body: some View {
        if mode == "keypath" { keypath }
        else if mode == "customized" { customized }
        else { basic }
    }
    private var keypath: some View {
        Table(state.rows.sorted(using: state.standardSort), selection: $state.selection, sortOrder: $state.standardSort) {
            TableColumn("Name", value: \.name).width(min: 160, ideal: 220)
            TableColumn("Version", value: \.version).width(min: 75, ideal: 100)
            TableColumn("Source", value: \.source).width(min: 120, ideal: 165)
            TableColumn("Size", value: \.size).width(min: 85, ideal: 100)
            TableColumn("Installed", value: \.installed).width(min: 100, ideal: 115)
            TableColumn("Last Opened", value: \.opened).width(min: 100, ideal: 115)
        }
    }
    private var basic: some View {
        Table(state.rows.sorted(using: state.customSort), selection: $state.selection, sortOrder: state.normalizedSort) {
            TableColumn("Name", sortUsing: ProbeComparator(key: "name")) { Text($0.name) }.width(min: 160, ideal: 220)
            TableColumn("Version", sortUsing: ProbeComparator(key: "version")) { Text($0.version) }.width(min: 75, ideal: 100)
            TableColumn("Source", sortUsing: ProbeComparator(key: "source")) { Text($0.source) }.width(min: 120, ideal: 165)
            TableColumn("Size", sortUsing: ProbeComparator(key: "size")) { Text($0.size) }.width(min: 85, ideal: 100)
            TableColumn("Installed", sortUsing: ProbeComparator(key: "installed")) { Text($0.installed) }.width(min: 100, ideal: 115)
            TableColumn("Last Opened", sortUsing: ProbeComparator(key: "opened")) { Text($0.opened) }.width(min: 100, ideal: 115)
        }
    }
    private var customized: some View {
        Table(state.rows.sorted(using: state.customSort), selection: $state.selection, sortOrder: state.normalizedSort, columnCustomization: $customization) {
            TableColumn("Name", sortUsing: ProbeComparator(key: "name")) { Text($0.name) }.width(min: 160, ideal: 220)
            TableColumn("Version", sortUsing: ProbeComparator(key: "version")) { Text($0.version) }.width(min: 75, ideal: 100).customizationID("version")
            TableColumn("Source", sortUsing: ProbeComparator(key: "source")) { Text($0.source) }.width(min: 120, ideal: 165).customizationID("source")
            TableColumn("Size", sortUsing: ProbeComparator(key: "size")) { Text($0.size) }.width(min: 85, ideal: 100).customizationID("size")
            TableColumn("Installed", sortUsing: ProbeComparator(key: "installed")) { Text($0.installed) }.width(min: 100, ideal: 115).customizationID("installed")
            TableColumn("Last Opened", sortUsing: ProbeComparator(key: "opened")) { Text($0.opened) }.width(min: 100, ideal: 115).customizationID("opened")
        }.accessibilityIdentifier("inventory.table").accessibilityHint("Select a row for details")
            .overlay { if state.rows.isEmpty { Text("No matching software") } }
            .contextMenu(forSelectionType: String.self) { _ in Button("Synthetic action") {} } primaryAction: { _ in }
    }
}
@MainActor private func findTable(_ view: NSView) -> NSTableView? {
    if let table = view as? NSTableView, table.numberOfColumns == 6 { return table }
    return view.subviews.lazy.compactMap(findTable).first
}
@main private struct HeaderProxyProbe {
    @MainActor static func main() {
        // A separate process with explicit fixture arguments; never launch normal mode.
        guard CommandLine.arguments.contains("--ui-testing"), let mode = CommandLine.arguments.first(where: { $0.hasPrefix("--case=") })?.dropFirst(7),
              ["keypath", "custom", "customized", "inventory"].contains(String(mode)) else { exit(2) }
        setbuf(stdout, nil)
        let modeName = String(mode)
        let app = NSApplication.shared
        let state = ProbeState()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 100, width: 1024, height: 620), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Synthetic header diagnostic — " + modeName
        if modeName == "inventory" {
            let model = AppModel() // --ui-testing selects synthetic inventory/executor.
            window.contentView = NSHostingView(rootView: InventoryView().environmentObject(model))
        } else {
            window.contentView = NSHostingView(rootView: ProbeTable(state: state, mode: modeName))
        }
        window.makeKeyAndOrderFront(nil)
        print("case=\(modeName) OS=\(ProcessInfo.processInfo.operatingSystemVersionString)")
        func schedule(_ phase: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { runPhase(phase) }
        }
        @MainActor func runPhase(_ phase: Int) {
            guard let content = window.contentView, let table = findTable(content), let header = table.headerView else { print("ERROR no six-column native table"); exit(3) }
            let phaseNames = ["before selection", "after selection", "Version ascending", "Version descending", "Source ascending", "Source descending"]
            print("PHASE \(phaseNames[phase]) selectedRow=\(table.selectedRow) selection=\(String(describing: state.selection)) customSort=\(state.customSort) nativeSort=\(table.sortDescriptors)")
            let children = header.accessibilityChildren() ?? []
            guard children.count == 6 else { print("ERROR missing native header proxies"); exit(4) }
            for index in 0..<6 {
                let proxy = children[index] as! NSObject
                let rect = header.headerRect(ofColumn: index)
                let point = window.convertPoint(toScreen: header.convert(NSPoint(x: rect.midX, y: rect.midY), to: nil))
                // Observe the native hit-test result; never synthesize a coordinate click.
                let hit = window.accessibilityHitTest(point) as? NSObject
                let windowPoint = window.convertPoint(fromScreen: point)
                let parentPoint = content.superview?.convert(windowPoint, from: nil) ?? windowPoint
                let viewHit = content.hitTest(parentPoint)
                let headerParentPoint = header.superview?.convert(windowPoint, from: nil) ?? windowPoint
                let headerViewHit = header.hitTest(headerParentPoint)
                let activation = NSAccessibility.Attribute(rawValue: "AXActivationPoint")
                let activationValue = proxy.accessibilityAttributeNames().contains(activation)
                    ? String(describing: proxy.accessibilityAttributeValue(activation)) : "not exposed"
                let data: [String: Any] = [
                    "column": table.tableColumns[index].title, "headerRect": NSStringFromRect(rect),
                    "phase": phaseNames[phase], "selectedRow": table.selectedRow,
                    "windowFrame": NSStringFromRect(window.frame),
                    "AXPosition": String(describing: proxy.accessibilityAttributeValue(.position)),
                    "AXSize": String(describing: proxy.accessibilityAttributeValue(.size)),
                    "AXActivationPoint": activationValue,
                    "AXActions": proxy.accessibilityActionNames().map(\.rawValue),
                    "AXEnabled": String(describing: proxy.accessibilityAttributeValue(.enabled)),
                    "AXSortDirection": String(describing: proxy.accessibilityAttributeValue(.sortDirection)),
                    "AXHitTitle": String(describing: hit?.accessibilityAttributeValue(.title)),
                    "AXHitClass": String(describing: hit.map { type(of: $0) }),
                    "viewHitClass": String(describing: viewHit.map { type(of: $0) }),
                    "headerViewHitClass": String(describing: headerViewHit.map { type(of: $0) }),
                    "headerVisibleRect": NSStringFromRect(header.visibleRect),
                    "scrollFrame": String(describing: table.enclosingScrollView?.frame),
                    "headerParent": String(describing: header.superview), "proxy": String(describing: proxy)
                ]
                if let json = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]), let line = String(data: json, encoding: .utf8) { print(line) }
            }
            if phase >= 4 {
                let source = children[2] as! NSObject
                let expectedDirection = phase == 4 ? "AXAscendingSortDirection" : "AXDescendingSortDirection"
                let expectedRow = phase == 4 ? 0 : 1
                guard source.accessibilityAttributeValue(.sortDirection) as? String == expectedDirection,
                      table.selectedRow == expectedRow else {
                    print("ERROR Source semantic action did not preserve the expected sort direction and selected row")
                    exit(5)
                }
            }
            switch phase {
            case 0: table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            case 1, 2: (children[1] as! NSObject).accessibilityPerformAction(.press)
            case 3, 4: (children[2] as! NSObject).accessibilityPerformAction(.press)
            default: exit(0)
            }
            schedule(phase + 1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { runPhase(0) }
        app.run()
    }
}
