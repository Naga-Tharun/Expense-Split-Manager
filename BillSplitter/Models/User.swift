//
//  User.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftUI
import SwiftData
import Foundation

// User Model
@Model
final class User {
    @Attribute(.unique) var id: UUID
    var name: String
    var profileColor: String // Store color as hex string
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var expenses: [Expense]?
    @Relationship(deleteRule: .nullify) var groups: [Group]?
    
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
