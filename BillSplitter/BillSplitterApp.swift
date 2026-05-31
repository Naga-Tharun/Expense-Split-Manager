//
//  BillSplitterApp.swift
//  BillSplitter
//

import SwiftUI
import SwiftData
import AppIntents
import os

private let logger = Logger(subsystem: "com.billsplitter", category: "app")

@main
struct BillSplitterApp: App {

    let sharedModelContainer: ModelContainer
    @State private var balanceCache = BalanceCache()
    @AppStorage("appearanceMode") private var appearanceMode: String = "dark"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil  // "system" follows device setting
        }
    }

    init() {
        logger.info("BillSplitter launching")

        if let container = try? SharedContainer.makeModelContainer() {
            sharedModelContainer = container
        } else {
            // Schema change — delete the old store and retry as last resort
            let storeURL = SharedContainer.storeURL
            let related = [storeURL,
                           storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"),
                           storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")]
            related.forEach { try? FileManager.default.removeItem(at: $0) }
            logger.warning("Schema migration failed — store reset to fresh state")

            guard let freshContainer = try? SharedContainer.makeModelContainer() else {
                fatalError("Could not create ModelContainer even after reset")
            }
            sharedModelContainer = freshContainer
        }

        CurrentUserManager.resolve(in: sharedModelContainer)
        logger.info("App initialized — container ready, current user resolved")

        // Index existing data into Spotlight for home screen search
        Self.reindexSpotlight(in: sharedModelContainer)

        // Tell Siri about our App Shortcuts so voice phrases work immediately.
        // This must be called after any change to shortcuts or their parameters.
        BillSplitterShortcuts.updateAppShortcutParameters()
    }

    /// Bulk re-index all expenses and friends into Core Spotlight.
    private static func reindexSpotlight(in container: ModelContainer) {
        let context = ModelContext(container)
        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let allUsers = (try? context.fetch(FetchDescriptor<User>())) ?? []
        let friends  = allUsers.filter { $0.id != CurrentUserManager.currentUserID }
        let groups   = (try? context.fetch(FetchDescriptor<Group>())) ?? []
        SpotlightIndexer.reindexAll(expenses: expenses, friends: friends, groups: groups)
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
                    .environment(balanceCache)
                    .preferredColorScheme(colorScheme)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .preferredColorScheme(colorScheme)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
