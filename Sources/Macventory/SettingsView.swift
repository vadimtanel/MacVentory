import SwiftUI
import AppKit
import MacventoryCore

struct SettingsView: View {
    // Reserve space for window chrome and sheet attachment above the usable display.
    // On compact screens a fixed 680-point sheet puts Done/Cancel behind the Dock.
    static var presentationHeight: CGFloat {
        min(680, max(560, (NSScreen.main?.visibleFrame.height ?? 780) - 100))
    }

    @EnvironmentObject private var model: AppModel
    var onClose: (() -> Void)? = nil
    @State private var selectedTab = 0
    @State private var transaction = SettingsDraft()
    @State private var validationError: String?
    @State private var hostingWindow: NSWindow?
    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings page", selection: $selectedTab) {
                Text("General").tag(0); Text("Scanning").tag(1)
                Text("Discovery").tag(2); Text("Information").tag(3)
            }.pickerStyle(.segmented).labelsHidden().accessibilityLabel("Settings page").padding(.horizontal, 24).padding(.vertical, 18)
                .controlHelp("Choose a settings page").accessibilityIdentifier("settings.pages")
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedTab {
                    case 1: scanning
                    case 2: discovery
                    case 3: information
                    default: general
                    }
                }.frame(maxWidth: .infinity, alignment: .topLeading).padding(24)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Divider()
            HStack {
                if let validationError { Text(validationError).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("settings.validation") }
                Spacer()
                Button("Cancel") { finish(commit: false) }.accessibilityIdentifier("settings.cancel").keyboardShortcut(.cancelAction).controlHelp("Discard pending settings changes")
                Button("Done") { finish(commit: true) }.accessibilityIdentifier("settings.done").keyboardShortcut(.defaultAction).controlHelp("Validate and save settings; scan once if discovery locations changed")
            }.padding(16)
        }.frame(minWidth: 700, minHeight: 560, alignment: .top)
            .preferredColorScheme(model.configuration.appearance == "dark" ? .dark : model.configuration.appearance == "light" ? .light : nil)
            .onAppear { transaction = SettingsDraft(model.configuration); validationError = nil }
            .onDisappear { transaction.cancel() }
            .background(SettingsWindowReader { if hostingWindow !== $0 { hostingWindow = $0 } }.frame(width: 0, height: 0))
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                if let window = notification.object as? NSWindow, window === hostingWindow { transaction = SettingsDraft(model.configuration); validationError = nil }
            }
    }
    private func finish(commit: Bool) {
        if commit {
            do { try model.applySettings(transaction.commit()) }
            catch { validationError = error.localizedDescription; return }
        } else { transaction.cancel() }
        if let onClose { onClose() } else { hostingWindow?.performClose(nil) }
    }
    private var general: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("General", "Choose how your inventory looks and which software appears.")
            SettingToggle("Show system applications", "Include protected macOS applications in the inventory. This does not allow their removal.", value: $transaction.value.showSystem)
            SettingToggle("Hide sources not installed", "Keep the sidebar focused on installation sources available on this Mac.", value: $transaction.value.hideAbsent)
            SettingRow("Appearance", "Follow macOS or choose a fixed appearance.") {
                Picker("Appearance", selection: $transaction.value.appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }.labelsHidden().controlHelp("Choose System, Light or Dark appearance")
            }
            SettingRow("Default sorting", "The initial sort for a new inventory window. Click table headers to change it while browsing.") {
                Picker("Default sorting", selection: $transaction.value.defaultSort) {
                    Text("Name").tag("name"); Text("Version").tag("version"); Text("Source").tag("source"); Text("Size").tag("size"); Text("Installed").tag("installed"); Text("Last Opened").tag("opened")
                }.labelsHidden().controlHelp("Choose the initial inventory sort column")
            }
            note("Your inventory stays on this Mac. Discovery only reads software metadata. Uninstall is a separate action with its own reviewed confirmation.")
        }
    }
    private var scanning: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Scanning", "Choose when to refresh and where to look. Done saves changes and refreshes once when scan locations change.")
            SettingToggle("Scan on launch", "Automatically refresh the software inventory when Macventory opens.", value: $transaction.value.scanOnLaunch)
            SettingToggle("Discover external application and Steam libraries", "Include supported application folders and Steam library paths on mounted external volumes, when present.", value: $transaction.value.externalVolumes)
            SettingRow("Additional app directories", "Extra local folders to search for application bundles. Enter one directory per line.") {
                TextField("Additional app directories", text: pathList(\.customAppDirectories, separator: "\n"), axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder).controlHelp("Extra local application directories, one per line")
            }
            SettingRow("Homebrew prefixes", "Local Homebrew installation roots used to discover formulae and casks. Separate multiple roots with commas.") {
                TextField("Homebrew prefixes", text: pathList(\.homebrewPrefixes, separator: ",")).textFieldStyle(.roundedBorder).controlHelp("Homebrew roots such as /opt/homebrew and /usr/local")
            }
            SettingRow("MacPorts executable", "Path to the local port tool, if MacPorts is installed. Macventory uses read-only queries.") {
                TextField("MacPorts executable", text: $transaction.value.macPortsExecutable).textFieldStyle(.roundedBorder).controlHelp("Local MacPorts port executable path")
            }
            SettingRow("Nix executable", "Path to the local nix tool, if Nix is installed. Only supported current-user profiles are queried.") {
                TextField("Nix executable", text: $transaction.value.nixExecutable).textFieldStyle(.roundedBorder).controlHelp("Local Nix executable path")
            }
            SettingRow("Additional Toolbox app roots", "Extra local folders to check for supported JetBrains Toolbox installation layouts. A folder or IDE name alone does not prove ownership. Separate roots with commas.") {
                TextField("Additional Toolbox app roots", text: pathList(\.additionalProviderRoots, separator: ",")).textFieldStyle(.roundedBorder).controlHelp("Additional local Toolbox application roots, comma separated")
            }
            note("Locations must be readable local paths. Macventory does not install package managers, request administrator access or bypass macOS privacy protections.")
        }
    }
    private var discovery: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Discovery", "Set the thresholds used by the smart views. These views help you review software; they never remove it.")
            SettingRow("Recently Installed", "Software with a verified installation event within this many days. File creation dates are not used as installation dates.") {
                DaysInput(title: "Recently installed threshold", value: $transaction.value.recentlyInstalledDays, range: 1...365)
            }
            SettingRow("Possibly Unused", "Software whose last recorded opening is older than this many days. The observation may be incomplete; review it before deciding what to keep.") {
                DaysInput(title: "Possibly unused threshold", value: $transaction.value.unusedDays, range: 1...3650)
            }
            SettingRow("Large Applications", "Applications at or above this logical payload size. External files, personal data and shared dependencies are not included.") {
                Picker("Large application threshold", selection: $transaction.value.largeBytes) {
                    Text("500 MB").tag(Int64(500_000_000)); Text("1 GiB").tag(Int64(1_073_741_824)); Text("5 GiB").tag(Int64(5_368_709_120)); Text("10 GiB").tag(Int64(10_737_418_240))
                }.labelsHidden().controlHelp("Choose the logical size threshold for Large Applications")
            }
            note("Missing last-opened information never counts as unused. Size is informational and is not guaranteed reclaimable space. Discovery is read-only; uninstall requires a separate, explicit confirmation.")
        }
    }
    private var information: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Information", "Review source availability and scanner results, export sanitized diagnostics, or maintain Macventory’s saved inventory.")
            VStack(alignment: .leading, spacing: 10) {
                Text("Scanner status").font(.headline)
                Text("Not Installed, Empty, Unsupported and Failed describe different outcomes. A failed source does not mean no software is installed.").font(.callout).foregroundStyle(.secondary)
                if model.reports.isEmpty { Text("No scanner results yet. Refresh Inventory to check available sources.").foregroundStyle(.secondary) }
                ForEach(model.reports.sorted { $0.source.title < $1.source.title }) { report in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(report.source.title).fontWeight(.medium); Spacer(); Text(report.state.title).foregroundStyle(.secondary) }
                        if !report.message.isEmpty { Text(report.message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                        Divider()
                    }
                }
            }
            SettingRow("Sanitized diagnostics", "Exports source status and counts only. Application names, paths, identifiers and raw errors are excluded. Nothing is uploaded.") {
                Button("Export Sanitized Diagnostics…") { model.exportDiagnostics() }.controlHelp("Save only source counts and status")
            }
            SettingRow("Inventory cache", "Clears Macventory’s saved inventory snapshot. Installed applications, packages and personal files are untouched. Refresh to rebuild the inventory.") {
                Button("Clear Inventory Cache") { model.clearCache() }.disabled(model.scanning || model.fixtureMode).controlHelp(model.fixtureMode ? "Cache maintenance is disabled in isolated demo and test modes" : model.scanning ? "Wait for the current scan to finish" : "Clear only Macventory’s cached inventory")
            }
        }
    }
    private func pathList(_ key: WritableKeyPath<ScanConfiguration, [String]>, separator: String) -> Binding<String> {
        Binding(get: { transaction.value[keyPath: key].joined(separator: separator == "," ? ", " : separator) }, set: { transaction.value[keyPath: key] = SettingsInput.paths($0, separator: separator) })
    }
    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.title2).bold(); Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
    }
    private func note(_ text: String) -> some View { Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.top, 4) }
}

private struct SettingRow<Control: View>: View {
    let title: String
    let explanation: String
    @ViewBuilder var control: () -> Control
    init(_ title: String, _ explanation: String, @ViewBuilder control: @escaping () -> Control) { self.title = title; self.explanation = explanation; self.control = control }
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 5) { Text(title).fontWeight(.medium); Text(explanation).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth: .infinity, alignment: .leading)
            control().frame(width: 290, alignment: .leading).accessibilityHint(explanation)
        }
    }
}
private struct SettingToggle: View {
    let title: String
    let explanation: String
    @Binding var value: Bool
    init(_ title: String, _ explanation: String, value: Binding<Bool>) { self.title = title; self.explanation = explanation; _value = value }
    var body: some View { SettingRow(title, explanation) { HStack { Spacer(); Toggle(title, isOn: $value).labelsHidden().toggleStyle(.switch).controlHelp(explanation) } } }
}
private struct DaysInput: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    private var bounded: Binding<Int> { Binding(get: { value }, set: { value = SettingsInput.days($0, within: range) }) }
    var body: some View {
        HStack(spacing: 8) {
            TextField(title, value: bounded, format: .number.grouping(.never)).frame(width: 70).textFieldStyle(.roundedBorder).accessibilityLabel(title).controlHelp("Type a whole number from \(range.lowerBound) to \(range.upperBound)")
            Text("days").foregroundStyle(.secondary)
            Stepper(title, value: bounded, in: range).labelsHidden().accessibilityLabel("Adjust " + title).controlHelp("Increase or decrease the number of days")
        }.fixedSize()
    }
}

private struct SettingsWindowReader: NSViewRepresentable {
    let receive: (NSWindow) -> Void
    func makeNSView(context: Context) -> Reader { let view = Reader(); view.receive = receive; return view }
    func updateNSView(_ view: Reader, context: Context) { view.receive = receive; view.deliver() }
    final class Reader: NSView {
        var receive: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); deliver() }
        func deliver() { DispatchQueue.main.async { [weak self] in if let self, let window = self.window { self.receive?(window) } } }
    }
}
