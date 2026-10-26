import Foundation
import Darwin

/// Separate-process safety contract. Only directories freshly created by this test are removed.
@main struct SelectionTraceContract {
    @MainActor static func main() throws {
        if CommandLine.arguments.contains("--child") {
            QASelectionDiagnostics.start(isolated: true)
            QASelectionDiagnostics.session?.record("contract", ["searchToken": QASelectionDiagnostics.token("PRIVATE-CONTRACT-MARKER")])
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
        func child(_ nonce: String, _ directory: QATraceHandoff.Directory, diagnostics: Bool = true) throws {
            let temporary = directory.url.appendingPathComponent("child-tmp", isDirectory: true)
            try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
            process.arguments = ["--child", "--ui-testing", "--qa-selection-trace-id", nonce] + (diagnostics ? ["--qa-selection-diagnostics"] : [])
            var environment = ProcessInfo.processInfo.environment
            environment["TMPDIR"] = temporary.path + "/" // Child only; never changes the developer's environment.
            process.environment = environment
            try process.run(); process.waitUntilExit()
            precondition(process.terminationStatus == 0)
        }
        func rejected(_ action: () throws -> Void, code: Int? = nil) {
            do { try action(); fatalError("Unsafe handoff unexpectedly accepted") }
            catch { if let code { precondition((error as NSError).code == code, "Unexpected failure: \(error)") } }
        }
        let (nonce, valid) = try directory()
        try child(nonce, valid)
        let startup = try valid.read(QATraceHandoff.startupName, limit: QATraceHandoff.startupLimit)
        let records = try String(decoding: startup, as: UTF8.self).split(separator: "\n").map {
            try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
        }
        let childPaths = records[0]["paths"] as! [String: String]
        precondition(childPaths["temporaryDirectory"] != QATraceHandoff.processPaths["temporaryDirectory"])
        precondition(records.last?["stage"] as? String == "trace.ready")
        let data = try valid.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit)
        precondition(String(decoding: data, as: UTF8.self).contains("contract"))
        precondition(!String(decoding: data, as: UTF8.self).contains("PRIVATE-CONTRACT-MARKER"))
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
        try child(failedNonce, failed)
        let failure = String(decoding: try failed.read(QATraceHandoff.startupName, limit: QATraceHandoff.startupLimit), as: UTF8.self)
        precondition(failure.contains("initialization.failed") && failure.contains("errno=17") && failure.contains("Create native-selection.jsonl"))
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
        let (disabledNonce, disabled) = try directory()
        try child(disabledNonce, disabled, diagnostics: false)
        rejected({ _ = try disabled.read(QATraceHandoff.startupName, limit: QATraceHandoff.startupLimit) }, code: Int(ENOENT))
        rejected({ _ = try disabled.read(QATraceHandoff.traceName, limit: QATraceHandoff.traceLimit) }, code: Int(ENOENT))
        print("Cross-process trace PASS: distinct canonical temp roots, bootstrap receipt, child write/parent read, redaction, size bound, 0700/0600, exclusive create, invalid nonce/name/directory/link refusal, precise EEXIST receipt, disabled mode creates no files")
        print("controller paths: \(QATraceHandoff.processPaths); child paths: \(childPaths)")
    }
}
