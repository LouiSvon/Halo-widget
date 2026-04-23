import SwiftUI

struct ContentView: View {
    @ObservedObject private var spotify    = SpotifyService.shared
    @ObservedObject private var bluetooth  = BluetoothService.shared

    var body: some View {
        VStack(spacing: 0) {
            SpotifyView()

            Rectangle()
                .fill(Color(hex: "#1F1F1F"))
                .frame(height: 1)

            BluetoothView()

            Spacer(minLength: 0)
        }
        .frame(width: 320, height: 480)
        .background(Color(hex: "#0A0A0A"))
        .preferredColorScheme(.dark)
        .onAppear {
            spotify.startPolling()
            bluetooth.refresh()
        }
        .onDisappear {
            spotify.stopPolling()
        }
    }
}
