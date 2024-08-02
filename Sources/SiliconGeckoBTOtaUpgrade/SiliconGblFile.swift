//
//  SiliconGblFile.swift
//  SiliconGeckoBTOtaUpgrade
//
//  Created by Nicolas Antonini on 02/08/24.
//

import Foundation

public class SiliconGblFile {
    var data: Data
    
    public init(data: Data) {
        self.data = data
    }
    
    public init(url: URL) throws {
        self.data = try Data(contentsOf: url)
    }
    
}
