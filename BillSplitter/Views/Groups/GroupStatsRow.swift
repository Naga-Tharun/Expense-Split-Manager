//
//  GroupStatsRow.swift
//  BillSplitter
//
//  Compact horizontal stats bar showing member count, expense count, and total spend.
//

import SwiftUI

struct GroupStatsRow: View {
    let memberCount:  Int
    let expenseCount: Int
    let totalSpend:   Double

    var body: some View {
        Section {
            HStack(spacing: 8) {
                statCard(title: "Members",  value: "\(memberCount)",       icon: "person.2.fill",         color: .cyan)
                statCard(title: "Expenses", value: "\(expenseCount)",      icon: "list.bullet.rectangle", color: .orange)
                statCard(title: "Total",    value: "\(CurrencyHelper.symbol)\(Int(totalSpend))", icon: "banknote.fill", color: .green)
            }
        }
        .listRowInsets(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline).fontWeight(.bold).minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.1)))
    }
}

#Preview {
    List {
        GroupStatsRow(memberCount: 4, expenseCount: 12, totalSpend: 3450)
    }
    .preferredColorScheme(.dark)
}
