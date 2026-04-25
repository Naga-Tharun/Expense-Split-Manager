//
//  CurrentUserManager.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

/// Fetches (or lazily creates) the single "me" User record.
/// Inject via .environment(\.currentUserManager, ...) or as an @Observable.
@Observable
final class CurrentUserManager {

    /// The persisted User record for "me". Nil until `resolve()` is called.
    private(set) var me: User?

    /// Key used to persist the current user's UUID across launches.
    private let key = "currentUserID"

    func resolve(in context: ModelContext) {
        // 1. Try to find an existing UUID stored in UserDefaults
        if let raw  = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: raw) {
            // 2. Fetch that User from SwiftData
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.id == uuid }
            )
            if let found = try? context.fetch(descriptor).first {
                me = found
                return
            }
        }

        // 3. No existing user — create one with stored name/color prefs
        let name  = UserDefaults.standard.string(forKey: "userName")  ?? "You"
        let color = UserDefaults.standard.string(forKey: "userColor") ?? "#00BCD4"
        let newUser = User(name: name, profileColor: color)
        context.insert(newUser)
        try? context.save()

        // 4. Persist the UUID
        UserDefaults.standard.set(newUser.id.uuidString, forKey: key)
        me = newUser
    }

    /// Call whenever the user changes their name/color in ProfileView.
    func updateProfile(name: String, color: String, in context: ModelContext) {
        guard let me else { return }
        me.name         = name
        me.profileColor = color
        try? context.save()
        UserDefaults.standard.set(name,  forKey: "userName")
        UserDefaults.standard.set(color, forKey: "userColor")
    }
}
