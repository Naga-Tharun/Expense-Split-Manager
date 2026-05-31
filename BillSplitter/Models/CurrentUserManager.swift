//
//  CurrentUserManager.swift
//  BillSplitter
//
//  Single source of truth for the "me" User record.
//  Key "currentUserID" is shared with @AppStorage in all views.
//

import SwiftData
import Foundation
import os

private let logger = Logger(subsystem: "com.billsplitter", category: "currentUser")

enum CurrentUserManager {

    static let idKey    = "currentUserID"
    static let nameKey  = "userName"
    static let colorKey = "userColor"

    /// Shared defaults — accessible from both the app and widget extension.
    private static var sharedDefaults: UserDefaults { SharedContainer.defaults }

    @discardableResult
    static func resolve(in container: ModelContainer) -> User {
        let context = container.mainContext

        // Fetch ALL users with NO predicate.
        // A predicate fetch can silently return empty on an unhydrated
        // context (which happens when called from App.init), causing a
        // duplicate User to be created on every launch.
        let allUsers = (try? context.fetch(FetchDescriptor<User>())) ?? []

        // 1. Stored UUID matches an existing record → done
        if let raw  = sharedDefaults.string(forKey: idKey),
           let uuid = UUID(uuidString: raw),
           let me   = allUsers.first(where: { $0.id == uuid }) {
            return me
        }

        // Fallback: check standard defaults (pre-migration)
        if let raw  = UserDefaults.standard.string(forKey: idKey),
           let uuid = UUID(uuidString: raw),
           let me   = allUsers.first(where: { $0.id == uuid }) {
            // Migrate to shared defaults
            syncToShared(me)
            return me
        }

        // 2. Users exist but UUID is missing/stale (e.g. after reinstall)
        //    Adopt the first user rather than creating a duplicate.
        if let existing = allUsers.first {
            syncToShared(existing)
            return existing
        }

        // 3. Truly first launch — create the User record
        let name  = sharedDefaults.string(forKey: nameKey)
            ?? UserDefaults.standard.string(forKey: nameKey)
            ?? "You"
        let color = sharedDefaults.string(forKey: colorKey)
            ?? UserDefaults.standard.string(forKey: colorKey)
            ?? "#00BCD4"
        let me    = User(name: name, profileColor: color)
        context.insert(me)
        do {
            try context.save()
        } catch {
            logger.error("Failed to save new user: \(error.localizedDescription)")
        }

        syncToShared(me)
        return me
    }

    /// Writes user info to both shared and standard defaults.
    private static func syncToShared(_ user: User) {
        for store in [sharedDefaults, .standard] {
            store.set(user.id.uuidString, forKey: idKey)
            store.set(user.name,          forKey: nameKey)
            store.set(user.profileColor,  forKey: colorKey)
        }
    }

    // MARK: - Convenience accessors

    /// The stored current-user UUID, if any.
    /// Checks shared defaults first (for widget access), falls back to standard.
    static var currentUserID: UUID? {
        let raw = sharedDefaults.string(forKey: idKey)
            ?? UserDefaults.standard.string(forKey: idKey)
        guard let raw else { return nil }
        return UUID(uuidString: raw)
    }

    /// Returns the current User from the given user list.
    static func currentUser(from allUsers: [User]) -> User? {
        guard let uid = currentUserID else { return nil }
        return allUsers.first { $0.id == uid }
    }

    /// Returns all users except the current user (i.e. the friend list).
    static func friends(from allUsers: [User]) -> [User] {
        guard let uid = currentUserID else { return allUsers }
        return allUsers.filter { $0.id != uid }
    }

    static func updateProfile(name: String, color: String, in context: ModelContext) {
        let allUsers = (try? context.fetch(FetchDescriptor<User>())) ?? []
        guard let uuid = currentUserID,
              let me   = allUsers.first(where: { $0.id == uuid }) else { return }
        me.name         = name
        me.profileColor = color
        do {
            try context.save()
        } catch {
            logger.error("Failed to update profile: \(error.localizedDescription)")
        }
        syncToShared(me)
    }
}
