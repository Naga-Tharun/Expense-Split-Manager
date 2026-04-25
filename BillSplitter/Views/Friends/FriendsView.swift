//
//  FriendsView.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftUI
import SwiftData

struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.name) private var friends: [User]
    @State private var isPresentingAddFriend = false
    
    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if friends.isEmpty {
                    ContentUnavailableView(
                        "No Friends Added",
                        systemImage: "person.2.fill",
                        description: Text("Add friends to start tracking shared expenses")
                    )
                } else {
                    FriendListView(friends: friends, onDelete: deleteFriends)
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddFriend) {
                AddFriendView()
            }
        }
    }
    
    private func deleteFriends(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(friends[index])
        }
    }
}

#Preview {
    FriendsView()
        .modelContainer(for: [User.self], inMemory: true)
        .preferredColorScheme(.dark)
}
