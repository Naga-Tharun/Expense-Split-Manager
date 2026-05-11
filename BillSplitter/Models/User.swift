//
//  User.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftData
import Foundation

// MARK: - Nested inside SchemaV1 for VersionedSchema support

extension SchemaV1 {

    @Model
    final class User {
        @Attribute(.unique) var id: UUID
        var name: String
        var profileColor: String // Store color as hex string
        var createdAt: Date

        // Relationships
        @Relationship(deleteRule: .cascade, inverse: \Expense.paidBy)
        var expenses: [Expense]?

        @Relationship(deleteRule: .nullify)
        var groups: [Group]?  // inverse defined on Group.members

        @Relationship(deleteRule: .cascade, inverse: \Settlement.fromFriend)
        var settlementsFrom: [Settlement]?

        @Relationship(deleteRule: .cascade, inverse: \Settlement.toFriend)
        var settlementsTo: [Settlement]?

        init(
            id: UUID = UUID(),
            name: String,
            profileColor: String = "#000000",
            createdAt: Date = Date()
        ) {
            self.id = id
            self.name = name
            self.profileColor = profileColor
            self.createdAt = createdAt
        }
    }
}

// Top-level alias so the rest of the app keeps using `User` unchanged.
typealias User = SchemaV1.User
