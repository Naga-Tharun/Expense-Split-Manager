//
//  SpendingInsightsCard.swift
//  BillSplitter
//
//  Monthly spending summary and category breakdown card.
//

import SwiftUI

struct SpendingInsightsCard: View {
    let expenses: [Expense]

    private var thisMonthExpenses: [Expense] {
        let cal = Calendar.current
        let now = Date()
        return expenses.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
    }

    private var lastMonthExpenses: [Expense] {
        let cal = Calendar.current
        guard let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) else { return [] }
        return expenses.filter { cal.isDate($0.date, equalTo: lastMonth, toGranularity: .month) }
    }

    private var thisMonthTotal: Double {
        thisMonthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var lastMonthTotal: Double {
        lastMonthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var monthChange: Double? {
        guard lastMonthTotal > 0 else { return nil }
        return ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100
    }

    /// Top 3 categories by total spend this month
    private var topCategories: [(category: ExpenseCategory, total: Double)] {
        var map: [ExpenseCategory: Double] = [:]
        for e in thisMonthExpenses {
            map[e.category, default: 0] += e.amount
        }
        return map.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }

    private var monthLabel: String {
        Date().formatted(.dateTime.month(.wide))
    }

    var body: some View {
        Section {
            VStack(spacing: 14) {
                // Month total
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monthLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text("\(CurrencyHelper.symbol)\(thisMonthTotal, specifier: "%.0f")")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    }

                    Spacer()

                    if let change = monthChange {
                        HStack(spacing: 3) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2)
                            Text("\(abs(change), specifier: "%.0f")%")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill((change >= 0 ? Color.red : Color.green).opacity(0.15)))
                        .foregroundColor(change >= 0 ? .red : .green)
                    }
                }

                // Category breakdown
                if !topCategories.isEmpty {
                    Divider()

                    VStack(spacing: 8) {
                        ForEach(topCategories, id: \.category) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.category.icon)
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                                    .frame(width: 18)

                                Text(item.category.label)
                                    .font(.caption)
                                    .foregroundStyle(.primary)

                                Spacer()

                                // Proportion bar
                                GeometryReader { geo in
                                    let fraction = thisMonthTotal > 0 ? item.total / thisMonthTotal : 0
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.cyan.opacity(0.25))
                                        .frame(width: geo.size.width * fraction, height: 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(width: 60, height: 6)

                                Text("\(CurrencyHelper.symbol)\(item.total, specifier: "%.0f")")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }
                }

                // Expense count
                HStack {
                    Text("\(thisMonthExpenses.count) expenses this month")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("Spending")
        }
    }
}

#Preview {
    List {
        SpendingInsightsCard(expenses: [])
    }
    .preferredColorScheme(.dark)
}
