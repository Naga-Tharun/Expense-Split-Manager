//
//  Expense.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftData
import Foundation

// MARK: - Nested inside SchemaV1 for VersionedSchema support

extension SchemaV1 {

    @Model
    final class Expense {
        @Attribute(.unique) var id: UUID
        var expenseDescription: String
        var amount: Double
        @Attribute(originalName: "category") var categoryRaw: String
        var date: Date
        var notes: String?
        @Attribute(.externalStorage) var receiptImageData: Data?

        // Who paid
        var paidBy: User?

        // Split details
        @Attribute(originalName: "splitType") var splitTypeRaw: String
        var participants: [ExpenseParticipant]?

        // Relationships
        var group: Group?

        // MARK: - Type-safe accessors

        var category: ExpenseCategory {
            get { ExpenseCategory(rawValue: categoryRaw) ?? .general }
            set { categoryRaw = newValue.rawValue }
        }

        var splitType: SplitType {
            get { SplitType(rawValue: splitTypeRaw) ?? .equal }
            set { splitTypeRaw = newValue.rawValue }
        }

        init(
            id: UUID = UUID(),
            expenseDescription: String,
            amount: Double,
            category: ExpenseCategory = .general,
            date: Date = Date(),
            notes: String? = nil,
            splitType: SplitType = .equal
        ) {
            self.id = id
            self.expenseDescription = expenseDescription
            self.amount = amount
            self.categoryRaw = category.rawValue
            self.date = date
            self.notes = notes
            self.splitTypeRaw = splitType.rawValue
        }
    }
}

// Top-level alias so the rest of the app keeps using `Expense` unchanged.
typealias Expense = SchemaV1.Expense
