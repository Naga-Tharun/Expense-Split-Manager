//
//  FriendsView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BalanceCache.self) private var cache
    @Query(sort: \User.name) private var allUsers:  [User]
    @Query private var expenses:                    [Expense]
    @Query private var settlements:                 [Settlement]
    @Query private var allParticipants:              [ExpenseParticipant]

    @State private var isPresentingAddFriend = false
    @State private var friendToDelete: User? = nil
    @State private var saveError = SaveErrorState()
    @State private var navigationPath = NavigationPath()

    /// Deep link from Spotlight — when set, navigates to that friend's detail.
    @Binding var deepLinkFriendID: UUID?

    init(deepLinkFriendID: Binding<UUID?> = .constant(nil)) {
        _deepLinkFriendID = deepLinkFriendID
    }

    private var currentUserID: UUID? { CurrentUserManager.currentUserID }

    private var friends: [User] {
        CurrentUserManager.friends(from: allUsers)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            friendsContent
                .navigationTitle("Friends")
                .navigationDestination(for: User.self) { friend in
                    FriendDetailView(friend: friend)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isPresentingAddFriend = true } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
                .onAppear { refreshCache() }
                .onChange(of: deepLinkFriendID) { _, newID in
                    guard let friendID = newID,
                          let friend = friends.first(where: { $0.id == friendID }) else { return }
                    navigationPath = NavigationPath()
                    navigationPath.append(friend)
                    deepLinkFriendID = nil
                }
                .sheet(isPresented: $isPresentingAddFriend) { AddFriendView() }
                .alert("Delete Friend?", isPresented: Binding(
                    get: { friendToDelete != nil },
                    set: { if !$0 { friendToDelete = nil } }
                )) {
                    Button("Delete", role: .destructive) {
                        if let friend = friendToDelete {
                            Haptics.warning()
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
                .saveErrorAlert($saveError)
        }
    }

    @ViewBuilder
    private var friendsContent: some View {
        if !cache.isLoaded {
            ProgressView("Loading balances…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if friends.isEmpty {
            ContentUnavailableView(
                "No Friends Added",
                systemImage: "person.2.fill",
                description: Text("Add friends to start tracking shared expenses")
            )
        } else {
            List {
                ForEach(friends) { friend in
                    NavigationLink(value: friend) {
                        FriendRowView(friend: friend, balance: cache.balance(for: friend.id))
                    }
                }
                .onDelete { offsets in
                    if let idx = offsets.first {
                        friendToDelete = friends[idx]
                    }
                }
            }
            .refreshable {
                refreshCache()
                try? await Task.sleep(for: .milliseconds(300))
                Haptics.light()
            }
        }
    }

    private func refreshCache() {
        guard let uid = currentUserID else { return }
        cache.refresh(expenses: expenses, settlements: settlements, currentUserID: uid)
    }

    private func deleteFriend(_ friend: User) {
        saveError.perform {
            try DataService.deleteFriend(
                friend,
                allParticipants: allParticipants,
                allSettlements: settlements,
                context: modelContext
            )
        }
        refreshCache()
    }
}

#Preview {
    FriendsView()
        .environment(BalanceCache())
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
