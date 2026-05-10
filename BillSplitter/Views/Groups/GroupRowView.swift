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

                Text("\(memberCount) members · \(expenseCount) expenses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if expenseCount > 0 {
                let total = (group.expenses ?? []).reduce(0) { $0 + $1.amount }
                Text("\(CurrencyHelper.symbol)\(String(format: "%.0f", total))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
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
