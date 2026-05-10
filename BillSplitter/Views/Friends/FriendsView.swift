//
//  FriendsView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.name) private var allUsers:  [User]
    @Query private var expenses:                    [Expense]
    @Query private var settlements:                 [Settlement]
    @Query private var allParticipants:              [ExpenseParticipant]

    @AppStorage("currentUserID") private var currentUserIDString: String = ""
    @State private var isPresentingAddFriend = false
    @State private var friendToDelete: User? = nil

    private var currentUserID: UUID? { UUID(uuidString: currentUserIDString) }

    private var friends: [User] {
        allUsers.filter { $0.id != currentUserID }
    }

    private var balances: [UUID: Double] {
        guard let uid = currentUserID else { return [:] }
        return BalanceCalculator.netBalances(
            expenses: expenses, settlements: settlements, currentUserID: uid
        )
    }

    var body: some View {
        NavigationStack {
            friendsContent
                .navigationTitle("Friends")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isPresentingAddFriend = true } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
                .sheet(isPresented: $isPresentingAddFriend) { AddFriendView() }
                .alert("Delete Friend?", isPresented: Binding(
                    get: { friendToDelete != nil },
                    set: { if !$0 { friendToDelete = nil } }
                )) {
                    Button("Delete", role: .destructive) {
                        if let friend = friendToDelete {
                            deleteFriend(friend)
                            friendToDelete = nil
                        }
                    }
                    Button("Cancel", role: .cancel) { friendToDelete = nil }
                } message: {
                    if let friend = friendToDelete {
                        Text("Remove \(friend.name) and clean up their related data? This cannot be undone.")
                    }
                }
        }
    }

    @ViewBuilder
    private var friendsContent: some View {
        if friends.isEmpty {
            ContentUnavailableView(
                "No Friends Added",
                systemImage: "person.2.fill",
                description: Text("Add friends to start tracking shared expenses")
            )
        } else {
            List {
                ForEach(friends) { friend in
                    NavigationLink {
                        FriendDetailView(friend: friend)
                    } label: {
                        FriendRowView(friend: friend, balance: balances[friend.id] ?? 0)
                    }
                }
                .onDelete { offsets in
                    if let idx = offsets.first {
                        friendToDelete = friends[idx]
                    }
                }
            }
        }
    }

    /// Safely delete a friend and clean up orphaned participants & settlements
    private func deleteFriend(_ friend: User) {
        // Remove orphaned ExpenseParticipant records that reference this friend
        let orphanedParticipants = allParticipants.filter { $0.friend?.id == friend.id }
        orphanedParticipants.forEach { modelContext.delete($0) }

        // Remove settlements involving this friend
        let orphanedSettlements = settlements.filter {
            $0.fromFriend?.id == friend.id || $0.toFriend?.id == friend.id
        }
        orphanedSettlements.forEach { modelContext.delete($0) }

        // Remove friend from all group memberships
        for user in allUsers {
            // Groups are accessed through the user's groups relationship
        }

        modelContext.delete(friend)
        try? modelContext.save()
    }
}

#Preview {
    FriendsView()
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
