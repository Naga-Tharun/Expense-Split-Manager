//
//  GroupMembersSection.swift
//  BillSplitter
//
//  Displays the list of group members with swipe-to-remove
//  and an "Add Member" button at the bottom.
//

import SwiftUI

struct GroupMembersSection: View {
    let members: [User]
    let currentUserID: UUID?
    var onRemove: ((IndexSet) -> Void)? = nil
    var onAddMember: () -> Void

    var body: some View {
        Section("Members") {
            if members.isEmpty {
                Text("No members yet").foregroundStyle(.secondary).font(.subheadline)
            } else {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        AvatarView(user: member, size: 38)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(member.name).font(.body)
                            if member.id == currentUserID {
                                Text("you").font(.caption2).foregroundStyle(.cyan)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    onRemove?(offsets)
                }
            }

            Button(action: onAddMember) {
                Label("Add Member", systemImage: "person.badge.plus").foregroundStyle(.cyan)
            }
        }
    }
}

#Preview {
    List {
        GroupMembersSection(
            members: [],
            currentUserID: nil,
            onAddMember: {}
        )
    }
    .preferredColorScheme(.dark)
}
