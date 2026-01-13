import Foundation
import CoreBluetooth
import Combine

fileprivate let nusServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
fileprivate let nusRXUUID      = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // write (phone -> feather)
fileprivate let nusTXUUID      = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // notify (feather -> phone)
fileprivate let targetDeviceName = "Feather ESP32-S3"

final class BLEManager: NSObject, ObservableObject {
    @Published var statusText: String = "Idle"
    @Published var connected: Bool = false
    @Published var lastReceived: String = ""
    @Published var discoveredDevices: [String] = []

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic? // write here
    private var txCharacteristic: CBCharacteristic? // notify here

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
        statusText = "Bluetooth initializing..."
    }

    func startScan() {
        guard central.state == .poweredOn else {
            statusText = "Bluetooth not powered"
            return
        }
        discoveredDevices.removeAll()
        peripheral = nil
        statusText = "Scanning for nearby BLE devices (looking for \(targetDeviceName) or NUS 6E400001...) - 10s timeout"
        print("[BLE] Starting scan for peripherals (no service filter). Will look for name '\(targetDeviceName)' or service \(nusServiceUUID)")
        // Scan without a service filter, because the Feather may not advertise the NUS UUID in the advertisement packet.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.central.stopScan()
            if self.peripheral == nil {
                if self.discoveredDevices.isEmpty {
                    self.statusText = "Scan timed out - no matching devices found. Is your Feather advertising NUS?"
                } else {
                    self.statusText = "Scan timed out before connecting. Devices seen:\n" + self.discoveredDevices.joined(separator: "\n")
                }
                print("[BLE] Scan timed out. Devices seen: \(self.discoveredDevices)")
            }
        }
    }

    func disconnect() {
        if let p = peripheral {
            central.cancelPeripheralConnection(p)
        }
    }

    func sendCommand(_ text: String) {
        guard let rx = rxCharacteristic, let p = peripheral else {
            statusText = "Not connected"
            return
        }
        guard let data = text.data(using: .utf8) else { return }
        p.writeValue(data, for: rx, type: .withResponse)
        statusText = "Sent: \(text)"
    }
}

extension BLEManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            statusText = "Bluetooth state: Unknown"
            print("[BLE] Central state: unknown")
        case .resetting:
            statusText = "Bluetooth state: Resetting"
            print("[BLE] Central state: resetting")
        case .unsupported:
            statusText = "Bluetooth Unsupported on this device"
            print("[BLE] Central state: unsupported")
        case .unauthorized:
            statusText = "Bluetooth Unauthorized - check permissions in Settings"
            print("[BLE] Central state: unauthorized")
        case .poweredOff:
            statusText = "Bluetooth Off - please turn it on"
            print("[BLE] Central state: poweredOff")
        case .poweredOn:
            statusText = "Bluetooth On - ready to scan"
            print("[BLE] Central state: poweredOn")
        @unknown default:
            statusText = "Bluetooth state: unknown value"
            print("[BLE] Central state: unknown default \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown"
        let line = "\(name) (RSSI: \(RSSI))"
        if !discoveredDevices.contains(line) {
            discoveredDevices.append(line)
        }
        print("[BLE] Discovered peripheral: \(line), advData=\(advertisementData)")

        // Check if this looks like our Feather / NUS device.
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let matchesService = advertisedServices.contains(nusServiceUUID)
        let matchesName = name.contains(targetDeviceName)

        if self.peripheral == nil && (matchesService || matchesName) {
            statusText = "Found target: \(line). Connecting..."
            print("[BLE] Target match (service:\(matchesService) name:\(matchesName)). Connecting to \(line)")
            central.stopScan()
            self.peripheral = peripheral
            peripheral.delegate = self
            central.connect(peripheral, options: nil)
        } else {
            statusText = "Scanning... last seen: \(line)"
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusText = "Connected to \(peripheral.name ?? "Device")"
        connected = true
        peripheral.discoverServices([nusServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        statusText = "Failed to connect: \(error?.localizedDescription ?? "err")"
        connected = false
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        statusText = "Disconnected"
        connected = false
        rxCharacteristic = nil
        txCharacteristic = nil
        self.peripheral = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let err = error {
            statusText = "Service discover error: \(err.localizedDescription)"
            return
        }
        guard let services = peripheral.services else { return }
        for s in services {
            if s.uuid == nusServiceUUID {
                peripheral.discoverCharacteristics([nusRXUUID, nusTXUUID], for: s)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let err = error {
            statusText = "Char discover error: \(err.localizedDescription)"
            return
        }
        guard let chars = service.characteristics else { return }
        for c in chars {
            if c.uuid == nusRXUUID {
                rxCharacteristic = c
            } else if c.uuid == nusTXUUID {
                txCharacteristic = c
                peripheral.setNotifyValue(true, for: c)
            }
        }
        if rxCharacteristic != nil || txCharacteristic != nil {
            statusText = "Ready"
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let err = error {
            statusText = "Notify error: \(err.localizedDescription)"
            return
        }
        if let data = characteristic.value, let s = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.lastReceived = s
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let err = error {
            statusText = "Write error: \(err.localizedDescription)"
        } else {
            statusText = "Write OK"
        }
    }
}
