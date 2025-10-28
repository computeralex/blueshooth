import Foundation
import IOBluetooth

struct BluetoothDevice: Hashable {
    let address: String
    let name: String
    let deviceRef: IOBluetoothDevice

    func hash(into hasher: inout Hasher) {
        hasher.combine(address)
    }

    static func == (lhs: BluetoothDevice, rhs: BluetoothDevice) -> Bool {
        return lhs.address == rhs.address
    }
}

class BluetoothManager {
    private let userDefaultsKey = "DisabledAutoConnectDevices"
    private var disabledDevices: Set<String> = []
    private var pairedDevices: [BluetoothDevice] = []

    init() {
        loadDisabledDevices()
        refreshDevices()
        setupBluetoothMonitoring()
    }

    func getPairedDevices() -> [BluetoothDevice] {
        return pairedDevices
    }

    func refreshDevices() {
        pairedDevices.removeAll()

        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return
        }

        for device in devices {
            if let address = device.addressString, let name = device.name {
                let btDevice = BluetoothDevice(address: address, name: name, deviceRef: device)
                pairedDevices.append(btDevice)
            }
        }
    }

    func isConnected(_ device: BluetoothDevice) -> Bool {
        return device.deviceRef.isConnected()
    }

    func isAutoConnectDisabled(for device: BluetoothDevice) -> Bool {
        return disabledDevices.contains(device.address)
    }

    func connectDevice(_ device: BluetoothDevice) -> Bool {
        // If device is already connected, return true
        if device.deviceRef.isConnected() {
            return true
        }

        // Attempt to open connection
        let result = device.deviceRef.openConnection()

        if result == kIOReturnSuccess {
            // Show success notification
            let notification = NSUserNotification()
            notification.title = "BlueShooth"
            notification.informativeText = "Connected to \(device.name)"
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
            return true
        } else {
            // Show error notification
            let notification = NSUserNotification()
            notification.title = "BlueShooth"
            notification.informativeText = "Failed to connect to \(device.name)"
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
            return false
        }
    }

    func disconnectDevice(_ device: BluetoothDevice) -> Bool {
        // If device is not connected, return true
        if !device.deviceRef.isConnected() {
            return true
        }

        // Close the connection
        let result = device.deviceRef.closeConnection()

        if result == kIOReturnSuccess {
            // Show success notification
            let notification = NSUserNotification()
            notification.title = "BlueShooth"
            notification.informativeText = "Disconnected from \(device.name)"
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
            return true
        } else {
            return false
        }
    }

    func toggleAutoConnect(for device: BluetoothDevice) {
        if disabledDevices.contains(device.address) {
            disabledDevices.remove(device.address)
            // Re-enable auto-connect by unblocking the device
            enableAutoConnect(for: device)
        } else {
            disabledDevices.insert(device.address)
            // Disable auto-connect by disconnecting and marking device
            disableAutoConnect(for: device)
        }
        saveDisabledDevices()
    }

    private func disableAutoConnect(for device: BluetoothDevice) {
        // Disconnect if currently connected
        if device.deviceRef.isConnected() {
            device.deviceRef.closeConnection()
        }
    }

    private func enableAutoConnect(for device: BluetoothDevice) {
        // macOS will handle re-enabling automatic connection
        // The system manages this once we stop blocking the connection
    }

    private func setupBluetoothMonitoring() {
        // Monitor Bluetooth connection attempts
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.IOBluetoothDeviceConnected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleDeviceConnected(notification)
        }
    }

    private func handleDeviceConnected(_ notification: Notification) {
        guard let device = notification.object as? IOBluetoothDevice,
              let address = device.addressString else {
            return
        }

        // If this device is in our disabled list, disconnect it immediately
        if disabledDevices.contains(address) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                device.closeConnection()

                // Show notification to user
                let notification = NSUserNotification()
                notification.title = "BlueShooth"
                notification.informativeText = "Blocked auto-connect for \(device.name ?? "device")"
                notification.soundName = NSUserNotificationDefaultSoundName
                NSUserNotificationCenter.default.deliver(notification)
            }
        }
    }

    private func loadDisabledDevices() {
        if let saved = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            disabledDevices = Set(saved)
        }
    }

    private func saveDisabledDevices() {
        UserDefaults.standard.set(Array(disabledDevices), forKey: userDefaultsKey)
    }
}
