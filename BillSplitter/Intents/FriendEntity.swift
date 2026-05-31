//
//  FriendEntity.swift
//  BillSplitter
//
//  AppEntity representing a friend for Siri App Intents.
//  Provides dynamic lookup so Siri can resolve friend names
//  spoken by the user.
//

import AppIntents
import SwiftData
import Foundation

/// Lightweight entity that Siri uses to identify a friend by name.
struct FriendEntity: AppEntity {

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Friend"
    }

    static var defaultQuery = FriendQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - Entity Query

/// Resolves friend names from the SwiftData store for Siri.
struct FriendQuery: EntityQuery {

    func entities(for identifiers: [UUID]) async throws -> [FriendEntity] {
        try await MainActor.run {
            let friends = try fetchFriends()
            return friends.filter { identifiers.contains($0.id) }
                .map { FriendEntity(id: $0.id, name: $0.name) }
        }
    }

    func suggestedEntities() async throws -> [FriendEntity] {
        try await MainActor.run {
            try fetchFriends()
                .map { FriendEntity(id: $0.id, name: $0.name) }
        }
    }

    // MARK: - Private

    @MainActor
    private func fetchFriends() throws -> [User] {
        let container = try SharedContainer.makeModelContainer()
        let context = ModelContext(container)
        let allUsers = try context.fetch(FetchDescriptor<User>(sortBy: [SortDescriptor(\.name)]))
        return CurrentUserManager.friends(from: allUsers)
    }
}

// MARK: - String Search

extension FriendQuery: EntityStringQuery {

    func entities(matching string: String) async throws -> [FriendEntity] {
        try await MainActor.run {
            let friends = try fetchFriends()
            let lowered = string.lowercased()
            return friends
                .filter { $0.name.lowercased().contains(lowered) }
                .map { FriendEntity(id: $0.id, name: $0.name) }
        }
    }
}
