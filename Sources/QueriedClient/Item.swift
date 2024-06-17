//
//  File.swift
//  
//
//  Created by Juan Arzola on 6/17/24.
//

import SwiftData
import Foundation

@Model
final class Item {
    var timestamp: Date
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
