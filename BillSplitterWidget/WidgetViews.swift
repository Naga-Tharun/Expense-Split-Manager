//
//  WidgetViews.swift
//  BillSplitterWidget
//
//  Widget views for systemSmall and systemMedium families.
//

import SwiftUI
import WidgetKit

// MARK: - Main Entry View

struct BalancesWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: BalancesEntry

    var body: some View {
        content
            .widgetURL(URL(string: "billsplitter://balances"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            SmallBalanceView(entry: entry)
        case .systemMedium:
            MediumBalanceView(entry: entry)
        default:
            SmallBalanceView(entry: entry)
        }
    }
}

// MARK: - Small Widget — Net Balance

struct SmallBalanceView: View {
    let entry: BalancesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan)
                Text("Balances")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.topBalances.isEmpty && entry.netBalance == 0 {
                Text("All settled!")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                Text(formattedAmount(entry.netBalance))
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(entry.netBalance >= 0 ? .green : .red)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(entry.netBalance >= 0 ? "owed to you" : "you owe")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 0) {
                // Mini avatars of top friends
                ForEach(Array(entry.topBalances.prefix(3).enumerated()), id: \.element.id) { index, friend in
                    WidgetAvatar(name: friend.name, colorHex: friend.colorHex, size: 18)
                        .offset(x: CGFloat(-4 * index))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(smallAccessibilityLabel)
    }

    private var smallAccessibilityLabel: String {
        if entry.topBalances.isEmpty && entry.netBalance == 0 {
            return "Balances: All settled"
        }
        let direction = entry.netBalance >= 0 ? "owed to you" : "you owe"
        return "Balances: \(entry.currencySymbol)\(formatNumber(abs(entry.netBalance))) \(direction)"
    }

    private func formattedAmount(_ value: Double) -> String {
        "\(entry.currencySymbol)\(formatNumber(abs(value)))"
    }
}

// MARK: - Medium Widget — Top Balances

struct MediumBalanceView: View {
    let entry: BalancesEntry

    var body: some View {
        HStack(spacing: 12) {
            // Left: summary
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    Text("Balances")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if entry.totalOwedToYou > BalanceCalculator.epsilon {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.currencySymbol)\(formatNumber(entry.totalOwedToYou))")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("owed to you")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if entry.totalYouOwe > BalanceCalculator.epsilon {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.currencySymbol)\(formatNumber(entry.totalYouOwe))")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("you owe")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if entry.topBalances.isEmpty {
                    Text("All settled!")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: top friend balances
            if !entry.topBalances.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.topBalances.prefix(3)) { friend in
                        FriendBalanceRow(friend: friend, currencySymbol: entry.currencySymbol)
                    }

                    if entry.topBalances.count > 3 {
                        Text("+\(entry.topBalances.count - 3) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Friend Balance Row

struct FriendBalanceRow: View {
    let friend: BalancesEntry.FriendBalance
    let currencySymbol: String

    var body: some View {
        HStack(spacing: 8) {
            WidgetAvatar(name: friend.name, colorHex: friend.colorHex, size: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(friend.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(balanceText)
                    .font(.caption2)
                    .foregroundStyle(friend.amount > 0 ? .green : .red)
                    .lineLimit(1)
            }
        }
    }

    private var balanceText: String {
        let abs = formatNumber(abs(friend.amount))
        if friend.amount > 0 {
            return "owes \(currencySymbol)\(abs)"
        } else {
            return "you owe \(currencySymbol)\(abs)"
        }
    }
}

// MARK: - Widget Avatar

struct WidgetAvatar: View {
    let name: String
    let colorHex: String
    let size: CGFloat

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color(hex: colorHex)))
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }
}

// MARK: - Number Formatting

/// Formats a Double for compact widget display.
/// Under 1000 → "123.45", over 1000 → "1.2K", over 1M → "1.2M"
private func formatNumber(_ value: Double) -> String {
    if value >= 1_000_000 {
        return String(format: "%.1fM", value / 1_000_000)
    } else if value >= 10_000 {
        return String(format: "%.0fK", value / 1_000)
    } else if value >= 1_000 {
        return String(format: "%.1fK", value / 1_000)
    } else {
        return String(format: "%.2f", value)
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    BalancesWidget()
} timeline: {
    BalancesEntry.placeholder
    BalancesEntry.empty
}

#Preview("Medium", as: .systemMedium) {
    BalancesWidget()
} timeline: {
    BalancesEntry.placeholder
    BalancesEntry.empty
}
