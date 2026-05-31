//
//  CategoryEntity.swift
//  BillSplitter
//
//  AppEnum wrapping ExpenseCategory for use in Siri App Intents.
//

import AppIntents

/// Maps ExpenseCategory cases to Siri-displayable values.
enum CategoryAppEnum: String, AppEnum {

    case general       = "general"
    case food          = "food"
    case transport     = "transport"
    case accommodation = "accommodation"
    case entertainment = "entertainment"
    case shopping      = "shopping"
    case utilities     = "utilities"
    case travel        = "travel"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Category"
    }

    static var caseDisplayRepresentations: [CategoryAppEnum: DisplayRepresentation] {
        [
            .general:       "General",
            .food:          "Food",
            .transport:     "Transport",
            .accommodation: "Stay",
            .entertainment: "Fun",
            .shopping:      "Shopping",
            .utilities:     "Utilities",
            .travel:        "Travel"
        ]
    }

    /// Converts back to the model enum.
    var modelCategory: ExpenseCategory {
        ExpenseCategory(rawValue: rawValue) ?? .general
    }
}
