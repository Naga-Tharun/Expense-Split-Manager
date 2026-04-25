import SwiftUI

struct FriendListView: View {
    let friends: [User]
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        List {
            ForEach(friends) { friend in
                NavigationLink {
                    FriendDetailView(friend: friend)
                } label: {
                    FriendRowView(friend: friend)
                }
            }
            .onDelete(perform: onDelete)
        }
    }
}

#Preview {
    NavigationStack {
        FriendListView(
            friends: [
                User(name: "Alex", profileColor: "#007AFF"),
                User(name: "Jordan", profileColor: "#FF9500")
            ],
            onDelete: { _ in }
        )
        .modelContainer(for: [User.self], inMemory: true)
    }
}
