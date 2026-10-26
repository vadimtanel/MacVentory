import SwiftUI
import AppKit
import MacventoryCore

struct DetailsView: View {
    var onUninstall: () -> Void
    @EnvironmentObject private var model: AppModel
    let item: SoftwareItem
    let unusedDays: Int
    var body: some View {
        VStack(spacing: 0) { metadata }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { actionButtons }
                    VStack(alignment: .leading, spacing: 8) { actionButtons }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.bar)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("inventory.details.actions")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("inventory.details")
    }
    private var metadata: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack { AppIcon(path: item.path, demoSymbol: item.attributes["Demo symbol"]); Text(item.name).font(.title2).bold().accessibilityIdentifier("inventory.details.title") }
                InstallationHealthBadge(item: item, showLabel: true)
                field("Installation Status", item.installationHealth.explanation)
                field("Manager State", item.installationHealth.registration.rawValue)
                ForEach(item.installationHealth.artifacts, id: \.path) { artifact in field("Expected Artifact · " + artifact.presence.rawValue, artifact.path) }
                field("Status Verified", item.installationHealth.checkedAt.formatted())
                if item.stale { Label("Cached / Stale", systemImage: "clock").foregroundStyle(.orange) }
                Group {
                    field("Version", item.version ?? "Not Available")
                    field("Kind", item.kind.rawValue.capitalized)
                    field("Developer / Vendor", item.vendor ?? "Not Available")
                    field("Bundle Identifier", item.bundleID ?? "Not Available")
                    field("Package Identifier", item.packageID ?? "Not Available")
                    field("Primary Source", item.primarySource.title + " · " + item.confidence.rawValue.capitalized)
                    field("Installation Path", item.path ?? "Not Available")
                }
                Group {
                    field("Size", Display.size(item) + "\n" + item.sizeMetric)
                    field("Installed", Display.date(item.installedAt, item: item, field: "installedAt"))
                    field("Updated", Display.date(item.updatedAt, item: item, field: "updatedAt"))
                    field("File Created", Display.date(item.fileCreatedAt, item: item, field: "fileCreatedAt") + "\nNot an installation date")
                    field("File Modified", item.fileModifiedAt?.formatted() ?? "Not Available")
                    field("Last Opened", Display.date(item.lastOpenedAt, item: item, field: "lastOpenedAt"))
                    field("Last Refreshed", item.scannedAt.formatted())
                }
                if let opened = item.lastOpenedAt, !item.isSystem, (item.kind == .app || item.kind == .game), opened < Date().addingTimeInterval(-Double(unusedDays) * 86400) {
                    Label("Possibly unused: last recorded opening exceeds \(unusedDays) days. Usage observations may be incomplete.", systemImage: "clock.badge.questionmark").font(.callout)
                }
                Divider()
                Text("Source Evidence").font(.headline)
                ForEach(Array(item.sources.enumerated()), id: \.offset) { _, source in
                    field(source.source.title + " · " + source.evidence.confidence.rawValue.capitalized, source.evidence.origin + "\n" + source.evidence.explanation)
                }
                DisclosureGroup("Metadata Evidence") {
                    ForEach(item.evidence.keys.sorted(), id: \.self) { key in
                        if let evidence = item.evidence[key] { field(key, evidence.origin + " · " + evidence.confidence.rawValue + "\n" + evidence.availability.title + "\n" + evidence.explanation) }
                    }
                }
                ForEach(item.attributes.keys.sorted(), id: \.self) { key in field(key, item.attributes[key] ?? "Unknown") }
                ForEach(item.sources, id: \.self) { source in
                    if let report = model.reports.first(where: { $0.source == source.source }) { field(source.source.title + " Scanner", report.state.title + (report.message.isEmpty ? "" : "\n" + report.message)) }
                }
            }.padding(20).textSelection(.enabled)
        }.accessibilityIdentifier("inventory.details.scroll")
    }
    @ViewBuilder
    private var actionButtons: some View {
        if let path = item.path {
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }.controlHelp("Reveal in Finder")
            Button("Copy Path") { Display.copy(path) }.controlHelp("Copy Installation Path")
        }
        Button("Copy Identifier") { Display.copy(item.bundleID ?? item.packageID ?? item.id) }.controlHelp("Copy Software Identifier")
        Button("Refresh Installation Status") { model.refresh() }.disabled(model.scanning).controlHelp("Refresh source ownership, manager state and expected artifacts")
        Button("Uninstall…", role: .destructive) { onUninstall() }.disabled(model.scanning || model.uninstallWorking).accessibilityIdentifier("inventory.uninstall").controlHelp(model.scanning ? "Wait for the scan to finish before preparing uninstall" : "Uninstall Selected Application").accessibilityHint("Review the exact application and removal plan. No removal occurs until confirmed.")
    }
    private func field(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.callout).fixedSize(horizontal: false, vertical: true) }
    }
}

struct InstallationHealthBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: SoftwareItem
    var showLabel = false
    private var health: InstallationHealth { item.installationHealth }
    private var tint: Color {
        switch health.status {
        case .attention, .partial: .orange
        case .protected: .red
        case .verified: colorScheme == .dark ? Color(red: 0.36, green: 0.78, blue: 0.52) : Color(red: 0.12, green: 0.50, blue: 0.28)
        case .unverified, .historical: .secondary
        }
    }
    var body: some View {
        Group {
            if showLabel { Label(health.status.title, systemImage: health.status.symbol) }
            else { Image(systemName: health.status.symbol) }
        }.foregroundStyle(tint)
            .help(health.status.title + ": " + health.explanation)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(health.status.title)
            .accessibilityValue(health.explanation)
            .accessibilityIdentifier("health." + health.status.rawValue)
    }
}
