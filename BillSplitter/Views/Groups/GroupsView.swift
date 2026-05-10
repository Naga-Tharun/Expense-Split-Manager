//
//  GroupsView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct GroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Group.createdAt, order: .reverse) private var groups: [Group]
    @State private var showingAddGroup = false
    @State private var saveError = SaveErrorState()
    @State private var pendingDelete: IndexSet? = nil

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
                    GroupListView(groups: groups, onDelete: { offsets in
                        pendingDelete = offsets
                    })
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddGroup.toggle() } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddGroupView()
            }
            .alert("Delete Group?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let offsets = pendingDelete {
                        Haptics.warning()
                        saveError.perform {
                            for index in offsets {
                                try DataService.deleteGroup(groups[index], context: modelContext)
                            }
                        }
                        pendingDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This group and all its expenses will be permanently removed.")
            }
            .saveErrorAlert($saveError)
        }
    }
}

#Preview {
    GroupsView()
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
