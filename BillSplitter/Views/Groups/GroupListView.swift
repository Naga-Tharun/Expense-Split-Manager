//
//  GroupListView.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 24/11/25.
//

import SwiftUI
import SwiftData

struct GroupListView: View {
    let groups: [Group]
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        List {
            ForEach(groups) { group in
                NavigationLink {
                    GroupDetailView(group: group)
                } label: {
                    GroupRowView(group: group)
                }
            }
            .onDelete(perform: onDelete)
        }
    }
}

#Preview {
    NavigationStack {
        GroupListView(
            groups: [
                Group(name: "Flatmates", groupDescription: "Bills and Other Expenses", iconName: "house.fill"),
                Group(name: "Friends", groupDescription: "Other Expenses", iconName: "tree.fill")
            ],
            onDelete: { _ in }
        )
        .withPreviewContainer()
    }
}
