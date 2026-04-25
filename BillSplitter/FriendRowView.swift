import SwiftUI

struct FriendRowView: View {
    let friend: User
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Circle
            ZStack {
                Circle()
                    .fill(Color(hex: friend.profileColor).opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(String(friend.name.prefix(1)))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: friend.profileColor))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.headline)
            }
            
            Spacer()
            
            // Balance badge
            Text("₹0.00")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FriendRowView(friend: User(name: "Alex", profileColor: "#007AFF"))
        .modelContainer(for: [User.self], inMemory: true)
}
