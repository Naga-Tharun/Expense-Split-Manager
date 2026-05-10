//
//  GroupRowView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct GroupRowView: View {
    let group: Group

    private var memberCount: Int { group.members?.count ?? 0 }
    private var expenseCount: Int { group.expenses?.count ?? 0 }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: group.colorHex).opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: group.iconName)
                    .font(.headline)
                    .foregroundStyle(Color(hex: group.colorHex))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    Label("\(memberCount)", systemImage: "person.2")
                    if expenseCount > 0 {
                        Text("·")
                        Label("\(expenseCount)", systemImage: "receipt")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if expenseCount > 0 {
                let total = (group.expenses ?? []).reduce(0) { $0 + $1.amount }
                Text("\(CurrencyHelper.symbol)\(total, specifier: "%.0f")")
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    GroupRowView(group: Group(name: "Flatmates", groupDescription: "Bills and Other Expenses", iconName: "house.fill"))
        .withPreviewContainer()
}
