//
//  FriendRowView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct FriendRowView: View {
    let friend:  User
    let balance: Double  // positive = they owe you, negative = you owe them

    init(friend: User, balance: Double = 0) {
        self.friend  = friend
        self.balance = balance
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(user: friend, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.name)
                    .font(.body)
                    .fontWeight(.medium)

                if abs(balance) >= BalanceCalculator.epsilon {
                    Text(balance > 0 ? "owes you" : "you owe")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if abs(balance) < BalanceCalculator.epsilon {
                Label("Settled up", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundColor(.green)
            } else {
                Text("\(CurrencyHelper.symbol)\(abs(balance), specifier: "%.2f")")
                    .font(.subheadline).fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(balance > 0 ? .green : .red)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    List {
        FriendRowView(friend: User(name: "Alex",   profileColor: "#007AFF"), balance:  450.0)
        FriendRowView(friend: User(name: "Jordan", profileColor: "#FF9500"), balance: -200.0)
        FriendRowView(friend: User(name: "Sam",    profileColor: "#34C759"), balance:    0.0)
    }
    .withPreviewContainer()
}
