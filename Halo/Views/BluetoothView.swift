import SwiftUI

struct BluetoothView: View {
    @ObservedObject private var bluetooth = BluetoothService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // En-tête section
            Text("BLUETOOTH")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "#6B6B6B"))
                .kerning(0.8)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)

            if bluetooth.connectedDevices.isEmpty {
                HStack {
                    Spacer()
                    Text("Aucun appareil connecté")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(bluetooth.connectedDevices) { device in
                            DeviceRow(device: device)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - DeviceRow

struct DeviceRow: View {
    let device: BluetoothDevice
    @ObservedObject private var bluetooth = BluetoothService.shared
    @State private var opacity: Double = 1

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.icon)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#F5F5F5"))
                .frame(width: 26, alignment: .center)

            Text(device.name)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#F5F5F5"))
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.18)) { opacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    bluetooth.disconnect(device)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#6B6B6B"))
                    .frame(width: 20, height: 20)
                    .background(Color(hex: "#1F1F1F"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .opacity(opacity)
        .background(Color(hex: "#141414").opacity(0.001)) // zone cliquable
    }
}
