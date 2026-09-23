import AppKit
import SwiftUI

@main
enum DesktopPetsApp {
    @MainActor private static let delegate = AppDelegate()

    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PetStore(url: ProcessInfo.processInfo.environment["DESKTOP_PETS_STATE_FILE"].map {
        URL(fileURLWithPath: $0)
    })
    private var overlays: OverlayCoordinator?
    private var statusItem: NSStatusItem?
    private var manager: NSWindow?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        overlays = OverlayCoordinator(store: store)
        overlays?.onManage = { [weak self] in self?.showManager() }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Desktop Pets")
        item.button?.toolTip = "Desktop Pets"
        statusItem = item
        rebuildMenu()
        store.onChange = { [weak self] in
            self?.overlays?.sync()
            self?.rebuildMenu()
            self?.applyAppearance()
        }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.refreshTreats() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
        if ProcessInfo.processInfo.arguments.contains("--show-manager") { showManager() }
    }

    func applicationWillTerminate(_ notification: Notification) { overlays?.shutdown() }

    private func rebuildMenu() {
        let menu = NSMenu(title: "Desktop Pets")
        menu.addItem(withTitle: "Manage Pets…", action: #selector(showManager), keyEquivalent: "")
        menu.addItem(withTitle: "Throw Ball", action: #selector(throwBall), keyEquivalent: "")
        let feed = menu.addItem(withTitle: "Feed Pet", action: nil, keyEquivalent: "")
        let feedMenu = NSMenu(title: "Feed Pet")
        for pet in store.pets where !pet.hidden {
            let item = feedMenu.addItem(withTitle: pet.name, action: #selector(feedPet(_:)), keyEquivalent: "")
            item.representedObject = pet.id
            item.target = self
        }
        feed.isEnabled = !store.document.hideAll && store.treats.count > 0 && !feedMenu.items.isEmpty
        feed.submenu = feedMenu
        menu.addItem(.separator())
        menu.addItem(withTitle: store.document.hideAll ? "Show Pets" : "Hide All", action: #selector(toggleVisibility), keyEquivalent: "")
        menu.addItem(withTitle: store.document.paused ? "Resume" : "Pause", action: #selector(togglePause), keyEquivalent: "")
        let clicks = menu.addItem(withTitle: "Click Through", action: #selector(toggleClickThrough), keyEquivalent: "")
        clicks.state = store.document.clickThrough ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Treats: \(store.treats.count)/10", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Quit Desktop Pets", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem?.menu = menu
    }

    @objc private func showManager() {
        if manager == nil {
            let content = ManagerView(store: store)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Desktop Pets"
            window.contentView = NSHostingView(rootView: content)
            window.setFrameAutosaveName("DesktopPetsManager")
            window.center()
            window.isReleasedWhenClosed = false
            manager = window
            applyAppearance()
        }
        NSApp.activate(ignoringOtherApps: true)
        manager?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleVisibility() { store.change { $0.hideAll.toggle() } }
    @objc private func togglePause() { store.change { $0.paused.toggle() } }
    @objc private func toggleClickThrough() { store.change { $0.clickThrough.toggle() } }
    @objc private func throwBall() { overlays?.throwBall() }
    @objc private func feedPet(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        overlays?.feed(id)
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func applyAppearance() {
        switch store.document.appearance {
        case "light": manager?.appearance = NSAppearance(named: .aqua)
        case "dark": manager?.appearance = NSAppearance(named: .darkAqua)
        default: manager?.appearance = nil
        }
    }
}
