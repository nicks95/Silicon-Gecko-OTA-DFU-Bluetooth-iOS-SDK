// The Swift Programming Language
// https://docs.swift.org/swift-book

import CoreBluetooth

/**
 The `SiliconGeckoBTOtaUpgrade` class allows to
 */
public class SiliconGeckoBTOtaUpgrade: NSObject {
    private var file: SiliconGblFile
    private var peripheral: CBPeripheral!
    private var centralManagerPeripheral: CBPeripheral!
    private var centralManager: CBCentralManager!
    private var centralManagerDelegate: CentralManagerDelegate!
    private var queue: DispatchQueue
    private var stopRequested: Bool = false
    
    private var otaService: CBService?
    
    private var controlChar: CBCharacteristic?
    private var dataChar: CBCharacteristic?
    
    private var packetSize: Int
    private var packetsDelayMilliseconds: Int
    
    private var status: Status = .idle {
        didSet {
            self.delegate?.siliconGeckoUpgrade(self, didUpdateStatus: status)
        }
    }
    
    /* Public interface */
    public enum Status {
        case idle
        
        case started
        case connecting
        
        case enablingDFUMode
        case enablingDFU
        case updating
        case checking
        
        case completed
        case failed
    }
    
    public init(file: SiliconGblFile, peripheral: CBPeripheral, delegate: SiliconGeckoUpgradeDelegate? = nil, queue: DispatchQueue?, packetSize: Int = 100, packetsDelayMilliseconds: Int = 50) {
        if (packetSize < 8) || (packetSize > 244) {
            self.packetSize = 100
        } else {
            self.packetSize = packetSize
        }
        
        if (packetsDelayMilliseconds < 1) {
            self.packetsDelayMilliseconds = 50
        } else {
            self.packetsDelayMilliseconds = packetsDelayMilliseconds
        }
        
        self.file = file
        self.peripheral = peripheral
        self.delegate = delegate
        self.queue = queue ?? .main
        super.init()
    }
    
    public weak var delegate: SiliconGeckoUpgradeDelegate?
    
    
    public func start() { self.startUpdate() }
    
    private class CentralManagerDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
            
        weak var owner: SiliconGeckoBTOtaUpgrade?
        
        init(owner: SiliconGeckoBTOtaUpgrade) {
            self.owner = owner
        }
        
        public func centralManagerDidUpdateState(_ central: CBCentralManager) {
            owner?.centralManagerDidUpdateState(central)
        }
        
        func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
            owner?.centralManager(central, didFailToConnect: peripheral, error: error)
        }
        
        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            owner?.centralManager(central, didConnect: peripheral)
        }
        
        func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
            owner?.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
            owner?.peripheral(peripheral, didDiscoverServices: error)
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
            owner?.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
        }
        
        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
            owner?.peripheral(peripheral, didWriteValueFor: characteristic, error: error)
        }
        
        func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
            owner?.peripheral(peripheral, didModifyServices: invalidatedServices)
        }
        
    }
    
    private func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "CBCentral manager state: \(String(describing: central.state))", level: "D")
        switch status {
        case .idle, .completed, .failed:
            return
        default:
            switch central.state {
            case .poweredOn:
                switch self.status {
                case .idle, .completed, .failed: fatalError()
                case .started:
                    if let p = self.centralManager.retrievePeripherals(withIdentifiers: [self.peripheral.identifier]).first {
                        self.peripheral = nil
                        self.centralManagerPeripheral = p
                        self.status = .connecting
                        self.centralManager.connect(p)
                    } else {
                        self.status = .failed
                        self.delegate?.siliconGeckoUpgrade(self, didFailWithError: .blePeripheralNotFound)
                        return
                    }
                default: return
                }
            default:
                self.status = .failed
                self.delegate?.siliconGeckoUpgrade(self, didFailWithError: .bleStatusError(central.state))
                return
            }
        }
    }
    
    private func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        switch self.status {
        case .connecting, .enablingDFUMode:
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Unable to connect to peripheral", level: "E")
            self.status = .failed
            self.delegate?.siliconGeckoUpgrade(self, didFailWithError: .connectionError)
            return
        default: break
        }
    }
    
    private func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        switch self.status {
        case .connecting:
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Device connected", level: "I")
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Scanning services", level: "I")
            
            peripheral.delegate = self.centralManagerDelegate
            peripheral.discoverServices([OTAService.otaServiceUUID])
        case .enablingDFUMode:
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Device reconnected", level: "I")
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Scanning services", level: "I")
            
            peripheral.discoverServices([OTAService.otaServiceUUID])
        default: break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        switch status {
        case .idle, .completed, .failed:
            return
        case .enablingDFUMode:
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Device disconnected. Reconnecting.", level: "I")
            self.centralManager.connect(peripheral)
        default:
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Device disconnected", level: "E")
            self.status = .failed
            self.delegate?.siliconGeckoUpgrade(self, didFailWithError: .connectionError)
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Device updated its services.", level: "I")
        guard self.status == .enablingDFUMode else { return }
        
        self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Scanning services", level: "I")
        peripheral.discoverServices([OTAService.otaServiceUUID])
    }
    
    private func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard error == nil else {
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Error discovering services: \(String(describing: error))", level: "E")
            self.status = .failed
            self.delegate?.siliconGeckoUpgrade(self, didFailWithError: .connectionError)
            return
        }
        
        self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Services discovered:\((peripheral.services ?? []).map({ s in "\n  -\(s.uuid.uuidString)" }))", level: "I")
        
        guard let s = peripheral.services?.first (where: { $0.uuid == OTAService.otaServiceUUID }) else {
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "OTA Service not found. Is this the correct peripheral?", level: "E")
            self.status = .failed
            self.delegate?.siliconGeckoUpgrade(self, didFailWithError: .deviceConfigurationError)
            return
        }
        
        self.otaService = s
        
        self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Scanning characteristics", level: "I")
        peripheral.discoverCharacteristics([OTAService.otaControlAttributeUUID, OTAService.otaDataAttributeUUID], for: s)
    }
    
    private func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        guard error == nil else {
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Error discovering characteristics: \(String(describing: error))", level: "E")
            self.status = .failed
            self.delegate?.siliconGeckoUpgrade(self, didFailWithError: .connectionError)
            return
        }
        
        guard service.uuid == OTAService.otaServiceUUID else { return }
        
        self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Characteristics discovered:\((service.characteristics ?? []).map({ c in "\n  -\(c.uuid.uuidString)" }))", level: "I")
        
        let controlChar = (service.characteristics ?? []).first(where: { $0.uuid == OTAService.otaControlAttributeUUID })
        let dataChar = (service.characteristics ?? []).first(where: { $0.uuid == OTAService.otaDataAttributeUUID })
        
        guard let controlChar else {
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "OTA Control characteristic not found", level: "E")
            self.status = .failed
            self.delegate?.siliconGeckoUpgrade(self, didFailWithError: .connectionError)
            return
        }
        
        self.controlChar = controlChar
        
        if let dataChar {
            self.dataChar = dataChar
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Device is in DFU Mode", level: "I")
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Enabling firmware update", level: "I")
            self.status = .enablingDFU
            peripheral.writeValue(Data([UInt8(0)]), for: controlChar, type: .withResponse)
        } else {
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "OTA Data characteristic not found. Device is not into DFU Mode", level: "I")
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Rebooting device into DFU Mode", level: "I")
            self.status = .enablingDFUMode
            peripheral.writeValue(Data([UInt8(0)]), for: controlChar, type: .withResponse)
        }
    }
    
    private func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        switch status {
        case .enablingDFUMode:
            if let error {
                self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Error executing the command: \(error._code)", level: "E")
                self.status = .failed
                self.delegate?.siliconGeckoUpgrade(self, didFailWithError: .operationFailed)
                return
            } else {
                self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Operation executed correctly", level: "I")
                self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Waiting for device to disconnect or update its services", level: "I")
            }
        case .enablingDFU:
            if let error {
                self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Error executing the command: \(error._code)", level: "E")
                self.status = .failed
                self.delegate?.siliconGeckoUpgrade(self, didFailWithError: .operationFailed)
                return
            } else {
                
                self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Operation executed correctly", level: "I")
                self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Beginning firmware upload", level: "I")
                
                self.status = .updating
                
                let fileSize = self.file.data.count
                let pageSize = 100
                let pageCount = (self.file.data.count + pageSize - 1) / pageSize

                self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "File size \(fileSize) B", level: "I")
                self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Pages: \(pageCount)", level: "I")
                
                func sendPage(index: Int) {
                    if index == pageCount {
                        self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "All pages sent. Checking if result is ok.", level: "I")
                        self.status = .checking
                        peripheral.writeValue(Data([UInt8(3)]), for: controlChar!, type: .withResponse)
                    } else {
                        self.delegate?.siliconGeckoUpgrade(self, didSendPage: index, outOf: pageCount, progress: Double(index + 1) / Double(pageCount) )
                        
                        let start = index * pageSize
                        let end = min(start + pageSize, self.file.data.count)
                        let range = start..<end
                            
                        let pageData = self.file.data.subdata(in: range)
                        peripheral.writeValue(pageData, for: dataChar!, type: .withoutResponse)
                        self.queue.asyncAfter(deadline: .now() + .milliseconds(50), execute: DispatchWorkItem(block: { sendPage(index: index + 1) }))
                    }
                    
                }
                
                sendPage(index: 0)
            }
        case .checking:
            if let error {
                self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Error executing the command: \(error._code)", level: "E")
                self.status = .failed
                let decodedError = switch (error._code) {
                case 0x80: SiliconGeckoUpgradeError.crcError
                case 0x81: SiliconGeckoUpgradeError.wrongState
                case 0x82: SiliconGeckoUpgradeError.buffersFull
                case 0x83: SiliconGeckoUpgradeError.imageTooBig
                case 0x84: SiliconGeckoUpgradeError.notSupported
                case 0x85: SiliconGeckoUpgradeError.bootloader
                case 0x86: SiliconGeckoUpgradeError.incorrectBootloader
                case 0x87: SiliconGeckoUpgradeError.applicationOverlapBootloader
                case 0x88: SiliconGeckoUpgradeError.incompatibleBootloaderVersion
                case 0x89: SiliconGeckoUpgradeError.attErrorApplicationVersionCheckFail
                default: SiliconGeckoUpgradeError.operationFailed
                }
                self.delegate?.siliconGeckoUpgrade(self, didFailWithError: decodedError)
                return
                
            } else {
                self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Operation executed correctly", level: "I")
                self.status = .completed
                self.delegate?.siliconGeckoUpgradeDidCompleteUpdate(self)
                self.centralManager.cancelPeripheralConnection(peripheral)
            }
        default: break
        }
        
    }
 
    private func startUpdate() {
        guard self.status == .idle else {
            self.delegate?.siliconGeckoUpgrade(self, didLogMessage: "Update already started", level: "W")
            return
        }
        
        self.status = .started
        
        self.centralManagerDelegate = CentralManagerDelegate(owner: self)
        self.centralManager = CBCentralManager(delegate: self.centralManagerDelegate, queue: self.queue)
    }
    
}


