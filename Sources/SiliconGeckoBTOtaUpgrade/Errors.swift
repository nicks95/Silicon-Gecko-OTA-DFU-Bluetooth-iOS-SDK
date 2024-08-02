//
//  Untitled.swift
//  SiliconGeckoBTOtaUpgrade
//
//  Created by Nicolas Antonini on 02/08/24.
//

import Foundation
import CoreBluetooth

public enum SiliconGeckoUpgradeError: LocalizedError {
    case bleStatusError(CBManagerState)
    case blePeripheralNotFound
    case connectionError
    case operationFailed
    case deviceConfigurationError

    case crcError
    case wrongState
    case buffersFull
    case imageTooBig
    case notSupported
    case bootloader
    case incorrectBootloader
    case applicationOverlapBootloader
    case incompatibleBootloaderVersion
    case attErrorApplicationVersionCheckFail
    
    public var errorDescription: String? {
        switch self {
        case .connectionError:
            return "A BLE connection error occurred."
        case .operationFailed:
            return "A write operation failed."
        case .blePeripheralNotFound:
            return "The provided BLE peripheral was not found."
        case .bleStatusError:
            return "BLE is in a wrong status (unauthorized, unavailable...)."
        case .deviceConfigurationError:
            return "The peripheral has a wrong GATT table configuration."
        case .crcError:
            return "CRC check failed, or signature failure (if enabled)."
        case .wrongState:
            return  "This error is returned if the OTA has not been started (by writing value 0x0 to the control endpoint) and the client tries to send data or terminate the update."
        case .buffersFull:
            return "AppLoader has run out of buffer space."
        case .imageTooBig:
            return  "New firmware image is too large to fit into flash, or it overlaps with AppLoader."
        case .notSupported:
            return "GBL file parsing failed. Potential causes are for example:  1) Attempting a partial update from one SDK version to another (such as 2.3.0 to 2.4.0). 2) The file is not a valid GBL file (for example, client is sending an EBL file)."
        case .bootloader:
            return "The Gecko bootloader cannot erase or write flash as requested by AppLoader, for example if the download area is too small to fit the entire GBL image."
        case .incorrectBootloader:
            return "Wrong type of bootloader. For example, target device has UART DFU bootloader instead of OTA bootloader installed."
        case .applicationOverlapBootloader:
            return "New application image is rejected because it would overlap with the AppLoader."
        case .incompatibleBootloaderVersion:
            return "AppLoader in Bluetooth SDK v3.0 requires Gecko Bootloader v1.11."
        case .attErrorApplicationVersionCheckFail:
            return "AppLoader fails checking application version."
        }
    }
}

