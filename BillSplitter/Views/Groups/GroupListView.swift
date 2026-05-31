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
                NavigationLink(value: group) {
                    GroupRowView(group: group)
                }
            }
            .onDelete(perform: onDelete)
        }
        .refreshable {
            try? await Task.sleep(for: .milliseconds(400))
            Haptics.light()
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
