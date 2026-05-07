import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        setupStatusItem()
        setupPopover()

        // Notch disponible → island ; sinon le popover suffit
        if NotchWindowController.shared.setup() {
            SpotifyService.shared.startPolling()
        }

        // Met à jour le menu quand l'auth ou la piste change
        Publishers.Merge(
            SpotifyService.shared.$isAuthenticated.map { _ in () },
            SpotifyService.shared.$currentTrack.map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] in self?.rebuildMenu() }
        .store(in: &cancellables)

        rebuildMenu()
    }

    // MARK: - Status Item (toujours présent)

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "Halo")
        statusItem = item
    }

    private func setupPopover() {
        let p = NSPopover()
        p.contentSize = NSSize(width: 320, height: 480)
        p.behavior = .transient
        p.animates = true
        p.appearance = NSAppearance(named: .darkAqua)
        p.contentViewController = NSHostingController(
            rootView: ContentView().preferredColorScheme(.dark)
        )
        popover = p
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if SpotifyService.shared.isAuthenticated {
            let statusTitle = SpotifyService.shared.currentTrack.map {
                "▶ \($0.title)"
            } ?? "Aucune lecture en cours"
            let trackItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
            trackItem.isEnabled = false
            menu.addItem(trackItem)
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "Ouvrir le panneau", action: #selector(togglePopover), keyEquivalent: "o"))
        } else {
            menu.addItem(NSMenuItem(title: "Connecter Spotify", action: #selector(connectSpotify), keyEquivalent: "c"))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quitter Halo", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func connectSpotify() {
        SpotifyService.shared.startAuth()
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

}
