import AppKit
import SwiftUI
import MacventoryCore

private struct CleanupPresentation: Identifiable {
    let id = UUID()
    let request: ManagementRequest
}

struct LeftoverDataView: View {
    @EnvironmentObject private var model: AppModel
    var onOpenScanningSettings: (() -> Void)? = nil
    @State private var groupID: String?
    @State private var search = ""
    @State private var confidence: AppDataClassification?
    @State private var grouping: LeftoverGroupingMode = .application
    @State private var showIssues = false
    @State private var selected = Set<String>()
    @State private var presentation: CleanupPresentation?
    @State private var manualGroup: AppDataDiscoveryResult?
    @State private var manualError: String?
    private var groups: [LeftoverPresentationGroup] {
        LeftoverPresentationGroup.make(from: model.leftoverGroups + [manualGroup].compactMap { $0 }, mode: grouping).filter { group in
            !group.candidates.isEmpty && (search.isEmpty || ([group.name, group.fallbackIdentifier ?? ""] + group.identities.flatMap { [$0.name, $0.bundleID ?? ""] } + group.candidates.map { $0.candidate.path }).joined(separator: "\n").localizedCaseInsensitiveContains(search)) && (confidence == nil || group.candidates.contains { $0.candidate.classification == confidence })
        }
    }
    private var group: LeftoverPresentationGroup? { groups.first { $0.id == groupID } }
    private var selectedReferences: [LeftoverCandidateReference] { group?.candidates.filter { selected.contains($0.id) && model.leftoverCleanupBlockReason(for: $0.candidate) == nil } ?? [] }
    private var selectedCandidates: [AppDataCandidate] { selectedReferences.map(\.candidate) }
    private var canClean: Bool { !selectedCandidates.isEmpty }
    private var verifiedCandidates: [LeftoverCandidateReference] { group?.candidates.filter { $0.candidate.isAutomaticSelection && model.leftoverCleanupBlockReason(for: $0.candidate) == nil } ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Leftover Data").font(.title2).bold()
                    Text("Discovered data for applications not currently found on this Mac. Uncertain ownership requires individual review.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if model.qaProtected { Label("Simulation only", systemImage: "shield.checkered").foregroundStyle(.blue) }
            }
            HStack {
                TextField("Search discovered names, identifiers or paths", text: $search).textFieldStyle(.roundedBorder).accessibilityIdentifier("leftovers.search")
                Picker("Group by", selection: $grouping) {
                    Text("Application").tag(LeftoverGroupingMode.application)
                    Text("Identifier").tag(LeftoverGroupingMode.identifier)
                }.frame(width: 180).accessibilityIdentifier("leftovers.grouping")
                Picker("Confidence", selection: $confidence) { Text("All confidence levels").tag(nil as AppDataClassification?); ForEach(AppDataClassification.allCases, id: \.self) { Text($0.title).tag(Optional($0)) } }.frame(width: 255)
                if model.leftoverScanState == .scanning { Button("Cancel Scan") { model.cancelLeftoverScan() }.controlHelp("Cancel discovery and retain previous observations as stale") }
                else { Button("Scan Supported Locations") { refresh() }.accessibilityIdentifier("leftovers.refresh").controlHelp("Refresh Library candidates, sizes and ownership evidence") }
            }
            HStack {
                Button("Choose File or Folder…") { chooseManual() }.controlHelp("Nominate a personal folder for explicit individual review; it is never automatically selected")
                Text(status).font(.caption).foregroundStyle(.secondary)
                if model.leftoverScanState == .scanning { ProgressView().controlSize(.small) }
            }
            HStack {
                Text(model.configuration.discoverPersonalFolders ? "Personal folder suggestions are enabled. Select a folder itself to move the whole folder and its contents." : "Documents, Downloads and Desktop discovery is off. Those folders are not included unless you enable it or choose one manually.").font(.caption).foregroundStyle(.secondary)
                if let onOpenScanningSettings { Button("Scanning Settings…", action: onOpenScanningSettings) }
            }
            if !model.leftoverMessages.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Some locations couldn't be scanned.").font(.callout).fontWeight(.semibold)
                    Text("Cleanup may be unavailable for affected files until their ownership can be verified.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(showIssues ? "Hide Scan Issues" : "View Scan Issues") { showIssues.toggle() }
                        Button("Retry Failed Locations") { refresh() }.disabled(model.leftoverScanState == .scanning)
                    }
                    if showIssues {
                        ForEach(model.leftoverIssues) { issue in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.location).font(.caption).fontWeight(.semibold)
                                Text(issue.reason).font(.caption).textSelection(.enabled)
                                Text(issue.permissionDenied ? "Permission may be required. Retry is available." : issue.retryable ? "Retry is available." : "This location cannot be retried automatically.").font(.caption2).foregroundStyle(.secondary)
                            }.padding(.leading, 8)
                        }
                        ForEach(model.leftoverMessages.filter { message in !model.leftoverIssues.contains(where: { $0.message == message }) }, id: \.self) { Text($0).font(.caption).textSelection(.enabled) }
                    }
                }.padding(10).background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }
            if let manualError { Text(manualError).font(.caption).foregroundStyle(.orange) }
            HSplitView {
                List(selection: $groupID) {
                    ForEach(groups) { result in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                if let path = result.identities.first?.installationPath, FileManager.default.fileExists(atPath: path) { AppIcon(path: path, demoSymbol: nil).frame(width: 18, height: 18) }
                                Text(result.name).lineLimit(1)
                            }
                            if let identifier = result.fallbackIdentifier, identifier != result.name { Text(identifier).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                            Text("Not Installed · \(result.candidates.count) candidate(s) · " + ByteCountFormatter.string(fromByteCount: result.measuredSize, countStyle: .file) + (result.hasIncompleteSize ? " (partial)" : "")).font(.caption2).foregroundStyle(.secondary)
                            Text(result.highestClassification.title).font(.caption2).foregroundStyle(result.highestClassification == .protected ? .orange : .secondary)
                        }.tag(result.id).pointingControl()
                    }
                }.frame(minWidth: 200, idealWidth: 230, maxWidth: 300).accessibilityIdentifier("leftovers.groups")
                VStack(alignment: .leading, spacing: 10) {
                    if let group {
                        Text(group.name).font(.headline)
                        Text(group.fallbackIdentifier ?? (group.identities.count == 1 ? group.identities[0].bundleID ?? "Manually nominated location" : "\(group.identities.count) independently classified identifiers")).font(.caption).textSelection(.enabled)
                        Text("Application not currently found · ownership must still be reviewed").font(.caption).foregroundStyle(.secondary)
                        if let identity = group.identities.first {
                            if identity.name == identity.bundleID {
                                Text("The original application name could not be determined. Similar identifiers are kept separate unless a relationship is known.").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Name: " + (identity.namingSource ?? "Local removal record or application metadata") + ". Naming does not verify file ownership.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(group.candidates.filter { confidence == nil || $0.candidate.classification == confidence }) { reference in
                                    DataCandidateRow(candidate: reference.candidate, selected: Binding(get: { selected.contains(reference.id) }, set: { if $0 { selected.insert(reference.id) } else { selected.remove(reference.id) } }), disabledReason: model.leftoverCleanupBlockReason(for: reference.candidate))
                                    if let message = model.leftoverItemMessages[reference.id] {
                                        Text(message).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                                        if message.hasPrefix(AppDataItemStatus.permissionDenied.rawValue) { CleanupPermissionHelp() }
                                    }
                                    if group.identities.count > 1 { Text(reference.identity.bundleID ?? reference.identity.name).font(.caption2).foregroundStyle(.secondary).padding(.leading, 28) }
                                    Divider()
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "externaldrive.badge.questionmark").font(.largeTitle).foregroundStyle(.secondary)
                            Text(model.leftoverScanState == .scanning ? "Looking for application data…" : groups.isEmpty ? "No matching leftover data" : "Select a discovered group").font(.headline)
                            Text(model.leftoverScanState == .completed ? "Removal history alone does not create an actionable cleanup group." : "Candidates from incomplete scans remain visible but require a complete refresh before cleanup.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }.padding(12).frame(minWidth: 430)
            }.frame(minHeight: 250)
            Divider()
            HStack {
                Button("Select All Verified Data") { selected = Set(verifiedCandidates.map(\.id)) }.disabled(verifiedCandidates.isEmpty).controlHelp(verifiedCandidates.isEmpty ? "No verified, independently eligible data is available in this group." : "Select only verified, eligible app data; possible and protected files are excluded.")
                Text("\(selectedCandidates.count) selected · " + ByteCountFormatter.string(fromByteCount: selectedCandidates.compactMap(\.sizeBytes).reduce(0, +), countStyle: .file)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { reviewCleanup() } label: { Label("Move Selected to Trash", systemImage: "trash") }.disabled(!canClean).accessibilityIdentifier("leftovers.trash").controlHelp(canClean ? "Review the exact paths and confirm before moving data to Trash" : "Select eligible files after a complete scan to review cleanup")
            }
        }.padding(22)
            .background(NativeControlHelp().frame(width: 0, height: 0))
            .task { if model.leftoverScanState == .notScanned { await model.reloadLeftoverRecords(); model.refreshLeftovers() } }
            .onChange(of: groupID) { _ in selected = [] }
            .onChange(of: grouping) { _ in selected = []; groupID = nil }
            .onChange(of: confidence) { _ in selected = [] }
            .onChange(of: search) { _ in selected = [] }
            .onChange(of: model.leftoverScanState) { state in if state != .scanning { selected = []; if !groups.contains(where: { $0.id == groupID }) { groupID = nil } } }
            .sheet(item: $presentation) { review in CleanupReviewView(request: review.request, onFinish: { manualGroup = nil; selected = []; model.refreshLeftovers() }) }
    }
    private var status: String {
        switch model.leftoverScanState {
        case .notScanned: "Not yet scanned"
        case .scanning: "Scan in progress"
        case .completed: "Scan completed · \(model.leftoverGroups.count) groups with candidates"
        case .partial: "Some locations couldn't be scanned"
        case .failed: "Scan failed · previous observations may be stale"
        case .cancelled: "Scan cancelled · refresh before cleanup"
        }
    }
    private func refresh() { selected = []; manualGroup = nil; model.refreshLeftovers() }
    private func reviewCleanup() {
        guard canClean, let group else { return }
        let identities = Dictionary(uniqueKeysWithValues: selectedReferences.map { ($0.id, $0.identity) })
        let primary = group.identities.first ?? ApplicationIdentity(name: group.name, bundleID: nil, evidence: "Manual review", installed: false)
        presentation = CleanupPresentation(request: ManagementRequest(item: nil, identity: primary, candidates: selectedCandidates, candidateIdentities: identities, operations: [.clearData]))
    }
    private func chooseManual() {
        guard !model.fixtureMode else { manualError = "Manual file picking is disabled in isolated QA. Synthetic personal-folder selection is covered by fixture tests."; return }
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = true; panel.canCreateDirectories = false
        panel.begin { response in
            guard response == .OK else { return }
            let paths = panel.urls.map(\.path), service = model.dataDiscoveryService
            Task {
                let candidates = await Task.detached(priority: .utility) { paths.compactMap { service.manualCandidate(path: $0) } }.value
                guard !candidates.isEmpty else { manualError = "These locations are protected, linked, inaccessible or too broad. Choose an individual personal file or subfolder."; return }
                let identity = ApplicationIdentity(name: "Personal files — manual review", bundleID: nil, evidence: "Explicit user nomination; ownership unverified", installed: false)
                manualGroup = AppDataDiscoveryResult(identity: identity, candidates: candidates); groupID = identity.id; selected = []
            }
        }
    }
}

private struct CleanupReviewView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let request: ManagementRequest
    let onFinish: () -> Void
    @State private var acknowledged = false
    @State private var working = false
    @State private var result: ManagementResult?
    @State private var execution: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clear App Data — \(request.identity.name)").font(.title2).bold()
            if let result {
                OperationResultView(result: result)
                HStack { Spacer(); Button("OK") { onFinish(); dismiss() }.keyboardShortcut(.defaultAction).accessibilityIdentifier("cleanup.ok").controlHelp("Close this result and refresh the leftover candidates once") }
            } else {
                if model.qaProtected { Label("Simulation only — no data will be moved.", systemImage: "shield.checkered").foregroundStyle(.blue) }
                Text("Move these selected locations to Trash. Preferences, sessions, saved logins and personal files inside selected folders may be lost.").font(.callout)
                Text("Selected folders are moved whole, including their contents. Parent folders and unselected locations are retained.").font(.caption).foregroundStyle(.secondary)
                ScrollView { VStack(alignment: .leading, spacing: 12) { ForEach(request.candidates) { candidate in
                    Text(candidate.path).font(.callout).textSelection(.enabled)
                    Text(candidate.classification.title + ": " + candidate.explanation).font(.caption).foregroundStyle(.secondary)
                } } }.frame(maxHeight: 260)
                Text("Unselected locations, shared/protected data and the application bundle remain untouched. Trash restoration is managed in Finder; this operation cannot guarantee a full rollback.").font(.caption).foregroundStyle(.secondary)
                if working { ProgressView("Applying selected cleanup…").controlSize(.small) }
                else { Toggle("I reviewed every selected path and its contents.", isOn: $acknowledged).accessibilityIdentifier("cleanup.acknowledge").pointingControl() }
                HStack {
                    if working { Button("Request Cancellation") { execution?.cancel() }.controlHelp("A submitted Trash request may still finish") }
                    else { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
                    Spacer()
                    Button(role: .destructive) {
                        guard !working, result == nil, acknowledged else { return }; working = true
                        execution = Task { result = await model.cleanupLeftovers(request); working = false }
                    } label: { Label("Move Selected to Trash", systemImage: "trash") }.disabled(!acknowledged || working).accessibilityIdentifier("cleanup.confirm").controlHelp("Revalidate and execute the reviewed cleanup")
                }
            }
        }.padding(24).frame(width: 640).background(NativeControlHelp().frame(width: 0, height: 0)).interactiveDismissDisabled(working)
    }
}
