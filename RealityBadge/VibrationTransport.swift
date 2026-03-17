import Foundation
import CoreBluetooth

// MARK: - 外接振动传输接口（BLE 预留）
protocol RBVibrationTransport {
    func connect()
    func disconnect()
    func send(intensity: Float, duration: TimeInterval)
}

final class RBNoopVibrationTransport: RBVibrationTransport {
    func connect() {}
    func disconnect() {}
    func send(intensity: Float, duration: TimeInterval) {}
}

// 示例：使用 CoreBluetooth 的极简实现（需替换为你的 Service/Characteristic UUID）
final class RBBLEVibrationTransport: NSObject, RBVibrationTransport {
    private let central = CBCentralManager()
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?

    // 替换为你的实际 UUID
    private let serviceUUID = CBUUID(string: "0000FFFF-0000-1000-8000-00805F9B34FB")
    private let characteristicUUID = CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB")

    override init() {
        super.init()
        central.delegate = self
    }

    func connect() { if central.state == .poweredOn { central.scanForPeripherals(withServices: [serviceUUID]) } }
    func disconnect() { if let p = peripheral { central.cancelPeripheralConnection(p) } }

    func send(intensity: Float, duration: TimeInterval) {
        guard let p = peripheral, let c = writeChar else { return }
        // 协议示例：2字节强度(0-100)、2字节时长ms（小端）
        let i = UInt16(max(0, min(100, Int(intensity * 100))))
        let ms = UInt16(max(0, min(10000, Int(duration * 1000))))
        let payload: [UInt8] = [UInt8(i & 0xFF), UInt8(i >> 8), UInt8(ms & 0xFF), UInt8(ms >> 8)]
        let data = Data(payload)
        p.writeValue(data, for: c, type: .withResponse)
    }
}

extension RBBLEVibrationTransport: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { connect() }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        central.stopScan()
        central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for s in services where s.uuid == serviceUUID { peripheral.discoverCharacteristics([characteristicUUID], for: s) }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let cs = service.characteristics else { return }
        for c in cs where c.uuid == characteristicUUID { self.writeChar = c }
    }
}

