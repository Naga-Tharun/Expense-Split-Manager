//
//  GroupRowView.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 24/11/25.
//

import SwiftUI
import SwiftData

struct GroupRowView: View {
    let group: Group
    
    var body: some View {
        HStack(spacing: 16) {
            // Group Icon
            ZStack {
                Circle()
                    .fill(Color(hex: group.colorHex).opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: group.iconName)
                    .font(.title2)
                    .foregroundStyle(Color(hex: group.colorHex))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                
                if let description = group.groupDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text("\(group.members?.count ?? 0) members")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GroupRowView(group: Group(name: "Flatmates", groupDescription: "Bills and Other Expenses", iconName: "house.fill"))
        .withPreviewContainer()
}
