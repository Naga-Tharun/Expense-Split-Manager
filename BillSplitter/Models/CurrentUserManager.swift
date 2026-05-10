//
//  CurrentUserManager.swift
//  BillSplitter
//
//  Single source of truth for the "me" User record.
//  Key "currentUserID" is shared with @AppStorage in all views.
//

import SwiftData
import Foundation

enum CurrentUserManager {

    static let idKey    = "currentUserID"
    static let nameKey  = "userName"
    static let colorKey = "userColor"

    @discardableResult
    static func resolve(in container: ModelContainer) -> User {
        let context = container.mainContext

        // Fetch ALL users with NO predicate.
        // A predicate fetch can silently return empty on an unhydrated
        // context (which happens when called from App.init), causing a
        // duplicate User to be created on every launch.
        let allUsers = (try? context.fetch(FetchDescriptor<User>())) ?? []

        // 1. Stored UUID matches an existing record → done
        if let raw  = UserDefaults.standard.string(forKey: idKey),
           let uuid = UUID(uuidString: raw),
           let me   = allUsers.first(where: { $0.id == uuid }) {
            return me
        }

        // 2. Users exist but UUID is missing/stale (e.g. after reinstall)
        //    Adopt the first user rather than creating a duplicate.
        if let existing = allUsers.first {
            UserDefaults.standard.set(existing.id.uuidString, forKey: idKey)
            UserDefaults.standard.set(existing.name,          forKey: nameKey)
            UserDefaults.standard.set(existing.profileColor,  forKey: colorKey)
            UserDefaults.standard.synchronize()
            return existing
        }

        // 3. Truly first launch — create the User record
        let name  = UserDefaults.standard.string(forKey: nameKey)  ?? "You"
        let color = UserDefaults.standard.string(forKey: colorKey) ?? "#00BCD4"
        let me    = User(name: name, profileColor: color)
        context.insert(me)
        try? context.save()

        UserDefaults.standard.set(me.id.uuidString, forKey: idKey)
        UserDefaults.standard.synchronize()
        return me
    }

    // MARK: - Convenience accessors

    /// The stored current-user UUID, if any.
    static var currentUserID: UUID? {
        guard let raw = UserDefaults.standard.string(forKey: idKey) else { return nil }
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
        guard let raw = UserDefaults.standard.string(forKey: idKey),
              let uuid = UUID(uuidString: raw),
              let me   = allUsers.first(where: { $0.id == uuid }) else { return }
        me.name         = name
        me.profileColor = color
        try? context.save()
        UserDefaults.standard.set(name,  forKey: nameKey)
        UserDefaults.standard.set(color, forKey: colorKey)
        UserDefaults.standard.synchronize()
    }
}
