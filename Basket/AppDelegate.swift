import AppKit
import SwiftUI

/// Owns the main window. It's an AppKit window rather than a SwiftUI scene so that closing it only
/// hides it: the web views keep running in the background and notifications keep arriving.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationBridge.shared.start { [weak self] accountID, notificationID in
            self?.showMainWindow()
            self?.model.handleNotificationClick(accountID: accountID, notificationID: notificationID)
        }
        model.onSelectionChange = { [weak self] in self?.updateWindowTitle() }
        model.start()
        showMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    func showMainWindow() {
        let window = window ?? makeMainWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeMainWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: ContentView().environment(model))
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 760, height: 480)
        window.setContentSize(NSSize(width: 1280, height: 820))
        window.center()
        // Restores the size and position from last time, and saves changes from now on.
        _ = window.setFrameAutosaveName("BasketMainWindow")
        self.window = window
        updateWindowTitle()
        return window
    }

    private func updateWindowTitle() {
        window?.title = model.selectedAccount?.title ?? "Basket"
    }
}
