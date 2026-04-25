//
//  GroupsView.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftUI
import SwiftData

struct GroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Group.createdAt, order: .reverse) private var groups: [Group]
    @State private var showingAddGroup = false
    
    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if groups.isEmpty {
                    ContentUnavailableView(
                        "No Groups Yet",
                        systemImage: "person.3.fill",
                        description: Text("Create a group to start splitting expenses with friends")
                    )
                } else {
                    GroupListView(groups: groups, onDelete: deleteGroups)
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddGroup.toggle()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddGroupView()
            }
        }
    }
    
    private func addSampleGroup() {
        let groupNames = ["Weekend Trip", "Roommates", "Office Lunch", "Vacation 2025"]
        let icons = ["beach.umbrella.fill", "house.fill", "fork.knife", "airplane"]
        let colors = ["#FF9500", "#34C759", "#5856D6", "#007AFF"]
        let index = groups.count % groupNames.count
        
        let newGroup = Group(
            name: groupNames[index],
            groupDescription: "Shared expenses for \(groupNames[index])",
            iconName: icons[index],
            colorHex: colors[index]
        )
        modelContext.insert(newGroup)
    }
    
    private func deleteGroups(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(groups[index])
        }
    }
}

#Preview {
    GroupsView()
        .modelContainer(for: [Group.self], inMemory: true)
        .preferredColorScheme(.dark)
}
