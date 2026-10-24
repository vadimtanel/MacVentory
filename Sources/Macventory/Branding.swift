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
    func pointingControl(enabled: Bool = true) -> some View { modifier(PointingControl(enabled: enabled)) }
    @ViewBuilder func inventoryNavigationTitle() -> some View {
        if #available(macOS 26, *) { navigationTitle("Macventory").toolbar(removing: .title) }
        else { navigationTitle("Macventory") }
    }
}

private struct PointingControl: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    var enabled = true
    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside && isEnabled && enabled { NSCursor.pointingHand.set() }
            else { NSCursor.arrow.set() }
        }.onDisappear { NSCursor.arrow.set() }
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
            if let button = view as? NSButton {
                if !button.subviews.contains(where: { $0 is NativePointerRegion }) {
                    let region = NativePointerRegion(frame: button.bounds)
                    region.control = button; region.autoresizingMask = [.width, .height]
                    button.addSubview(region)
                }
                for region in button.subviews.compactMap({ $0 as? NativePointerRegion }) { button.window?.invalidateCursorRects(for: region) }
            }
            if let table = view as? NSTableView {
                for column in table.tableColumns { column.headerToolTip = "Sort by \(column.title). Click again to reverse; missing values stay last." }
                if let header = table.headerView, !header.subviews.contains(where: { $0 is NativePointerRegion }) {
                    let region = NativePointerRegion(frame: header.bounds)
                    region.table = table; region.autoresizingMask = [.width, .height]
                    header.addSubview(region)
                }
            }
            for child in view.subviews { annotateSearch(in: child) }
        }
    }
}

/// Native cursor rectangles disappear with their owning view. They do not push a global
/// cursor stack, intercept clicks, cover text fields, or override header resize boundaries.
private final class NativePointerRegion: NSView {
    weak var control: NSControl?
    weak var table: NSTableView?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func resetCursorRects() {
        if let control, control.isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
        else if let table {
            for index in table.tableColumns.indices {
                let rect = table.rect(ofColumn: index)
                addCursorRect(NSRect(x: rect.minX + 5, y: 0, width: max(0, rect.width - 10), height: bounds.height), cursor: .pointingHand)
            }
        }
    }
}
