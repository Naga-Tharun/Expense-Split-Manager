import SwiftUI
import SwiftData

struct FriendDetailView: View {
    let friend: User
    
    var body: some View {
        List {
            Section("Contact Information") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(friend.name)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Balance") {
                HStack {
                    Text("Total Balance")
                    Spacer()
                    Text("₹0.00")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Shared Expenses") {
                if let expenses = friend.expenses, !expenses.isEmpty {
                    ForEach(expenses) { expense in
                        ExpenseRow(expense: expense)
                    }
                } else {
                    Text("No shared expenses yet")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(friend.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    FriendDetailView(friend: User(name: "Alex", profileColor: "#007AFF"))
        .modelContainer(for: [User.self], inMemory: true)
}
