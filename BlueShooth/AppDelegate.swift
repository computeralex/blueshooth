import Cocoa
import IOBluetooth

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var bluetoothManager: BluetoothManager!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "BlueShooth")
            button.action = #selector(statusBarButtonClicked)
        }

        // Initialize Bluetooth manager
        bluetoothManager = BluetoothManager()

        // Setup menu
        setupMenu()

        // Request Bluetooth permissions
        IOBluetoothPreferenceSetControllerPowerState(1)
    }

    @objc func statusBarButtonClicked() {
        setupMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func setupMenu() {
        menu = NSMenu()

        // Title
        let titleItem = NSMenuItem(title: "BlueShooth - Smart Bluetooth Manager", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Paired devices section
        let pairedDevices = bluetoothManager.getPairedDevices()

        if pairedDevices.isEmpty {
            let noDevicesItem = NSMenuItem(title: "No paired devices found", action: nil, keyEquivalent: "")
            noDevicesItem.isEnabled = false
            menu.addItem(noDevicesItem)
        } else {
            for device in pairedDevices {
                let deviceItem = NSMenuItem(
                    title: device.name,
                    action: #selector(toggleDeviceAutoConnect(_:)),
                    keyEquivalent: ""
                )
                deviceItem.target = self
                deviceItem.representedObject = device

                // Check if auto-connect is disabled for this device
                if bluetoothManager.isAutoConnectDisabled(for: device) {
                    deviceItem.state = .on
                    deviceItem.attributedTitle = NSAttributedString(
                        string: "🚫 \(device.name) (Auto-connect disabled)",
                        attributes: [.font: NSFont.systemFont(ofSize: 13)]
                    )
                } else {
                    deviceItem.state = .off
                    deviceItem.title = "✓ \(device.name) (Auto-connect enabled)"
                }

                menu.addItem(deviceItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Refresh
        menu.addItem(NSMenuItem(title: "Refresh Devices", action: #selector(refreshDevices), keyEquivalent: "r"))

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit BlueShooth", action: #selector(quitApp), keyEquivalent: "q"))
    }

    @objc func toggleDeviceAutoConnect(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? BluetoothDevice else { return }

        bluetoothManager.toggleAutoConnect(for: device)
        setupMenu()
    }

    @objc func refreshDevices() {
        bluetoothManager.refreshDevices()
        setupMenu()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
