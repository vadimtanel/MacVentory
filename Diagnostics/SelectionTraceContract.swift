import Foundation
import Darwin

/// Standalone safety contract for temporary QA logging; never creates a GUI or changes selection.
@main struct SelectionTraceContract {
    @MainActor static func main() throws {
        let flag = ["--ui-testing", "--qa-selection-diagnostics"]
        precondition(!QASelectionDiagnostics.enabled(isolated: false, arguments: flag))
        precondition(!QASelectionDiagnostics.enabled(isolated: true, arguments: ["--qa-selection-diagnostics"]))
        precondition(!QASelectionDiagnostics.enabled(isolated: true, arguments: ["--ui-testing"]))
        precondition(QASelectionDiagnostics.enabled(isolated: true, arguments: flag))
        let temporary = FileManager.default.temporaryDirectory
        let url = temporary.appendingPathComponent("MacventorySelection-\(UUID().uuidString).jsonl")
        let link = temporary.appendingPathComponent("MacventorySelection-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: link) }
        guard let session = QASelectionDiagnostics.Session(url: url) else { fatalError("Fresh QA trace must be created") }
        let marker = "PRIVATE-CONTRACT-MARKER"
        session.record("contract", ["searchToken": QASelectionDiagnostics.token(marker)])
        let data = try Data(contentsOf: url)
        precondition(!String(decoding: data, as: UTF8.self).contains(marker))
        session.record("oversized", ["padding": String(repeating: "x", count: 1_048_576)])
        let bounded = try Data(contentsOf: url)
        precondition(bounded == data, "Oversized observations must not exceed the trace limit")
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        precondition(permissions?.intValue == 0o600)
        precondition(QASelectionDiagnostics.Session(url: url) == nil, "Existing file must not be overwritten")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: url)
        precondition(QASelectionDiagnostics.Session(url: link) == nil, "Symlink must not be followed")
        let retained = try Data(contentsOf: url)
        precondition(retained == data)
        precondition(QASelectionDiagnostics.Session(url: temporary.appendingPathComponent("unapproved-name.jsonl")) == nil)
        print("Selection trace contract passed: synthetic gate, redaction, size bound, 0600, exclusive creation, symlink refusal")
    }
}
