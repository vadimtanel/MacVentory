import AppKit
import SwiftUI
import CryptoKit
import Darwin

/// Temporary, observational diagnostics. No event replacement, responder changes or selection setters.
@MainActor
enum QASelectionDiagnostics {
    static var session: Session?
    static func enabled(isolated: Bool, arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        isolated && arguments.contains("--ui-testing") && arguments.contains("--qa-selection-diagnostics")
    }
    static func token(_ value: String?) -> String {
        value.map { SHA256.hash(data: Data($0.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined() } ?? "nil"
    }
    static func record(_ event: String, _ fields: [String: Any] = [:]) {
        if event == "binding.set" { session?.state["lastBindingSelection"] = fields["new"] }
        if event == "selection.observed" { session?.state["lastObservedSelection"] = fields["value"] }
        session?.record(event, fields)
    }
    static func start(isolated: Bool) {
        guard session == nil, enabled(isolated: isolated) else { return }
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--qa-selection-trace-file"), args.indices.contains(index + 1) else {
            NSLog("QA selection diagnostics require an explicit temporary trace destination")
            return
        }
        guard let created = Session(url: URL(fileURLWithPath: args[index + 1])) else {
            NSLog("QA selection trace unavailable: require a fresh MacventorySelection-UUID.jsonl in this process temporary directory")
            return
        }
        session = created
    }

    @MainActor final class Session {
        private let file: FileHandle
        private var bytes = 0
        private var sequence = 0
        private var monitor: Any?
        private var observers: [NSObjectProtocol] = []
        weak var window: NSWindow?
        var state: [String: Any] = [:]

        init?(url: URL) {
            // Only a fresh, private test log in this user's temporary directory. Never follow a link.
            let parent = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
            guard parent == FileManager.default.temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL,
                  url.lastPathComponent.hasPrefix("MacventorySelection-"), url.pathExtension == "jsonl",
                  UUID(uuidString: String(url.deletingPathExtension().lastPathComponent.dropFirst("MacventorySelection-".count))) != nil else { return nil }
            let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
            guard descriptor >= 0 else { return nil }
            file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            record("trace.started", ["pid": ProcessInfo.processInfo.processIdentifier])
        }
        func attach(_ window: NSWindow) {
            self.window = window
            record("window.attached")
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .keyDown]) { [weak self] event in
                MainActor.assumeIsolated {
                    guard let self, let window = self.window, event.window === window else { return }
                    let fields: [String: Any] = ["eventType": event.type.rawValue, "eventTimestamp": event.timestamp,
                        "pointInWindow": NSStringFromPoint(event.locationInWindow), "clickCount": event.type == .keyDown ? 0 : event.clickCount,
                        "keyCode": event.type == .keyDown && [36, 48, 53, 123, 124, 125, 126].contains(event.keyCode) ? Int(event.keyCode) : -1]
                    // Public hitTest predicts routing; it cannot prove a private SwiftUI handler ran.
                    self.record("event.beforeDelivery", fields, point: event.locationInWindow)
                    let point = event.locationInWindow
                    // A tracking loop may run nested turns: this is a scheduled
                    // snapshot, not proof that a private mouse handler returned.
                    DispatchQueue.main.async { [weak self] in self?.record("event.nextMainTurn", fields, point: point) }
                }
                return event // Observe only: never consume, replace, redirect or synthesize input.
            }
            for name in [NSTableView.selectionDidChangeNotification, NSOutlineView.selectionDidChangeNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    guard let table = note.object as? NSTableView else { return }
                    MainActor.assumeIsolated {
                        guard let self, let window = self.window, table.window === window, table.tableColumns.contains(where: { $0.title == "Name" }) else { return }
                        self.record("native.selectionChanged", ["notification": name.rawValue, "notifyingTable": Self.identity(table)])
                    }
                })
            }
            for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
                         NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                         NSControl.textDidBeginEditingNotification, NSControl.textDidEndEditingNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    let observedWindow = note.object as? NSWindow
                    let control = note.object as? NSControl
                    let application = note.object as? NSApplication
                    MainActor.assumeIsolated {
                        guard let self, let window = self.window else { return }
                        let relevant = observedWindow.map { $0 === window } ?? control.map { $0.window === window } ?? (application != nil)
                        if relevant { self.record("responder.notification", ["notification": name.rawValue]) }
                    }
                })
            }
        }
        private static func identity(_ object: AnyObject?) -> String {
            object.map { String(describing: type(of: $0)) + ":" + String(describing: ObjectIdentifier($0)) } ?? "nil"
        }
        private func inventoryTables(_ view: NSView) -> [NSTableView] {
            if let table = view as? NSTableView, table.tableColumns.contains(where: { $0.title == "Name" }), table.tableColumns.count > 1 { return [table] }
            return view.subviews.flatMap(inventoryTables)
        }
        func record(_ event: String, _ fields: [String: Any] = [:], point: NSPoint? = nil) {
            guard bytes < 1_048_576 else { return }
            sequence += 1
            var record = state.merging(fields) { _, new in new }
            record["event"] = event; record["sequence"] = sequence; record["uptime"] = ProcessInfo.processInfo.systemUptime
            record["firstResponder"] = Self.identity(window?.firstResponder)
            if let editor = window?.firstResponder as? NSTextView { record["fieldEditor"] = editor.isFieldEditor; record["editorDelegateClass"] = editor.delegate.map { String(describing: type(of: $0)) } ?? "nil" }
            if let root = window?.contentView {
                let tables = inventoryTables(root)
                record["tables"] = tables.map { table -> [String: Any] in
                    var result: [String: Any] = ["identity": Self.identity(table), "selectedRows": Array(table.selectedRowIndexes),
                        "clickedRow": table.clickedRow, "rowCount": table.numberOfRows, "frame": NSStringFromRect(table.frame)]
                    if let point { result["rowAtPoint"] = table.row(at: table.convert(point, from: nil)) }
                    return result
                }
                if let point {
                    let parentPoint = root.superview?.convert(point, from: nil) ?? point
                    record["predictedHitView"] = Self.identity(root.hitTest(parentPoint))
                }
            }
            guard let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]), bytes + data.count + 1 <= 1_048_576 else { return }
            do { try file.write(contentsOf: data + Data([10])); bytes += data.count + 1 }
            catch { NSLog("QA selection trace could not append an observation") }
        }
    }
}

struct QASelectionObserver: NSViewRepresentable {
    let selected: String?
    let rows: [String]
    let search: String
    func makeNSView(context: Context) -> Reader {
        QASelectionDiagnostics.start(isolated: true)
        return Reader()
    }
    func updateNSView(_ view: Reader, context: Context) {
        // Old/new probes can coexist while SwiftUI reparents the table. Label the
        // view snapshot and its owner; never misreport it as the current binding value.
        QASelectionDiagnostics.session?.state.merge(["viewSnapshotSelection": QASelectionDiagnostics.token(selected),
            "viewProbe": String(describing: ObjectIdentifier(view)), "rowIDs": rows.map { QASelectionDiagnostics.token($0) },
            "searchToken": QASelectionDiagnostics.token(search)]) { _, new in new }
        QASelectionDiagnostics.record("swiftUI.updated")
    }
    final class Reader: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { QASelectionDiagnostics.session?.attach(window) }
            QASelectionDiagnostics.record(window == nil ? "tableProbe.detached" : "tableProbe.attached", ["probe": String(describing: ObjectIdentifier(self))])
        }
    }
}
