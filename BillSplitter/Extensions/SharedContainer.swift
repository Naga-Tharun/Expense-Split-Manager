//
//  SharedContainer.swift
//  BillSplitter
//
//  Provides the shared App Group container URL and UserDefaults suite
//  used by both the main app and the WidgetKit extension.
//

import Foundation
import SwiftData

enum SharedContainer {

    /// The App Group identifier — must match the entitlement on both targets.
    static let appGroupID = "group.project.ios.BillSplitter"

    /// Shared UserDefaults suite accessible from both the app and widget.
    static let defaults: UserDefaults = {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }()

    /// The shared SwiftData store URL inside the App Group container.
    /// Falls back to the default location when the group isn't available
    /// (e.g. in unit tests or Previews).
    static var storeURL: URL {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            return containerURL.appending(path: "BillSplitter.store")
        }
        // Fallback for tests / previews / simulator without entitlement
        return URL.applicationSupportDirectory.appending(path: "BillSplitter.store")
    }

    /// Creates a ModelContainer pointing at the shared store.
    ///
    /// - Parameters:
    ///   - inMemory: `true` for unit tests and previews.
    ///   - readOnly: `true` for the widget extension (no writes needed).
    static func makeModelContainer(inMemory: Bool = false, readOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let config: ModelConfiguration

        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            config = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: !readOnly
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: BillSplitterMigrationPlan.self,
            configurations: [config]
        )
    }
}
