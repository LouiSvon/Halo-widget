import AppKit
import SwiftUI
import Combine

enum IslandState: Equatable {
    case idle       // pas de musique → pill invisible (= notch physique)
    case collapsed  // musique → pill étendue (album + eq) toujours visible
    case expanded   // hover → contenu détaillé
}

final class NotchWindowController: NSObject, ObservableObject {
    static let shared = NotchWindowController()

    @Published var state: IslandState = .idle

    private var panel: NSPanel?
    private var collapseWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Géométrie écran

    var notchHeight: CGFloat {
        NSScreen.main?.safeAreaInsets.top ?? 0
    }

    var notchWidth: CGFloat {
        guard let screen = NSScreen.main,
              let left  = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea
        else { return 180 }
        return right.minX - left.maxX
    }

    private var notchCenterX: CGFloat {
        guard let screen = NSScreen.main,
              let left  = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea
        else { return (NSScreen.main?.frame.width ?? 0) / 2 }
        return (left.maxX + right.minX) / 2
    }

    /// Largeur de la pill : notch + extensions pour album (gauche) et eq (droite)
    private let sideExtension: CGFloat = 80
    private var pillWidth: CGFloat { notchWidth + sideExtension }

    /// Hauteur du contenu étendu sous l'encoche
    static let expandedContentHeight: CGFloat = 220

    // MARK: - Frames du panel

    private var idleFrame: NSRect {
        guard let screen = NSScreen.main else { return .zero }
        // Même taille que la pill max pour éviter les resize latéraux
        return NSRect(
            x: notchCenterX - pillWidth / 2,
            y: screen.frame.maxY - notchHeight,
            width: pillWidth,
            height: notchHeight
        )
    }

    private var collapsedFrame: NSRect { idleFrame }

    private var expandedFrame: NSRect {
        guard let screen = NSScreen.main else { return .zero }
        let totalH = notchHeight + Self.expandedContentHeight
        return NSRect(
            x: notchCenterX - pillWidth / 2,
            y: screen.frame.maxY - totalH,
            width: pillWidth,
            height: totalH
        )
    }

    // MARK: - Setup

    private override init() {}

    @discardableResult
    func setup() -> Bool {
        guard notchHeight > 0 else { return false }

        let panel = NSPanel(
            contentRect: idleFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level              = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.backgroundColor    = .clear
        panel.isOpaque           = false
        panel.hasShadow          = false
        panel.animationBehavior  = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true   // idle + collapsed : transparent aux clics

        let hosting = NSHostingView(rootView: NotchIslandView())
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.orderFrontRegardless()
        self.panel = panel

        observeSpotify()
        startMouseTracking()
        return true
    }

    // MARK: - Observer Spotify pour idle ↔ collapsed

    private func observeSpotify() {
        SpotifyService.shared.$currentTrack
            .receive(on: RunLoop.main)
            .sink { [weak self] track in
                guard let self else { return }
                if track != nil && self.state == .idle {
                    self.setState(.collapsed)
                } else if track == nil && self.state != .idle {
                    self.setState(.idle)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Mouse tracking (poll 50 ms)

    private func startMouseTracking() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkMouse()
        }
    }

    private func checkMouse() {
        let mouse = NSEvent.mouseLocation

        switch state {
        case .idle:
            // Hover sur le notch en idle → expand pour montrer auth/status
            let zone = collapsedFrame.insetBy(dx: -12, dy: -4)
            if zone.contains(mouse) {
                setState(.expanded)
            }

        case .collapsed:
            let zone = collapsedFrame.insetBy(dx: -12, dy: -4)
            if zone.contains(mouse) {
                collapseWork?.cancel()
                collapseWork = nil
                setState(.expanded)
            }

        case .expanded:
            let zone = expandedFrame.insetBy(dx: -24, dy: -16)
            if zone.contains(mouse) {
                collapseWork?.cancel()
                collapseWork = nil
            } else if collapseWork == nil {
                let work = DispatchWorkItem { [weak self] in
                    // Retour à idle si pas de musique, sinon collapsed
                    if SpotifyService.shared.currentTrack != nil {
                        self?.setState(.collapsed)
                    } else {
                        self?.setState(.idle)
                    }
                    self?.collapseWork = nil
                }
                collapseWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
            }
        }
    }

    // MARK: - Transitions d'état

    private func setState(_ newState: IslandState) {
        guard newState != state else { return }

        switch newState {
        case .expanded:
            // D'abord agrandir le panel, puis animer le contenu
            panel?.setFrame(expandedFrame, display: true)
            panel?.ignoresMouseEvents = false
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                state = newState
            }

        case .collapsed:
            panel?.ignoresMouseEvents = true
            withAnimation(.easeOut(duration: 0.22)) {
                state = newState
            }
            // Réduire le panel après l'animation de sortie
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                self.panel?.setFrame(self.collapsedFrame, display: true)
            }

        case .idle:
            panel?.ignoresMouseEvents = true
            withAnimation(.easeOut(duration: 0.25)) {
                state = newState
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.panel?.setFrame(self.idleFrame, display: true)
            }
        }
    }
}
