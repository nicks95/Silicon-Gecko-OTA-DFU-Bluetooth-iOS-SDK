# Silicon-Gecko-OTA-DFU-Bluetooth-iOS-SDK
iOS (Swift 6.0) SDK that performs OTA DFU over Bluetooth LE transmitting .GBL files

It implements the procedure defined at: [gecko-bootloader-bluetooth.pdf](https://www.silabs.com/documents/public/application-notes/an1086-gecko-bootloader-bluetooth.pdf).

It uses the OTA BLE Service ( 1D14D6EE-FD63-4FA1-BFA4-8F47B42119F0 ) and the OTA Control Attribute and OTA Data Attribute Characteristics ( F7BF3564-FB6D-4E53-88A4-5E37E0326063 and 984227F3-34FC-4045-A5D0-2C581F81A153 ).

# How to use

```swift
let file = try! SiliconGblFile(url: Bundle.main.url(forResource:"fw", withExtension: "gbl")!)
// or let file = SiliconGblFile(data: your_data)

let updater = SiliconGeckoBTOtaUpgrade(file: file, peripheral: device, delegate: self, queue: nil)
//you can also specify packet dimension or frequency to speedup the transmission default is 100 B / 50ms

updater.start()
```

You will get callbacks on the delegate.

# Example
Very simple example viewcontroller implementing the update:

```swift
import UIKit
import CoreBluetooth

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate, SiliconGeckoUpgradeDelegate {
    @IBOutlet weak var devicesTableView: UITableView!
    
    var cbCentralManager: CBCentralManager!
    var foundDevices: [CBPeripheral] = []
    var updater: SiliconGeckoBTOtaUpgrade!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cbCentralManager = CBCentralManager(delegate: self, queue: nil)
        self.devicesTableView.dataSource = self
        self.devicesTableView.delegate = self
    }
    
    @IBAction func scanPressed(_ sender: Any) {
        self.foundDevices = []
        self.devicesTableView.reloadData()
        self.cbCentralManager.scanForPeripherals(withServices: nil)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.foundDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let dev = self.foundDevices[indexPath.row]
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.text = dev.name
        cellConfig.secondaryText = dev.identifier.uuidString
        let cell = UITableViewCell()
        cell.contentConfiguration = cellConfig
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = self.foundDevices[indexPath.row]
        let file = try! SiliconGblFile(url: Bundle.main.url(forResource:"fw", withExtension: "gbl")!)
        updater = SiliconGeckoBTOtaUpgrade(file: file, peripheral: device, delegate: self, queue: nil)
        updater.start()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {}
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.foundDevices.append(peripheral)
        self.devicesTableView.reloadData()
    }
    
    func siliconGeckoUpgradeDidCompleteUpdate(_ sender: SiliconGeckoBTOtaUpgrade) {
        print("siliconGeckoUpgradeDidCompleteUpdate")
    }
    
    func siliconGeckoUpgrade(_ sender: SiliconGeckoBTOtaUpgrade, didFailWithError error: SiliconGeckoUpgradeError) {
        print("siliconGeckoUpgrade didFailWithError \(error)")
    }
    
    func siliconGeckoUpgrade(_ sender: SiliconGeckoBTOtaUpgrade, didUpdateStatus status: SiliconGeckoBTOtaUpgrade.Status) {
        print("siliconGeckoUpgrade didUpdateStatus \(status)")
    }
    
    func siliconGeckoUpgrade(_ sender: SiliconGeckoBTOtaUpgrade, didSendPage pageIndex: Int, outOf totalPages: Int, progress: Double) {
        print("siliconGeckoUpgrade didSendPage \(pageIndex) outOf \(totalPages)")
    }
    
    func siliconGeckoUpgrade(_ sender: SiliconGeckoBTOtaUpgrade, didLogMessage message: String, level: String) {
        print("siliconGeckoUpgrade didLogMessage: \(message)")
    }
}
```
