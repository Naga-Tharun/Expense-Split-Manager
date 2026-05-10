//
//  BillSplitterApp.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

@main
struct BillSplitterApp: App {

    let sharedModelContainer: ModelContainer
    @State private var balanceCache = BalanceCache()

    init() {
        let schema = Schema([
            User.self, Group.self, Expense.self,
            ExpenseParticipant.self, Settlement.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            sharedModelContainer = container
        } else {
            // Schema migration failed — delete the old store and retry
            let storeURL = config.url
            let related = [storeURL,
                           storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"),
                           storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")]
            related.forEach { try? FileManager.default.removeItem(at: $0) }

            guard let freshContainer = try? ModelContainer(for: schema, configurations: [config]) else {
                fatalError("Could not create ModelContainer even after reset")
            }
            sharedModelContainer = freshContainer
        }

        CurrentUserManager.resolve(in: sharedModelContainer)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(balanceCache)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
