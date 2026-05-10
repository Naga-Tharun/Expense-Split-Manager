//
//  Group.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftData
import Foundation

// Group Model
@Model
final class Group {
    @Attribute(.unique) var id: UUID
    var name: String
    var groupDescription: String?
    var createdAt: Date
    var iconName: String // SF Symbol name
    var colorHex: String
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Expense.group) var expenses: [Expense]?
    @Relationship(deleteRule: .nullify, inverse: \User.groups) var members: [User]?
    
    init(
        id: UUID = UUID(),
        name: String,
        groupDescription: String? = nil,
        createdAt: Date = Date(),
        iconName: String = "person.3.fill",
        colorHex: String = "#FF9500"
    ) {
        self.id = id
        self.name = name
        self.groupDescription = groupDescription
        self.createdAt = createdAt
        self.iconName = iconName
        self.colorHex = colorHex
    }
}
