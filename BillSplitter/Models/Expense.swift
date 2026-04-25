//
//  Expense.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftUI
import SwiftData
import Foundation

// Expense Model
@Model
final class Expense {
    @Attribute(.unique) var id: UUID
    var expenseDescription: String
    var amount: Double
    var category: String
    var date: Date
    var notes: String?
    var receiptImageData: Data?
    
    // Who paid
    var paidBy: User?
    
    // Split details
    var splitType: String // "equal", "custom", "percentage"
    var participants: [ExpenseParticipant]?
    
    // Relationships
    var group: Group?
    
    init(
        id: UUID = UUID(),
        expenseDescription: String,
        amount: Double,
        category: String = "general",
        date: Date = Date(),
        notes: String? = nil,
        splitType: String = "equal"
    ) {
        self.id = id
        self.expenseDescription = expenseDescription
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes
        self.splitType = splitType
    }
}
