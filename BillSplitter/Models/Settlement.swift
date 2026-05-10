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
    @Attribute(originalName: "paymentMethod") var paymentMethodRaw: String?
    var notes: String?
    var isConfirmed: Bool

    // MARK: - Type-safe accessor

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRaw ?? "") ?? .cash }
        set { paymentMethodRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        fromFriend: User? = nil,
        toFriend: User? = nil,
        amount: Double = 0.0,
        date: Date = Date(),
        paymentMethod: PaymentMethod = .cash,
        notes: String? = nil,
        isConfirmed: Bool = false
    ) {
        self.id = id
        self.fromFriend = fromFriend
        self.toFriend = toFriend
        self.amount = amount
        self.date = date
        self.paymentMethodRaw = paymentMethod.rawValue
        self.notes = notes
        self.isConfirmed = isConfirmed
    }
}
