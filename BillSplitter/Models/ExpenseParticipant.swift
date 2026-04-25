//
//  ExpenseParticipant.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftUI
import SwiftData
import Foundation

// Expense Participant (for tracking who owes what)
@Model
final class ExpenseParticipant {
    @Attribute(.unique) var id: UUID
    var friend: User?
    var amountOwed: Double
    var isPaid: Bool
    
    init(
        id: UUID = UUID(),
        friend: User? = nil,
        amountOwed: Double = 0.0,
        isPaid: Bool = false
    ) {
        self.id = id
        self.friend = friend
        self.amountOwed = amountOwed
        self.isPaid = isPaid
    }
}
