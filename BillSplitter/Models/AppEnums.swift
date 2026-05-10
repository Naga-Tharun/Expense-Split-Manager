//
//  AppEnums.swift
//  BillSplitter
//
//  Type-safe enums for split types, expense categories,
//  and payment methods. Stored as raw String values for
//  SwiftData compatibility.
//

import SwiftUI
import Foundation

// MARK: - Split Type

enum SplitType: String, Codable, CaseIterable, Identifiable {
    case equal      = "equal"
    case custom     = "custom"
    case percentage = "percentage"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .equal:      return "Equal"
        case .custom:     return "Custom \(CurrencyHelper.symbol)"
        case .percentage: return "By %"
        }
    }
}

// MARK: - Expense Category

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case general       = "general"
    case food          = "food"
    case transport     = "transport"
    case accommodation = "accommodation"
    case entertainment = "entertainment"
    case shopping      = "shopping"
    case utilities     = "utilities"
    case travel        = "travel"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:       return "square.grid.2x2.fill"
        case .food:          return "fork.knife"
        case .transport:     return "car.fill"
        case .accommodation: return "house.fill"
        case .entertainment: return "theatermasks.fill"
        case .shopping:      return "cart.fill"
        case .utilities:     return "bolt.fill"
        case .travel:        return "airplane"
        }
    }

    var label: String {
        switch self {
        case .general:       return "General"
        case .food:          return "Food"
        case .transport:     return "Transport"
        case .accommodation: return "Stay"
        case .entertainment: return "Fun"
        case .shopping:      return "Shopping"
        case .utilities:     return "Utilities"
        case .travel:        return "Travel"
        }
    }
}

// MARK: - Payment Method

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash         = "cash"
    case upi          = "upi"
    case bankTransfer = "bank transfer"
    case card         = "card"
    case other        = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cash:         return "Cash"
        case .upi:          return "UPI"
        case .bankTransfer: return "Bank Transfer"
        case .card:         return "Card"
        case .other:        return "Other"
        }
    }

    var icon: String {
        switch self {
        case .cash:         return "banknote.fill"
        case .upi:          return "iphone.radiowaves.left.and.right"
        case .bankTransfer: return "building.columns.fill"
        case .card:         return "creditcard.fill"
        case .other:        return "ellipsis.circle.fill"
        }
    }
}
