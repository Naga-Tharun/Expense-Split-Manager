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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: friend.profileColor).opacity(0.2))
                    .frame(width: 50, height: 50)
                Text(String(friend.name.prefix(1)))
                    .font(.title2).fontWeight(.semibold)
                    .foregroundColor(Color(hex: friend.profileColor))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.name).font(.headline)

                if abs(balance) < 0.01 {
                    Text("settled up").font(.caption).foregroundColor(Color.green)
                } else {
                    Text(balance > 0 ? "owes you" : "you owe")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if abs(balance) > 0.01 {
                Text("₹\(abs(balance), specifier: "%.2f")")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(balance > 0 ? Color.green : Color.red)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.green.opacity(0.6))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        FriendRowView(friend: User(name: "Alex",   profileColor: "#007AFF"), balance:  450.0)
        FriendRowView(friend: User(name: "Jordan", profileColor: "#FF9500"), balance: -200.0)
        FriendRowView(friend: User(name: "Sam",    profileColor: "#34C759"), balance:    0.0)
    }
    .modelContainer(for: [User.self], inMemory: true)
    .preferredColorScheme(.dark)
}
