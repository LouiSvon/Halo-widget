import Foundation
import IOBluetooth

// MARK: - Model

struct BluetoothDevice: Identifiable {
    let id: String
    let name: String
    let icon: String
    let ioDevice: IOBluetoothDevice

    init(device: IOBluetoothDevice) {
        self.ioDevice = device
        self.id       = device.addressString ?? UUID().uuidString
        self.name     = device.name ?? "Appareil inconnu"
        self.icon     = Self.icon(for: device)
    }

    private static func icon(for device: IOBluetoothDevice) -> String {
        let n = (device.name ?? "").lowercased()
        if n.contains("airpod") || n.contains("headphone") || n.contains("earphone")
            || n.contains("casque") || n.contains("earbud") {
            return "headphones"
        } else if n.contains("keyboard") || n.contains("clavier") {
            return "keyboard"
        } else if n.contains("mouse") || n.contains("souris") {
            return "computermouse"
        } else if n.contains("trackpad") {
            return "rectangle.and.hand.point.up.left.fill"
        } else if n.contains("speaker") || n.contains("enceinte") || n.contains("soundbar") {
            return "hifispeaker.fill"
        } else {
            return "dot.radiowaves.left.and.right"
        }
    }
}

// MARK: - BluetoothService

final class BluetoothService: NSObject, ObservableObject {
    static let shared = BluetoothService()

    @Published var connectedDevices: [BluetoothDevice] = []

    // Conserver les notifications pour éviter leur déallocation
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [IOBluetoothUserNotification] = []

    private override init() {
        super.init()
        refresh()
        // S'abonner aux connexions futures
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceDidConnect(_:device:))
        )
    }

    // MARK: - API publique

    func refresh() {
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        connectedDevices = paired
            .filter { $0.isConnected() }
            .map { BluetoothDevice(device: $0) }
    }

    func disconnect(_ device: BluetoothDevice) {
        device.ioDevice.closeConnection()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.refresh() }
    }

    // MARK: - Notifications IOBluetooth

    @objc private func deviceDidConnect(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        DispatchQueue.main.async { self.refresh() }
        // S'abonner à la déconnexion de cet appareil précis
        let n = device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDidDisconnect(_:device:))
        )
        if let n { disconnectNotifications.append(n) }
    }

    @objc private func deviceDidDisconnect(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        DispatchQueue.main.async { self.refresh() }
    }
}
