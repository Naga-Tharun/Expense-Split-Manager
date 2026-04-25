//
//  BillSplitterApp.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

@main
struct BillSplitterApp: App {

    let sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([
            User.self, Group.self, Expense.self,
            ExpenseParticipant.self, Settlement.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            fatalError("Could not create ModelContainer")
        }
        sharedModelContainer = container

        // Runs BEFORE any SwiftUI view body is evaluated.
        // Uses fetch-all (no predicate) to work on an unhydrated context.
        // Writes "currentUserID" to UserDefaults so every @AppStorage
        // in every view gets the correct UUID on the very first render.
        CurrentUserManager.resolve(in: container)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
