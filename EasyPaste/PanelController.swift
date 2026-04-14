import AppKit
import SwiftUI

final class PanelController {
    private let panel: EasyPastePanel

    var isVisible: Bool {
        panel.isVisible
    }

    init<Content: View>(rootView: Content) {
        let hostingController = NSHostingController(rootView: rootView)
        let panel = EasyPastePanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false

        self.panel = panel
    }

    func show() {
        centerOnActiveScreen()
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func centerOnActiveScreen() {
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first(where: {
            NSMouseInRect(mouseLocation, $0.frame, false)
        }) ?? NSScreen.main

        guard let activeScreen else {
            panel.center()
            return
        }

        let visibleFrame = activeScreen.visibleFrame
        let panelFrame = panel.frame
        let origin = NSPoint(
            x: visibleFrame.midX - panelFrame.width / 2,
            y: visibleFrame.midY - panelFrame.height / 2
        )

        panel.setFrameOrigin(origin)
    }
}

final class EasyPastePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
