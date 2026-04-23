import SwiftUI

@main
struct HaloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Pas de fenêtre principale — uniquement NSPopover géré par AppDelegate
        Settings { EmptyView() }
    }
}
