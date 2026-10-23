import SwiftUI
import MacventoryCore

struct UninstallView: View {
    @EnvironmentObject private var model: AppModel
    let plan: UninstallPlan
    @State private var review: UninstallReviewState
    init(plan: UninstallPlan) { self.plan = plan; _review = State(initialValue: UninstallReviewState(planID: plan.id)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                AppIcon(path: plan.item.path, demoSymbol: plan.item.attributes["Demo symbol"])
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.item.name).font(.title2).bold().fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    Text("Version: \(plan.item.version ?? "Not Available") · \(plan.item.primarySource.title)").foregroundStyle(.secondary)
                }
            }
            if model.qaProtected { Label("Simulation only — no files or packages will be removed.", systemImage: "shield.checkered").foregroundStyle(.blue) }
            if let outcome = model.uninstallOutcome {
                Text(outcome.completionMessage).fixedSize(horizontal: false, vertical: true).textSelection(.enabled).accessibilityIdentifier("uninstall.result")
                HStack {
                    Spacer()
                    Button("OK") { model.cancelUninstall() }.keyboardShortcut(.defaultAction).accessibilityIdentifier("uninstall.ok").controlHelp("Close the completed operation")
                }
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Installed path").font(.headline)
                        Text(plan.item.path ?? "Not Available").font(.callout).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    }
                    Text(plan.operation).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
                    Text(plan.explanation).fixedSize(horizontal: false, vertical: true)
                    if plan.canExecute {
                        Text("User data, preferences and dependencies are retained. No force, zap or automatic cleanup. Cancellation after an operation starts cannot guarantee rollback.").font(.callout).foregroundStyle(.secondary)
                    }
                    if let executable = plan.executable {
                        DisclosureGroup("Operation details") {
                            Text(([executable] + plan.arguments).joined(separator: "\n")).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 320)
            if plan.canExecute {
                Toggle("I reviewed the application and want to uninstall it.", isOn: $review.acknowledged)
                    .accessibilityIdentifier("uninstall.acknowledge").controlHelp("Confirm only the application and operation shown in this preview")
                    .disabled(model.uninstallWorking || model.uninstallMessage != nil)
            }
            if model.uninstallWorking { ProgressView("Uninstall in progress…").controlSize(.small) }
            if let message = model.uninstallMessage { Text(message).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("uninstall.result") }
            HStack {
                Button(model.uninstallWorking ? "Request cancellation" : "Cancel") { model.cancelUninstall() }.keyboardShortcut(.cancelAction).controlHelp("Close without starting removal; cancellation of an active operation is best effort")
                Spacer()
                Button("Uninstall", role: .destructive) { model.confirmUninstall(plan, acknowledged: review.acknowledged) }
                    .disabled(!plan.canExecute || !review.acknowledged || review.planID != plan.id || model.uninstallWorking || model.uninstallMessage != nil)
                    .accessibilityIdentifier("uninstall.confirm").controlHelp(model.qaProtected ? "Simulate only; no installed software will be changed" : "Revalidate this exact plan and uninstall the reviewed application")
            }
            }
        }.padding(24).frame(width: 570)
            .onExitCommand { if model.uninstallOutcome != nil { model.cancelUninstall() } }
            .onChange(of: plan.id) { review.reset(for: $0) }
    }
}
