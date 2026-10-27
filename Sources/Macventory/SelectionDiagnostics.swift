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
    static let lifecycleName = "startup-lifecycle.jsonl"
    static let selectionEnvironmentKey = "MACVENTORY_QA_SELECTION_TRACE_ID"
    static let startupEnvironmentKey = "MACVENTORY_QA_STARTUP_TRACE_ID"
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
            guard [traceName, startupName, lifecycleName].contains(name) else { throw failure("Invalid trace filename", code: EINVAL) }
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
            for name in [startupName, traceName, lifecycleName] {
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
            guard [traceName, startupName, lifecycleName].contains(name) else { throw failure("Invalid trace filename", code: EINVAL) }
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

/// Independent of the table/selection probe: available even when no scene attaches.
/// Only explicitly requested synthetic QA launches write this bounded private trace.
/// Never creates/activates/orders a window, changes preferences, or installs an event monitor.
@MainActor
enum QAStartupDiagnostics {
    private static var session: Session?
    static func start(isolated: Bool, arguments: [String] = ProcessInfo.processInfo.arguments,
                      environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard session == nil, isolated, arguments.contains("--ui-testing"),
              arguments.contains("--qa-startup-diagnostics"),
              let nonce = environment[QATraceHandoff.startupEnvironmentKey] else { return }
        do { session = try Session(nonce: nonce) }
        catch { NSLog("QA startup observation could not initialize: %@", error.localizedDescription) }
    }
    static func record(_ stage: String, _ fields: [String: Any] = [:]) { session?.record(stage, fields) }

    @MainActor private final class Session {
        private let directory: QATraceHandoff.Directory
        private let file: FileHandle
        private var observers: [NSObjectProtocol] = []
        private var bytes = 0
        private var sequence = 0
        private var updateSignature: String?

        init(nonce: String) throws {
            directory = try QATraceHandoff.Directory.create(nonce)
            file = try directory.createFile(QATraceHandoff.lifecycleName)
            record("startup.observer.ready", ["selectionDiagnostics": ProcessInfo.processInfo.arguments.contains("--qa-selection-diagnostics"),
                "isolated": true, "uiTestingArgument": true,
                "bundleIdentifier": Bundle.main.bundleIdentifier ?? "nil", "pid": ProcessInfo.processInfo.processIdentifier,
                "paths": QATraceHandoff.processPaths, "restorationPreferences": Self.restorationPreferences])
            let defaultLaunchKey = NSApplication.launchIsDefaultUserInfoKey
            for name in [NSApplication.willFinishLaunchingNotification, NSApplication.didFinishLaunchingNotification,
                         NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
                         NSApplication.didHideNotification, NSApplication.didUnhideNotification,
                         NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                         NSWindow.didBecomeMainNotification, NSWindow.didMiniaturizeNotification,
                         NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    let isDefaultLaunch = (note.userInfo?[defaultLaunchKey] as? NSNumber)?.boolValue
                    let window = note.object as? NSWindow
                    MainActor.assumeIsolated {
                        var fields: [String: Any] = ["notification": name.rawValue]
                        if let isDefaultLaunch { fields["isDefaultLaunch"] = isDefaultLaunch }
                        if name == NSApplication.didFinishLaunchingNotification {
                            fields["restorationPreferences"] = Self.restorationPreferences
                        }
                        if let window { fields["notifyingWindow"] = Self.windowState(window) }
                        self?.record("native.notification", fields)
                    }
                })
            }
            // Event-driven snapshots, deduplicated by actual native state. No timer,
            // sleep, updateWindows call or synthetic event advances the lifecycle.
            observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didUpdateNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let state = Self.nativeState
                    let signature = (try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) }
                    guard signature != self.updateSignature else { return }
                    self.updateSignature = signature
                    self.record("native.windowsUpdated", state)
                }
            })
            observers.append(NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.record("application.willTerminate")
                    do { try self.directory.remove() }
                    catch { NSLog("QA startup trace cleanup failed: %@", error.localizedDescription) }
                }
            })
        }
        private static var restorationPreferences: [String: Any] {
            let defaults = UserDefaults.standard
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            let domain = defaults.persistentDomain(forName: bundleID) ?? [:]
            var result: [String: Any] = ["persistentKeys": Array(domain.keys.sorted().prefix(64)),
                                         "hasConfiguration": domain["configuration"] != nil]
            for key in ["NSQuitAlwaysKeepsWindows", "ApplePersistenceIgnoreState"] {
                result[key] = defaults.object(forKey: key).map { String(describing: $0) } ?? "unset"
            }
            // Presence only: do not copy file paths from AppKit's launch defaults.
            result["NSOpenPresent"] = defaults.object(forKey: "NSOpen") != nil
            let saved = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Saved Application State/" + bundleID + ".savedState")
            result["savedStateDirectoryExists"] = FileManager.default.fileExists(atPath: saved.path)
            return result
        }
        private static func windowState(_ window: NSWindow) -> [String: Any] {
            ["identity": String(describing: ObjectIdentifier(window)), "class": String(describing: type(of: window)),
             "number": window.windowNumber, "identifier": window.identifier?.rawValue ?? "nil",
             "title": window.title, "frame": NSStringFromRect(window.frame), "visible": window.isVisible,
             "key": window.isKeyWindow, "main": window.isMainWindow, "miniaturized": window.isMiniaturized,
             "restorable": window.isRestorable, "occlusionVisible": window.occlusionState.contains(.visible),
             "contentView": window.contentView.map { String(describing: type(of: $0)) } ?? "nil"]
        }
        private static var nativeState: [String: Any] {
            // NSApp is read without NSApplication.shared: observation must not
            // instantiate NSApplication earlier than SwiftUI normally would.
            guard let app = NSApp else { return ["nsApplicationAvailable": false] }
            return ["nsApplicationAvailable": true, "active": app.isActive, "hidden": app.isHidden,
                    "activationPolicy": app.activationPolicy().rawValue, "running": app.isRunning,
                    "windows": app.windows.map(windowState), "orderedWindows": app.orderedWindows.map(\.windowNumber),
                    "keyWindow": app.keyWindow?.windowNumber ?? -1, "mainWindow": app.mainWindow?.windowNumber ?? -1]
        }
        func record(_ stage: String, _ fields: [String: Any] = [:]) {
            guard bytes < 262_144 else { return }
            sequence += 1
            var value = Self.nativeState.merging(fields) { _, new in new }
            value["stage"] = stage; value["sequence"] = sequence; value["uptime"] = ProcessInfo.processInfo.systemUptime
            guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
                  bytes + data.count + 1 <= 262_144 else { return }
            do { try file.write(contentsOf: data + Data([10])); bytes += data.count + 1 }
            catch { NSLog("QA startup trace append failed: %@", error.localizedDescription) }
        }
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
    static func start(isolated: Bool, arguments: [String] = ProcessInfo.processInfo.arguments,
                      environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard !attempted, enabled(isolated: isolated, arguments: arguments) else { return }
        attempted = true
        var startup: FileHandle?
        do {
            // Cold QA presentation depends on the original argument arrangement.
            // Transport this opaque metadata independently of launch-argument order.
            guard let nonce = environment[QATraceHandoff.selectionEnvironmentKey] else {
                throw QATraceHandoff.failure("Missing " + QATraceHandoff.selectionEnvironmentKey, code: EINVAL)
            }
            let directory = try QATraceHandoff.Directory.create(nonce)
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
            // Capture the native changing notification as well as the committed
            // change. A provisional selection may roll back without didChange.
            for (name, event) in [(NSTableView.selectionIsChangingNotification, "native.selectionChanging"),
                                  (NSOutlineView.selectionIsChangingNotification, "native.selectionChanging"),
                                  (NSTableView.selectionDidChangeNotification, "native.selectionChanged"),
                                  (NSOutlineView.selectionDidChangeNotification, "native.selectionChanged")] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    guard let table = note.object as? NSTableView else { return }
                    MainActor.assumeIsolated {
                        guard let self, let window = self.window, table.window === window, table.tableColumns.contains(where: { $0.title == "Name" }) else { return }
                        self.record(event, ["notification": name.rawValue, "notifyingTable": Self.identity(table),
                            "callerStack": Array(Thread.callStackSymbols.prefix(40))])
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
                        if relevant {
                            var fields: [String: Any] = ["notification": name.rawValue]
                            if name == NSControl.textDidEndEditingNotification {
                                fields["callerStack"] = Array(Thread.callStackSymbols.prefix(40))
                            }
                            self.record("responder.notification", fields)
                        }
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
