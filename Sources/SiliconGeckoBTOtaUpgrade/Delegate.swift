//
//  Delegate.swift
//  SiliconGeckoBTOtaUpgrade
//
//  Created by Nicolas Antonini on 02/08/24.
//

public protocol SiliconGeckoUpgradeDelegate: AnyObject {
    func siliconGeckoUpgradeDidCompleteUpdate(_ sender: SiliconGeckoBTOtaUpgrade)
    func siliconGeckoUpgrade(_ sender: SiliconGeckoBTOtaUpgrade, didFailWithError error: SiliconGeckoUpgradeError)
    func siliconGeckoUpgrade(_ sender: SiliconGeckoBTOtaUpgrade, didUpdateStatus status: SiliconGeckoBTOtaUpgrade.Status)
    func siliconGeckoUpgrade(_ sender: SiliconGeckoBTOtaUpgrade, didSendPage pageIndex: Int, outOf totalPages: Int, progress: Double)
    func siliconGeckoUpgrade(_ sender: SiliconGeckoBTOtaUpgrade, didLogMessage message: String, level: String)
}
