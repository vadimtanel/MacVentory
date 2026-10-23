import SwiftUI
import AppKit

/// One resource loader for all app branding; never substitutes a generic system icon.
@MainActor
enum BrandAssets {
    static let applicationIcon: NSImage? = Bundle.main.url(forResource: "Macventory", withExtension: "icns").flatMap { NSImage(contentsOf: $0) }
    static let toolbarIcon: NSImage? = Bundle.main.url(forResource: "ToolbarMark", withExtension: "png").flatMap { NSImage(contentsOf: $0) } ?? applicationIcon
}

@MainActor
final class MacventoryAppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var officialIconAssigned = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reassert the official running icon instead of relying on a cached generic Dock image.
        DispatchQueue.main.async {
            if let image = BrandAssets.applicationIcon {
                NSApplication.shared.applicationIconImage = image
                Self.officialIconAssigned = true
            }
        }
    }
}

struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 7) {
            if let icon = BrandAssets.toolbarIcon {
                Image(nsImage: icon).resizable().interpolation(.high).frame(width: 26, height: 26).accessibilityHidden(true)
            }
            if #available(macOS 26, *) { Text("Macventory").font(.headline) }
        }.accessibilityElement(children: .ignore).accessibilityLabel("Macventory software inventory")
    }
}

extension View {
    /// Native hover help plus a VoiceOver explanation, retaining the control's own label.
    func controlHelp(_ text: String) -> some View { help(text).accessibilityHint(text) }
    @ViewBuilder func inventoryNavigationTitle() -> some View {
        if #available(macOS 26, *) { navigationTitle("Macventory").toolbar(removing: .title) }
        else { navigationTitle("Macventory") }
    }
}

/// SwiftUI owns the sidebar toggle and search field. Supply native hover help for
/// those generated controls without replacing their keyboard or accessibility behavior.
struct NativeControlHelp: NSViewRepresentable {
    func makeNSView(context: Context) -> HelpView { HelpView() }
    func updateNSView(_ view: HelpView, context: Context) { view.installHelp() }
    final class HelpView: NSView {
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); installHelp() }
        func installHelp() {
            DispatchQueue.main.async { [weak self] in
                guard let window = self?.window else { return }
                for item in window.toolbar?.items ?? [] {
                    if item.itemIdentifier == .toggleSidebar || item.label.localizedCaseInsensitiveContains("sidebar") { item.toolTip = "Show or Hide Sidebar" }
                    if let view = item.view { Self.annotateSearch(in: view) }
                }
                if let content = window.contentView?.superview ?? window.contentView { Self.annotateSearch(in: content) }
            }
        }
        private static func annotateSearch(in view: NSView) {
            if let search = view as? NSSearchField {
                search.toolTip = "Search Software by name, identifier or installation path"
                search.setAccessibilityHelp("Filter the current inventory using a name, identifier or path")
            }
            if let button = view as? NSButton, let label = button.accessibilityLabel(), label.localizedCaseInsensitiveContains("sidebar") {
                button.toolTip = label
                button.setAccessibilityHelp(label)
            }
            if let table = view as? NSTableView {
                for column in table.tableColumns { column.headerToolTip = "Sort by \(column.title). Click again to reverse; missing values stay last." }
            }
            for child in view.subviews { annotateSearch(in: child) }
        }
    }
}
