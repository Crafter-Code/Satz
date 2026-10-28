import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Satz")
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Satz", action: #selector(quit), keyEquivalent: "q").target = self
        appMenuItem.submenu = appMenu; mainMenu.addItem(appMenuItem)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu; mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "Satz")
            button.toolTip = "Satz · local writing assistance"
        }
        model.onMenuChange = { [weak self] in self?.updateMenu() }
        updateMenu()
        let content = SettingsView(model: model)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1020, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Satz"; window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content)
        window.center(); showSettings()
        model.start()
    }

    func updateMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Satz · \(model.data.preferences.enabled ? "Enabled" : "Paused")", action: #selector(toggle), keyEquivalent: "")
        let status = NSMenuItem(title: model.status, action: nil, keyEquivalent: ""); status.isEnabled = false; menu.addItem(status)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Pause / Resume", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Satz", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { if item.action != nil { item.target = self } }
        statusItem.menu = menu
    }
    @objc func showSettings() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func toggle() { model.toggle(); updateMenu() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
    withExtendedLifetime(delegate) {}
}
