//
//  Settlement.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftUI
import SwiftData
import Foundation

// Settlement Model
@Model
final class Settlement {
    @Attribute(.unique) var id: UUID
    var fromFriend: User?
    var toFriend: User?
    var amount: Double
    var date: Date
    var paymentMethod: String?
    var notes: String?
    var isConfirmed: Bool
    
    init(
        id: UUID = UUID(),
        fromFriend: User? = nil,
        toFriend: User? = nil,
        amount: Double = 0.0,
        date: Date = Date(),
        paymentMethod: String? = nil,
        notes: String? = nil,
        isConfirmed: Bool = false
    ) {
        self.id = id
        self.fromFriend = fromFriend
        self.toFriend = toFriend
        self.amount = amount
        self.date = date
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.isConfirmed = isConfirmed
    }
}

