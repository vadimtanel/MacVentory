import SwiftUI
import AppKit
import MacventoryCore

@main
struct MacventoryApp: App {
    @NSApplicationDelegateAdaptor(MacventoryAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    init() {
        let mode = InventoryRunMode(arguments: ProcessInfo.processInfo.arguments,
                                    qaBundle: Bundle.main.object(forInfoDictionaryKey: "MacventoryQABundle") as? Bool == true)
        QAStartupDiagnostics.start(isolated: mode.isolated)
        QAStartupDiagnostics.record("app.init")
    }
    var body: some Scene {
        let _ = QAStartupDiagnostics.record("scene.body")
        WindowGroup {
            InventoryView().environmentObject(model)
                .preferredColorScheme(model.configuration.appearance == "dark" ? .dark : model.configuration.appearance == "light" ? .light : nil)
                .frame(minWidth: 900, minHeight: 520)
                .background(InventoryWindowLayout().frame(width: 0, height: 0))
        }
        .defaultSize(width: min(1320, NSScreen.main?.visibleFrame.width ?? 1320),
                     height: min(820, (NSScreen.main?.visibleFrame.height ?? 848) - 28))
        .commands {
            CommandGroup(replacing: .appInfo) { Button("About Macventory") { showAbout(appearance: model.configuration.appearance) } }
            CommandGroup(after: .newItem) { Button("Refresh Inventory") { model.refresh() }.keyboardShortcut("r").disabled(model.scanning).help("Refresh Inventory") }
            CommandGroup(after: .textEditing) {
                Button("Find Software") { InventorySearchField.focus(in: NSApp.keyWindow) }
                    .keyboardShortcut("f")
            }
        }
        Settings { SettingsView().environmentObject(model).frame(width: 760, height: SettingsView.presentationHeight) }
    }
}

