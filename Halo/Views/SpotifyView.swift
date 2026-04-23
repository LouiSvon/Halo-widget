import SwiftUI

// MARK: - SpotifyView (conteneur)

struct SpotifyView: View {
    @ObservedObject private var spotify = SpotifyService.shared

    var body: some View {
        Group {
            if spotify.isAuthenticated {
                if let track = spotify.currentTrack {
                    NowPlayingView(track: track)
                } else {
                    emptyState
                }
            } else {
                loginView
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - États annexes

    private var loginView: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 34))
                .foregroundColor(Color(hex: "#1DB954"))
            Text("Connecter Spotify")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#F5F5F5"))
            Button("Se connecter") { spotify.startAuth() }
                .buttonStyle(SpotifyPillButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 26))
                .foregroundColor(Color(hex: "#6B6B6B"))
            Text("Aucune lecture en cours")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#6B6B6B"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: - NowPlayingView

struct NowPlayingView: View {
    let track: SpotifyTrack
    @ObservedObject private var spotify = SpotifyService.shared

    var body: some View {
        VStack(spacing: 0) {

            // Pochette + infos
            HStack(alignment: .center, spacing: 12) {
                artworkView
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#F5F5F5"))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                        .lineLimit(1)
                }
                Spacer()
            }

            // Contrôles
            HStack(spacing: 36) {
                PlayerButton(symbol: "backward.fill", size: 17) { spotify.previous() }

                PlayerButton(
                    symbol: spotify.isPlaying ? "pause.fill" : "play.fill",
                    size: 22,
                    tint: Color(hex: "#1DB954")
                ) { spotify.togglePlayPause() }

                PlayerButton(symbol: "forward.fill", size: 17) { spotify.next() }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let image = spotify.albumArtwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#141414"))
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(Color(hex: "#6B6B6B"))
                )
        }
    }
}

// MARK: - Bouton lecteur

private struct PlayerButton: View {
    let symbol: String
    let size: CGFloat
    var tint: Color = Color(hex: "#F5F5F5")
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(tint)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Style bouton "Se connecter"

struct SpotifyPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(Color(hex: "#1DB954"))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
