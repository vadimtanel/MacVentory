import AppKit
import SwiftUI
import MacventoryCore

/// One presentation value owns the sheet's complete lifetime, including its terminal result.
struct ManagementPresentation: Identifiable {
    let id = UUID()
    let item: SoftwareItem
    var forceQuit = false
}

struct ManagementView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let presentation: ManagementPresentation
    @State private var forceQuit = false
    @State private var clearData = false
    @State private var uninstall = false
    @State private var selected = Set<String>()
    @State private var acknowledged = false
    private var item: SoftwareItem { presentation.item }
    private var candidates: [AppDataCandidate] { model.managementDiscovery?.candidates ?? [] }
    private var operations: Set<ManagementOperation> {
        var result = Set<ManagementOperation>()
        if forceQuit { result.insert(.forceQuit) }; if clearData { result.insert(.clearData) }; if uninstall { result.insert(.uninstall) }
        return result
    }
    private var actionTitle: String { operations.isEmpty ? "Choose Operations" : ManagementOperation.allCases.filter { operations.contains($0) }.map(\.rawValue).joined(separator: " + ") }
    private var mayUninstall: Bool { model.managementUninstallPlan?.canExecute == true && (model.managementTarget == nil || forceQuit) }
    private var mayConfirm: Bool { !operations.isEmpty && acknowledged && !model.managementPreparing && !model.managementWorking && (!clearData || !selected.isEmpty) && (!uninstall || mayUninstall) && (model.managementTarget == nil || forceQuit || (!clearData && !uninstall)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                AppIcon(path: item.path, demoSymbol: item.attributes["Demo symbol"])
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.title2).bold().accessibilityIdentifier("management.title")
                    Text("\(item.version ?? "Version not available") · \(item.primarySource.title)").foregroundStyle(.secondary)
                    if let path = item.path { Text(path).font(.caption).textSelection(.enabled) }
                }
            }
            if model.qaProtected { Label("Simulation only — no process, application or data will be changed.", systemImage: "shield.checkered").font(.callout).foregroundStyle(.blue) }
            if let result = model.managementResult {
                OperationResultView(result: result)
                if let message = model.managementMessage { Text(message).font(.caption).foregroundStyle(.orange) }
                HStack { Spacer(); Button("OK") { dismiss() }.keyboardShortcut(.defaultAction).accessibilityIdentifier("management.ok").controlHelp("Close the completed review and return to the inventory") }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Choose the actions to review").font(.headline)
                        Toggle("Force Quit", isOn: $forceQuit).disabled(model.managementTarget == nil).accessibilityIdentifier("management.forceQuit").pointingControl(enabled: model.managementTarget != nil && !model.managementWorking)
                        Text(model.managementTarget == nil ? "No safely verified running application was found." : "Stops the exact reviewed application process. Unsaved changes may be lost; helpers and services may remain. Quit normally from the application if you want to save first.").font(.caption).foregroundStyle(forceQuit ? .orange : .secondary)
                        Toggle("Clear App Data", isOn: $clearData).disabled(!candidates.contains(where: \.eligibleForTrash)).accessibilityIdentifier("management.clearData").pointingControl(enabled: candidates.contains(where: \.eligibleForTrash) && !model.managementWorking)
                        Text("Move individually selected application data to Trash. Preferences, sessions and saved login data may be lost.").font(.caption).foregroundStyle(.secondary)
                        if clearData {
                            Button("Select All Verified App Data") { selected = Set(candidates.filter(\.isAutomaticSelection).map(\.id)) }.controlHelp("Select only verified, eligible app data; possible and personal files require individual review")
                            ForEach(candidates) { candidate in DataCandidateRow(candidate: candidate, selected: selection(candidate), disabledReason: nil) }
                        }
                        if candidates.isEmpty, !model.managementPreparing { Text("No supported data locations were discovered. Personal folders can be nominated in Leftover Data.").font(.caption).foregroundStyle(.secondary) }
                        Toggle("Uninstall", isOn: $uninstall).disabled(!mayUninstall).accessibilityIdentifier("management.uninstall").pointingControl(enabled: mayUninstall && !model.managementWorking)
                        Text(model.managementUninstallPlan?.explanation ?? "Checking eligibility…").font(.caption).foregroundStyle(.secondary)
                        if let message = model.managementMessage { Text(message).font(.caption).foregroundStyle(.orange) }
                        if model.managementTarget != nil && !forceQuit { Text("Select Force Quit before cleaning data or uninstalling a running application, or quit it normally and reopen this dialog.").font(.caption).foregroundStyle(.secondary) }
                        if let plan = model.managementUninstallPlan, plan.canExecute {
                            Text(plan.operation).font(.caption)
                            if let executable = plan.executable { Text(([executable] + plan.arguments).joined(separator: " ")).font(.system(.caption2, design: .monospaced)).textSelection(.enabled) }
                        }
                        Divider()
                        Text("Review selected operations").font(.headline)
                        Text(actionTitle).fontWeight(.semibold)
                        if forceQuit, let target = model.managementTarget { Text("Process \(target.processIdentifier) · \(target.bundleID)\n\(target.bundleURL)").font(.caption).textSelection(.enabled) }
                        if clearData { ForEach(candidates.filter { selected.contains($0.id) }) { candidate in Text("Trash: " + candidate.path).font(.caption).textSelection(.enabled) } }
                        if uninstall { Text("Uninstall: " + (item.path ?? "Unavailable")).font(.caption).textSelection(.enabled) }
                        Text("Shared and protected data, unselected files, and personal folders remain untouched. Selected possible files may contain user-created work.").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 390).disabled(model.managementWorking)
                if model.managementPreparing { ProgressView("Discovering data and checking source ownership…").controlSize(.small) }
                if model.managementWorking {
                    ProgressView("Applying confirmed operations…").controlSize(.small)
                    Text("A submitted operation may still finish after cancellation is requested.").font(.caption).foregroundStyle(.secondary)
                } else { Toggle("I reviewed the selected operations, targets and warnings.", isOn: $acknowledged).accessibilityIdentifier("management.acknowledge").disabled(operations.isEmpty || model.managementPreparing).pointingControl(enabled: !operations.isEmpty && !model.managementPreparing) }
                HStack {
                    if model.managementWorking { Button("Request Cancellation") { model.cancelManagement() }.controlHelp("Stop before the next step; an operation already submitted may still complete") }
                    else { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).accessibilityIdentifier("management.cancel").controlHelp("Close without executing any operation") }
                    Spacer()
                    Button(actionTitle, role: .destructive) {
                        let request = ManagementRequest(item: item, identity: ApplicationIdentity(item: item), target: model.managementTarget, candidates: clearData ? candidates.filter { selected.contains($0.id) } : [], uninstallPlan: uninstall ? model.managementUninstallPlan : nil, operations: operations)
                        model.executeManagement(request, acknowledged: acknowledged)
                    }.disabled(!mayConfirm).accessibilityIdentifier("management.confirm").controlHelp("Revalidate and execute only the reviewed operations")
                }
            }
        }.padding(24).frame(width: 660)
            .background(NativeControlHelp().frame(width: 0, height: 0))
            .interactiveDismissDisabled(model.managementWorking)
            .onAppear { forceQuit = presentation.forceQuit && model.managementTarget != nil }
            .onChange(of: operations) { _ in acknowledged = false }
            .onChange(of: selected) { _ in acknowledged = false }
    }
    private func selection(_ candidate: AppDataCandidate) -> Binding<Bool> {
        Binding(get: { selected.contains(candidate.id) }, set: { enabled in if enabled { selected.insert(candidate.id) } else { selected.remove(candidate.id) } })
    }
}

struct OperationResultView: View {
    let result: ManagementResult
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.title).font(.headline).accessibilityIdentifier("operation.result.title")
            Text(result.explanation).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("operation.result.explanation")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(result.steps) { step in
                    let alreadyAbsent = !step.cleanupResults.isEmpty && step.cleanupResults.allSatisfy { $0.status == .alreadyRemoved }
                    Text(step.operation.rawValue + " — " + (alreadyAbsent ? "Already Removed" : step.status.rawValue.capitalized)).font(.callout).bold()
                    if result.steps.count > 1 || (step.status != .completed && step.cleanupResults.isEmpty) {
                        Text(step.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    ForEach(step.cleanupResults) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.simulated && item.status == .moved ? "Simulated Move" : item.status.rawValue).font(.caption).fontWeight(.semibold)
                            Text(item.candidate.path).font(.caption).textSelection(.enabled)
                            Text(item.message).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if result.steps.flatMap(\.cleanupResults).contains(where: { $0.status == .permissionDenied }) { CleanupPermissionHelp() }
        }
    }
}

struct CleanupPermissionHelp: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Check System Settings → Privacy & Security → Files and Folders for personal locations. Protected app data may require additional access. macOS can still refuse an operation; Macventory cannot grant itself permission.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Open System Settings") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app")) }.disabled(model.qaProtected).controlHelp(model.qaProtected ? "Opening system privacy settings is disabled in QA." : "Open System Settings to review access yourself.")
                Link("About macOS file access", destination: URL(string: "https://support.apple.com/guide/security/secddd1d86a6/web")!)
            }.font(.caption)
        }
    }
}

struct DataCandidateRow: View {
    let candidate: AppDataCandidate
    @Binding var selected: Bool
    var disabledReason: String?
    private var selectionBlockReason: String? {
        disabledReason ?? (candidate.eligibleForTrash ? nil : "This location is shared or protected and cannot be moved to Trash.")
    }
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle(candidate.category, isOn: $selected).labelsHidden().accessibilityLabel("Select " + candidate.path).pointingControl(enabled: selectionBlockReason == nil).disabled(selectionBlockReason != nil).controlHelp(selectionBlockReason ?? (candidate.requiresExplicitSelection ? "Select this possible related file individually after reviewing it in Finder." : "Select this verified app data."))
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.category + " · " + candidate.classificationTitle).font(.callout)
                Text(candidate.path).font(.caption).textSelection(.enabled)
                Text(candidate.explanation).font(.caption2).foregroundStyle(.secondary)
                if let selectionBlockReason { Text(selectionBlockReason).font(.caption2).foregroundStyle(.orange) }
                if let summary = candidate.contentsSummary { Text(summary).font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 6) {
                Text(candidate.sizeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) + (candidate.sizeComplete ? "" : " (partial)") } ?? "Size unavailable").font(.caption).foregroundStyle(.secondary)
                Button { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: candidate.path)]) } label: { Image(systemName: "magnifyingglass") }.buttonStyle(.borderless).controlHelp("Reveal this exact location in Finder for contents review")
            }
        }.padding(.vertical, 5)
    }
}
