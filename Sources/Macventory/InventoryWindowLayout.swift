import SwiftUI
import AppKit

/// Keep new and restored inventory windows inside their display's usable area.
struct InventoryWindowLayout: NSViewRepresentable {
    func makeNSView(context: Context) -> Reader {
        QAStartupDiagnostics.record("layout.reader.created")
        return Reader()
    }
    func updateNSView(_ view: Reader, context: Context) { view.constrainWindow() }

    final class Reader: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            QAStartupDiagnostics.record("layout.window.changed", ["attached": window != nil, "windowNumber": window?.windowNumber ?? -1])
            NotificationCenter.default.removeObserver(self)
            guard let window else { return }
            for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification, NSWindow.didChangeScreenNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(windowChanged), name: name, object: window)
            }
            NotificationCenter.default.addObserver(self, selector: #selector(windowChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
            constrainWindow()
        }
        @objc private func windowChanged(_ notification: Notification) { constrainWindow() }
        func constrainWindow() {
            // Defer until SwiftUI has installed the window's content constraints.
            DispatchQueue.main.async { [weak self] in
                guard let window = self?.window, let screen = window.screen ?? NSScreen.main else { return }
                let frame = Self.fittingFrame(window.frame, in: screen.visibleFrame)
                QAStartupDiagnostics.record("layout.constrain.before", ["proposed": NSStringFromRect(window.frame), "fitted": NSStringFromRect(frame)])
                if window.frame != frame { window.setFrame(frame, display: true) }
                QAStartupDiagnostics.record("layout.constrain.after")
            }
        }
        static func fittingFrame(_ proposed: NSRect, in visible: NSRect) -> NSRect {
            var frame = proposed
            frame.size.width = min(frame.width, visible.width)
            frame.size.height = min(frame.height, visible.height)
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
            return frame
        }
        deinit { NotificationCenter.default.removeObserver(self) }
    }
}
