import Foundation
import Darwin
import AppKit

/// Separate-process safety contract. Only directories freshly created by this test are removed.
@main struct SelectionTraceContract {
    @MainActor static func main() throws {
        if CommandLine.arguments.contains("--reader") {
            let nonce = CommandLine.arguments.last!
            let directory = try QATraceHandoff.Directory(nonce)
            let startup = try directory.read(QATraceHandoff.startupName, limit: QATraceHandoff.startupLimit)
            let trace = try directory.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit)
            precondition(String(decoding: startup, as: UTF8.self).contains("trace.ready"))
            precondition(String(decoding: trace, as: UTF8.self).contains("contract"))
            precondition(!String(decoding: trace, as: UTF8.self).contains("PRIVATE-CONTRACT-MARKER"))
            // Negative controls prove that this reader is actually write-restricted.
            let forbidden = try QATraceHandoff.location(UUID().uuidString)
            errno = 0
            precondition(mkdir(forbidden.path, 0o700) == -1 && errno == EPERM)
            errno = 0
            let fd = open(directory.url.appendingPathComponent(QATraceHandoff.traceName).path, O_WRONLY | O_APPEND | O_NOFOLLOW)
            precondition(fd == -1 && errno == EPERM)
            do { try directory.remove(); fatalError("Read-only controller unexpectedly removed evidence") }
            catch { precondition((error as NSError).code == Int(EPERM)) }
            let retained = try directory.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit)
            precondition(retained == trace)
            print("Sandbox reader PASS: directory open, startup read, native trace read; mkdir, append and unlink denied with EPERM")
            return
        }
        if CommandLine.arguments.contains("--child") {
            QASelectionDiagnostics.start(isolated: true)
            QASelectionDiagnostics.session?.record("contract", ["searchToken": QASelectionDiagnostics.token("PRIVATE-CONTRACT-MARKER")])
            if CommandLine.arguments.contains("--wait-for-cleanup") {
                print("ready"); fflush(stdout)
                _ = try FileHandle.standardInput.read(upToCount: 1)
                NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)
            }
            return
        }
        let flags = ["--ui-testing", "--qa-selection-diagnostics"]
        precondition(!QASelectionDiagnostics.enabled(isolated: false, arguments: flags))
        precondition(!QASelectionDiagnostics.enabled(isolated: true, arguments: [flags[0]]))
        precondition(!QASelectionDiagnostics.enabled(isolated: true, arguments: [flags[1]]))
        precondition(QASelectionDiagnostics.enabled(isolated: true, arguments: flags))
        var owned: [URL] = []
        defer { for url in owned { try? FileManager.default.removeItem(at: url) } }
        func directory() throws -> (String, QATraceHandoff.Directory) {
            let nonce = UUID().uuidString
            let directory = try QATraceHandoff.Directory.create(nonce)
            owned.append(directory.url)
            return (nonce, directory)
        }
        func child(_ nonce: String, diagnostics: Bool = true, wait: Bool = false) throws -> (Process, Pipe?) {
            let temporary = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
                .appendingPathComponent("MacventoryTraceContract-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false,
                                                    attributes: [.posixPermissions: 0o700])
            owned.append(temporary)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
            process.arguments = ["--child", "--ui-testing", "--qa-selection-trace-id", nonce] +
                (diagnostics ? ["--qa-selection-diagnostics"] : []) + (wait ? ["--wait-for-cleanup"] : [])
            var environment = ProcessInfo.processInfo.environment
            environment["TMPDIR"] = temporary.path + "/" // Child only; never changes the developer's environment.
            process.environment = environment
            let control = wait ? Pipe() : nil
            let ready = wait ? Pipe() : nil
            if wait { process.standardInput = control; process.standardOutput = ready }
            try process.run()
            if let ready {
                precondition(ready.fileHandleForReading.readData(ofLength: 6) == Data("ready\n".utf8))
            } else {
                process.waitUntilExit()
                precondition(process.terminationStatus == 0)
            }
            return (process, control)
        }
        func rejected(_ action: () throws -> Void, code: Int? = nil) {
            do { try action(); fatalError("Unsafe handoff unexpectedly accepted") }
            catch { if let code { precondition((error as NSError).code == code, "Unexpected failure: \(error)") } }
        }
        let nonce = UUID().uuidString
        let destination = try QATraceHandoff.location(nonce)
        precondition(!FileManager.default.fileExists(atPath: destination.path))
        owned.append(destination)
        let (writer, control) = try child(nonce, wait: true)
        // The parent neither creates the destination nor shares a directory descriptor.
        let valid = try QATraceHandoff.Directory(nonce)
        let startup = try valid.read(QATraceHandoff.startupName, limit: QATraceHandoff.startupLimit)
        let records = try String(decoding: startup, as: UTF8.self).split(separator: "\n").map {
            try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
        }
        let childPaths = records[0]["paths"] as! [String: String]
        print("controller paths: \(QATraceHandoff.processPaths); child paths: \(childPaths)"); fflush(stdout)
        // macOS may ignore TMPDIR for FileManager. Verify physically distinct configured roots,
        // not an assumption about Foundation's per-OS temporary-directory implementation.
        let childTemporary = URL(fileURLWithPath: childPaths["TMPDIR"]!).resolvingSymlinksInPath()
        let controllerTemporary = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        precondition(childTemporary.standardizedFileURL != controllerTemporary.standardizedFileURL)
        precondition(FileManager.default.fileExists(atPath: childTemporary.path))
        precondition(records.last?["stage"] as? String == "trace.ready")
        let data = try valid.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit)
        precondition(String(decoding: data, as: UTF8.self).contains("contract"))
        precondition(!String(decoding: data, as: UTF8.self).contains("PRIVATE-CONTRACT-MARKER"))
        let reader = Process()
        reader.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
        // Match the hosted runner's relevant filesystem boundary: read-only /, no external writes.
        // Denying ALL writes is stricter than its writable private container. No app entitlements change.
        reader.arguments = ["-p", "(version 1)(allow default)(deny file-write*)",
                            URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path, "--reader", nonce]
        try reader.run(); reader.waitUntilExit()
        precondition(reader.terminationStatus == 0, "Sandbox reader must execute; an unavailable sandbox is a failure")
        rejected({ _ = try QATraceHandoff.Directory.create(nonce) }, code: Int(EEXIST))
        rejected({ _ = try valid.createFile(QATraceHandoff.traceName) }, code: Int(EEXIST))
        rejected({ _ = try QATraceHandoff.location("../untrusted") }, code: Int(EINVAL))
        rejected({ _ = try valid.createFile("../untrusted") }, code: Int(EINVAL))
        let boundedNonce = UUID().uuidString
        let bounded = try QATraceHandoff.Directory.create(boundedNonce); owned.append(bounded.url)
        let session = try QASelectionDiagnostics.Session(directory: bounded)
        let before = try bounded.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit)
        session.record("oversized", ["padding": String(repeating: "x", count: QATraceHandoff.traceLimit)])
        let after = try bounded.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit)
        precondition(after == before)
        let (_, empty) = try directory()
        try empty.createFile(QATraceHandoff.traceName).close()
        rejected({ _ = try empty.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit) }, code: Int(ENODATA))
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: empty.url.appendingPathComponent(QATraceHandoff.traceName).path)
        rejected({ _ = try empty.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit) }, code: Int(EACCES))
        let (failedNonce, failed) = try directory()
        try FileManager.default.createSymbolicLink(at: failed.url.appendingPathComponent(QATraceHandoff.traceName),
                                                 withDestinationURL: valid.url.appendingPathComponent(QATraceHandoff.traceName))
        _ = try child(failedNonce)
        // An existing directory is rejected before any startup/trace file is written.
        rejected({ _ = try failed.read(QATraceHandoff.startupName, limit: QATraceHandoff.startupLimit) }, code: Int(ENOENT))
        rejected({ _ = try failed.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit) }, code: Int(ELOOP))
        let retained = try valid.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit)
        precondition(retained == data)
        let (_, unsafeDirectory) = try directory()
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: unsafeDirectory.url.path)
        let unsafeNonce = String(unsafeDirectory.url.lastPathComponent.suffix(36))
        rejected({ _ = try QATraceHandoff.Directory(unsafeNonce) }, code: Int(EACCES))
        let (linkedNonce, linked) = try directory()
        // Replace only our own fresh empty directory with a test link.
        try FileManager.default.removeItem(at: linked.url)
        try FileManager.default.createSymbolicLink(at: linked.url, withDestinationURL: valid.url)
        rejected({ _ = try QATraceHandoff.Directory(linkedNonce) })
        let (_, hard) = try directory()
        precondition(link(valid.url.appendingPathComponent(QATraceHandoff.traceName).path,
                          hard.url.appendingPathComponent(QATraceHandoff.traceName).path) == 0)
        rejected({ _ = try hard.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit) }, code: Int(EACCES))
        rejected({ try hard.remove() }, code: Int(EACCES))
        // Remove only this fixture link so that the original trace has one link again.
        precondition(unlink(hard.url.appendingPathComponent(QATraceHandoff.traceName).path) == 0)
        let afterHardLink = try valid.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit)
        precondition(afterHardLink == data)
        rejected({ try failed.remove() }, code: Int(ELOOP))
        let (_, unknown) = try directory()
        let sentinel = unknown.url.appendingPathComponent("unrecognized-test-file")
        try Data("fixture-only".utf8).write(to: sentinel, options: .withoutOverwriting)
        rejected({ try unknown.remove() }, code: Int(ENOTEMPTY))
        let preserved = try Data(contentsOf: sentinel)
        precondition(preserved == Data("fixture-only".utf8))
        let (changedNonce, changed) = try directory()
        let moved = changed.url.appendingPathExtension("retained-fixture")
        try FileManager.default.moveItem(at: changed.url, to: moved)
        owned.append(moved)
        _ = try QATraceHandoff.Directory.create(changedNonce)
        rejected({ try changed.remove() }, code: Int(EACCES))
        let (emptyNonce, cleanupEmpty) = try directory()
        try cleanupEmpty.remove()
        rejected({ _ = try QATraceHandoff.Directory(emptyNonce) }, code: Int(ENOENT))
        let disabledNonce = UUID().uuidString
        _ = try child(disabledNonce, diagnostics: false)
        let disabledLocation = try QATraceHandoff.location(disabledNonce)
        precondition(!FileManager.default.fileExists(atPath: disabledLocation.path))
        rejected({ _ = try QATraceHandoff.Directory(disabledNonce) }, code: Int(ENOENT))
        // Exercise the actual app-side normal-termination observer in the separate writer.
        try control!.fileHandleForWriting.write(contentsOf: Data([1]))
        try control!.fileHandleForWriting.close()
        writer.waitUntilExit()
        precondition(writer.terminationStatus == 0)
        rejected({ _ = try QATraceHandoff.Directory(nonce) }, code: Int(ENOENT))
        print("Cross-process trace PASS: app-exclusive create/write, distinct temp roots, sandboxed read-only controller, bootstrap/trace reads, redaction, size bound, 0700/0600, directory/file exclusive create, invalid nonce/name/mode/link/hard-link refusal, disabled mode creates no directory, app-owned termination cleanup")
    }
}
