//
//  FriendListView.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftUI
import SwiftData

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
        .withPreviewContainer()
    }
}
