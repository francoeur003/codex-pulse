import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = PulseModel()
    private var bridge: CodexBridge?
    private var watcher: SessionTokenWatcher?
    private var panel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createPanel()

        let bridge = CodexBridge(model: model)
        let watcher = SessionTokenWatcher(model: model)
        self.bridge = bridge
        self.watcher = watcher
        bridge.start()
        watcher.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        bridge?.stop()
        watcher?.stop()
    }

    private func createPanel() {
        let size = NSSize(width: 420, height: 520)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.contentView = NSHostingView(rootView: PetView(model: model))

        if let screen = NSScreen.main?.visibleFrame {
            let origin = NSPoint(
                x: screen.maxX - size.width - 28,
                y: screen.minY + 42
            )
            panel.setFrameOrigin(origin)
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }
}

@main
enum CodexPulseMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
