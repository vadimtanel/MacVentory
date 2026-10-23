import SwiftUI
import AppKit
import MacventoryCore

@main
struct MacventoryApp: App {
    @NSApplicationDelegateAdaptor(MacventoryAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            InventoryView().environmentObject(model)
                .preferredColorScheme(model.configuration.appearance == "dark" ? .dark : model.configuration.appearance == "light" ? .light : nil)
                .frame(minWidth: 1050, minHeight: 620)
        }
        .defaultSize(width: 1320, height: 820)
        .commands {
            CommandGroup(replacing: .appInfo) { Button("About Macventory") { showAbout(appearance: model.configuration.appearance) } }
            CommandGroup(after: .newItem) { Button("Refresh Inventory") { model.refresh() }.keyboardShortcut("r").disabled(model.scanning).help("Refresh Inventory") }
        }
        Settings { SettingsView().environmentObject(model).frame(width: 760, height: SettingsView.presentationHeight) }
    }
}

