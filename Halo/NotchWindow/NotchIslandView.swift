import SwiftUI

struct NotchIslandView: View {
    @ObservedObject private var notch     = NotchWindowController.shared
    @ObservedObject private var spotify   = SpotifyService.shared
    @ObservedObject private var bluetooth = BluetoothService.shared

    @Namespace private var ns

    private var isExpanded: Bool { notch.state == .expanded }

    var body: some View {
        Color.clear
            .overlay(alignment: .top) { pill }
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
    }

    // MARK: - Pill

    private var pill: some View {
        VStack(spacing: 0) {
            collapsedBar
                .frame(height: notch.notchHeight)

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: pillWidth)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: isExpanded ? 22 : notch.notchHeight / 2,
                bottomTrailingRadius: isExpanded ? 22 : notch.notchHeight / 2,
                topTrailingRadius: 0
            )
            .fill(Color(hex: "#0A0A0A"))
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: isExpanded ? 22 : notch.notchHeight / 2,
                bottomTrailingRadius: isExpanded ? 22 : notch.notchHeight / 2,
                topTrailingRadius: 0
            )
        )
        .shadow(
            color: .black.opacity(isExpanded ? 0.5 : 0),
            radius: isExpanded ? 20 : 0,
            y: isExpanded ? 8 : 0
        )
    }

    private var pillWidth: CGFloat {
        switch notch.state {
        case .idle:     return notch.notchWidth
        case .collapsed, .expanded: return notch.notchWidth + 80
        }
    }

    // MARK: - Barre collapsed / idle

    private var collapsedBar: some View {
        HStack(spacing: 0) {
            switch notch.state {
            case .idle:
                // Petit point vert centré indiquant que Halo tourne
                Spacer()
                Circle()
                    .fill(Color(hex: "#1DB954"))
                    .frame(width: 6, height: 6)
                    .transition(.scale.combined(with: .opacity))
                Spacer()

            case .collapsed, .expanded:
                // Album art à gauche
                if !isExpanded {
                    albumImage(size: 26, radius: 6)
                        .matchedGeometryEffect(id: "album", in: ns)
                        .padding(.leading, 10)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }

                Spacer()

                // Equalizer à droite
                if !isExpanded {
                    EqualizerBars(isActive: spotify.isPlaying)
                        .matchedGeometryEffect(id: "eq", in: ns)
                        .frame(width: 20, height: 16)
                        .padding(.trailing, 10)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Contenu étendu

    private var expandedContent: some View {
        VStack(spacing: 10) {
            if spotify.isAuthenticated {
                if let _ = spotify.currentTrack {
                    // Ligne 1 : album + track info + eq
                    HStack(spacing: 10) {
                        albumImage(size: 56, radius: 10)
                            .matchedGeometryEffect(id: "album", in: ns)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(spotify.currentTrack?.title ?? "")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "#F5F5F5"))
                                .lineLimit(1)
                            Text(spotify.currentTrack?.artist ?? "")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#6B6B6B"))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 2)

                        EqualizerBars(isActive: spotify.isPlaying)
                            .matchedGeometryEffect(id: "eq", in: ns)
                            .frame(width: 18, height: 14)
                    }

                    progressBar
                    controlsRow
                } else {
                    // Authentifié mais rien ne joue
                    VStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#6B6B6B"))
                        Text("Aucune lecture en cours")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#6B6B6B"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                // Non authentifié → bouton connect
                VStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "#1DB954"))
                    Text("Connecter Spotify")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#F5F5F5"))
                    Button("Se connecter") { spotify.startAuth() }
                        .buttonStyle(SpotifyPillButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    // MARK: - Album art

    @ViewBuilder
    private func albumImage(size: CGFloat, radius: CGFloat) -> some View {
        if let artwork = spotify.albumArtwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: radius))
        } else {
            RoundedRectangle(cornerRadius: radius)
                .fill(Color(hex: "#1F1F1F"))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.35))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                )
        }
    }

    // MARK: - Barre de progression

    private var progressBar: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#1F1F1F"))
                    Capsule()
                        .fill(Color(hex: "#F5F5F5"))
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 3)

            Text(timeLabel)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#6B6B6B"))
                .fixedSize()
        }
    }

    // MARK: - Contrôles

    private var controlsRow: some View {
        HStack(spacing: 0) {
            Spacer()
            IslandButton(icon: "backward.fill", size: 13) { spotify.previous() }
            Spacer()
            IslandButton(
                icon: spotify.isPlaying ? "pause.fill" : "play.fill",
                size: 17
            ) { spotify.togglePlayPause() }
            Spacer()
            IslandButton(icon: "forward.fill", size: 13) { spotify.next() }
            Spacer()
            Image(systemName: bluetooth.connectedDevices.isEmpty ? "airplayaudio" : "headphones")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#6B6B6B"))
            Spacer()
        }
    }

    // MARK: - Helpers

    private var progress: CGFloat {
        guard spotify.durationMS > 0 else { return 0 }
        return min(CGFloat(spotify.progressMS) / CGFloat(spotify.durationMS), 1)
    }

    private var timeLabel: String {
        "\(fmt(spotify.progressMS)) / \(fmt(spotify.durationMS))"
    }

    private func fmt(_ ms: Int) -> String {
        let s = ms / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Bouton île

private struct IslandButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(Color(hex: "#F5F5F5"))
            .scaleEffect(pressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.1), value: pressed)
            .onTapGesture {
                pressed = true
                action()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    pressed = false
                }
            }
    }
}

// MARK: - Equalizer animé

struct EqualizerBars: View {
    let isActive: Bool
    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(hex: "#1DB954"))
                    .frame(width: 3, height: barHeight(index: i))
            }
        }
        .animation(.easeInOut(duration: 0.38), value: phase)
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .task(id: isActive) {
            guard isActive else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(420))
                phase += 1
            }
        }
    }

    private func barHeight(index: Int) -> CGFloat {
        guard isActive else { return 2 }
        let t = phase * (1.0 + Double(index) * 0.3) + Double(index) * 2.1
        let h = (sin(t * 1.7) + 1) / 2 * 0.7 + 0.3
        return CGFloat(h) * 14
    }
}
