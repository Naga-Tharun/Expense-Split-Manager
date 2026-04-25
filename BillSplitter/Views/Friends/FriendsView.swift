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

    @AppStorage("currentUserID") private var currentUserIDString: String = ""
    @State private var isPresentingAddFriend = false

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
                .onDelete(perform: deleteFriends)
            }
        }
    }

    private func deleteFriends(offsets: IndexSet) {
        for index in offsets { modelContext.delete(friends[index]) }
    }
}

#Preview {
    FriendsView()
        .withPreviewContainer()
}
