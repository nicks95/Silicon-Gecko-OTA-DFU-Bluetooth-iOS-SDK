//
//  OtaService.swift
//  SiliconGeckoBTOtaUpgrade
//
//  Created by Nicolas Antonini on 02/08/24.
//
import CoreBluetooth
import Foundation

class OTAService {
    nonisolated(unsafe) static let otaServiceUUID: CBUUID = CBUUID(string: "1D14D6EE-FD63-4FA1-BFA4-8F47B42119F0")
    nonisolated(unsafe) static let otaControlAttributeUUID: CBUUID = CBUUID(string: "F7BF3564-FB6D-4E53-88A4-5E37E0326063")
    nonisolated(unsafe) static let otaDataAttributeUUID: CBUUID = CBUUID(string: "984227F3-34FC-4045-A5D0-2C581F81A153")
}
