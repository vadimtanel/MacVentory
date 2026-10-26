import AppKit
import SwiftUI
import CryptoKit
import Darwin

/// Shared by the app and XCTest runner. Only an opaque nonce crosses the launch boundary.
/// A fixed OS temporary root avoids either process's container/TMPDIR. Each run owns a
/// fresh app-created 0700 directory; the runner only reads. Descriptor-relative operations
/// never follow a supplied link. The app removes its evidence on normal termination.
enum QATraceHandoff {
    static let traceName = "native-selection.jsonl"
    static let startupName = "startup.jsonl"
    static let traceLimit = 1_048_576
    static let startupLimit = 16_384
    static func failure(_ operation: String, code: Int32 = errno) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [NSLocalizedDescriptionKey:
            "\(operation): errno=\(code) (\(String(cString: strerror(code))))"])
    }
    static func location(_ nonce: String) throws -> URL {
        guard UUID(uuidString: nonce)?.uuidString == nonce else { throw failure("Invalid trace nonce", code: EINVAL) }
        return URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("MacventorySelection-\(geteuid())-\(nonce)", isDirectory: true)
    }
    final class Directory: Sendable {
        let url: URL
        private let descriptor: Int32
        static func create(_ nonce: String) throws -> Directory {
            let url = try location(nonce)
            guard mkdir(url.path, 0o700) == 0 else { throw failure("Create private trace directory") }
            return try Directory(nonce)
        }
        init(_ nonce: String) throws {
            url = try location(nonce)
            let opened = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard opened >= 0 else { throw failure("Open private trace directory") }
            var info = stat()
            guard fstat(opened, &info) == 0 else {
                let error = failure("Inspect private trace directory")
                close(opened)
                throw error
            }
            guard info.st_uid == geteuid(), info.st_mode & S_IFMT == S_IFDIR, info.st_mode & 0o777 == 0o700 else {
                close(opened)
                throw failure("Trace directory must be owned by this user with mode 0700", code: EACCES)
            }
            descriptor = opened
        }
        deinit { close(descriptor) }
        func createFile(_ name: String) throws -> FileHandle {
            guard [traceName, startupName].contains(name) else { throw failure("Invalid trace filename", code: EINVAL) }
            let fd = openat(descriptor, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard fd >= 0 else { throw failure("Create \(name)") }
            return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        }
        /// App-side cleanup only. Never recurse or remove an unknown filename.
        func remove() throws {
            var current = stat(), retained = stat()
            guard lstat(url.path, &current) == 0, fstat(descriptor, &retained) == 0 else {
                throw failure("Inspect trace directory before cleanup")
            }
            guard current.st_dev == retained.st_dev, current.st_ino == retained.st_ino,
                  current.st_uid == geteuid(), current.st_mode & S_IFMT == S_IFDIR,
                  current.st_mode & 0o777 == 0o700 else {
                throw failure("Trace directory changed before cleanup", code: EACCES)
            }
            for name in [startupName, traceName] {
                let fd = openat(descriptor, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
                if fd < 0 && errno == ENOENT { continue }
                guard fd >= 0 else { throw failure("Open trace file before cleanup") }
                var info = stat()
                let inspected = fstat(fd, &info)
                close(fd)
                guard inspected == 0, info.st_uid == geteuid(), info.st_mode & S_IFMT == S_IFREG,
                      info.st_mode & 0o777 == 0o600, info.st_nlink == 1 else {
                    throw failure("Invalid trace file before cleanup", code: EACCES)
                }
                guard unlinkat(descriptor, name, 0) == 0 else { throw failure("Remove private trace file") }
            }
            guard rmdir(url.path) == 0 else { throw failure("Remove private trace directory") }
        }
        func read(_ name: String, limit: Int) throws -> Data {
            guard [traceName, startupName].contains(name) else { throw failure("Invalid trace filename", code: EINVAL) }
            let fd = openat(descriptor, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard fd >= 0 else { throw failure("Read \(name)") }
            let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            defer { try? file.close() }
            var info = stat()
            guard fstat(fd, &info) == 0 else { throw failure("Inspect \(name)") }
            guard info.st_uid == geteuid(), info.st_mode & S_IFMT == S_IFREG,
                  info.st_mode & 0o777 == 0o600, info.st_nlink == 1, info.st_size <= limit else {
                throw failure("Invalid trace file type, ownership, permissions or size: \(name)", code: EACCES)
            }
            let data = try file.read(upToCount: limit + 1) ?? Data()
            guard data.count <= limit else { throw failure("Trace exceeds size bound", code: EFBIG) }
            guard !data.isEmpty else { throw failure("Empty \(name)", code: ENODATA) }
            return data
        }
    }
    static func writeStartup(_ file: FileHandle, _ fields: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) + Data([10])
        guard data.count <= startupLimit / 4 else { throw failure("Startup record exceeds size bound", code: EFBIG) }
        try file.write(contentsOf: data)
    }
    private static func canonicalPath(_ url: URL) -> String {
        guard let path = realpath(url.path, nil) else { return url.standardizedFileURL.path }
        defer { free(path) }
        return String(cString: path)
    }
    static var processPaths: [String: String] {
        ["temporaryDirectory": canonicalPath(FileManager.default.temporaryDirectory),
         "TMPDIR": ProcessInfo.processInfo.environment["TMPDIR"] ?? "unset", "sharedRoot": "/private/tmp"]
    }
}

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
    private static var attempted = false
    private static var cleanupObserver: NSObjectProtocol?
    static func start(isolated: Bool, arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard !attempted, enabled(isolated: isolated, arguments: arguments) else { return }
        attempted = true
        var startup: FileHandle?
        do {
            guard let index = arguments.firstIndex(of: "--qa-selection-trace-id"), arguments.indices.contains(index + 1) else {
                throw QATraceHandoff.failure("Missing --qa-selection-trace-id", code: EINVAL)
            }
            let directory = try QATraceHandoff.Directory.create(arguments[index + 1])
            cleanupObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                                                     object: nil, queue: .main) { _ in
                do { try directory.remove() }
                catch { NSLog("QA selection trace cleanup failed: %@", error.localizedDescription) }
            }
            startup = try directory.createFile(QATraceHandoff.startupName)
            try QATraceHandoff.writeStartup(startup!, ["stage": "bootstrap", "pid": ProcessInfo.processInfo.processIdentifier,
                "isolated": isolated, "enabled": true, "uiTestingArgument": arguments.contains("--ui-testing"),
                "diagnosticsArgument": arguments.contains("--qa-selection-diagnostics"), "paths": QATraceHandoff.processPaths,
                "destination": directory.url.path])
            session = try Session(directory: directory)
            try QATraceHandoff.writeStartup(startup!, ["stage": "trace.ready"])
        } catch {
            let detail = ["stage": "initialization.failed", "error": error.localizedDescription,
                          "domain": (error as NSError).domain, "code": String((error as NSError).code)]
            if let startup { try? QATraceHandoff.writeStartup(startup, detail) }
            NSLog("QA selection trace initialization failed: %@", error.localizedDescription)
        }
        try? startup?.close()
    }

    @MainActor final class Session {
        private let file: FileHandle
        private var bytes = 0
        private var sequence = 0
        private var writeFailure: Error?
        private var monitor: Any?
        private var observers: [NSObjectProtocol] = []
        weak var window: NSWindow?
        var state: [String: Any] = [:]

        init(directory: QATraceHandoff.Directory) throws {
            file = try directory.createFile(QATraceHandoff.traceName)
            record("trace.started", ["pid": ProcessInfo.processInfo.processIdentifier])
            if let writeFailure { throw writeFailure }
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
            catch { writeFailure = error; NSLog("QA selection trace could not append an observation: %@", error.localizedDescription) }
        }
    }
}

struct QASelectionObserver: NSViewRepresentable {
    let selected: String?
    let rows: [String]
    let search: String
    func makeNSView(context: Context) -> Reader {
        QASelectionDiagnostics.record("observer.created")
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
