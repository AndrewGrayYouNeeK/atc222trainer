//
//  Item.swift
//  YouNeeKATC
//
//  Created by Andrew Gray on 5/29/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
