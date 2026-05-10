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
    @State private var saveError = SaveErrorState()
    
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
            .saveErrorAlert($saveError)
        }
    }

    private func deleteGroups(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(groups[index])
        }
        saveError.perform { try modelContext.save() }
    }
}

#Preview {
    GroupsView()
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
