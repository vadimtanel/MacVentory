import SwiftUI
import AppKit
import MacventoryCore

struct AboutView: View {
    let appearance: String
    var body: some View {
        VStack(spacing: 16) {
            if let icon = BrandAssets.applicationIcon {
                Image(nsImage: icon).resizable().frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).accessibilityHidden(true)
            }
            VStack(spacing: 6) {
                Text("Macventory").font(.largeTitle).bold()
                Text("Version " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Not Available")).foregroundStyle(.secondary)
                Text("Know what’s on your Mac.")
            }
            Divider()
            Text("Created by Vadim Tanel").fontWeight(.medium)
            Text("Copyright © 2026 Vadim Tanel\nLicensed under Apache License 2.0").font(.callout).multilineTextAlignment(.center).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                Link(destination: AppLinks.linkedIn) { Label("LinkedIn", systemImage: "person.crop.square") }.controlHelp("Open Vadim Tanel’s LinkedIn profile")
                Link(destination: AppLinks.githubProfile) { Label("GitHub Profile", systemImage: "chevron.left.forwardslash.chevron.right") }.controlHelp("Open Vadim Tanel’s GitHub profile")
                Link(destination: AppLinks.projectRepository) { Label("Macventory Repository", systemImage: "folder.badge.gearshape") }.controlHelp("Open the official Macventory repository on GitHub")
            }
            Text("Local inventory. No accounts or telemetry.").font(.caption).foregroundStyle(.secondary)
        }.padding(28).frame(width: 370)
            .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
    }
}
@MainActor
private enum AboutWindow {
    static var controller: NSWindowController?
}
@MainActor
func showAbout(appearance: String = "system") {
    let theme: NSAppearance? = appearance == "dark" ? NSAppearance(named: .darkAqua) : appearance == "light" ? NSAppearance(named: .aqua) : nil
    if let controller = AboutWindow.controller, let window = controller.window {
        window.appearance = theme
        window.contentView = NSHostingView(rootView: AboutView(appearance: appearance))
        controller.showWindow(nil); window.makeKeyAndOrderFront(nil); return
    }
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 426, height: 500), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.appearance = theme
    window.title = "About Macventory"; window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: AboutView(appearance: appearance)); window.center()
    let controller = NSWindowController(window: window); AboutWindow.controller = controller
    controller.showWindow(nil); window.makeKeyAndOrderFront(nil)
}
