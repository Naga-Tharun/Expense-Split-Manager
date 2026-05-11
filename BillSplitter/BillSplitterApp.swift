//
//  BillSplitterApp.swift
//  BillSplitter
//

import SwiftUI
import SwiftData
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
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let container = try? ModelContainer(
            for: schema,
            migrationPlan: BillSplitterMigrationPlan.self,
            configurations: [config]
        ) {
            sharedModelContainer = container
        } else {
            // Schema change — delete the old store and retry as last resort
            let storeURL = config.url
            let related = [storeURL,
                           storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"),
                           storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")]
            related.forEach { try? FileManager.default.removeItem(at: $0) }
            logger.warning("Schema migration failed — store reset to fresh state")

            guard let freshContainer = try? ModelContainer(
                for: schema,
                migrationPlan: BillSplitterMigrationPlan.self,
                configurations: [config]
            ) else {
                fatalError("Could not create ModelContainer even after reset")
            }
            sharedModelContainer = freshContainer
        }

        CurrentUserManager.resolve(in: sharedModelContainer)
        logger.info("App initialized — container ready, current user resolved")
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
