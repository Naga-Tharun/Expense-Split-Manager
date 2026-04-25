//
//  ExpenseDetailView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct ExpenseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @Query(sort: \User.name) private var allUsers: [User]
    @AppStorage("currentUserID") private var currentUserIDString: String = ""

    let expense: Expense

    @State private var showDeleteAlert = false
    @State private var showEditSheet   = false

    private var currentUserID: UUID? { UUID(uuidString: currentUserIDString) }

    private var categoryIcon: String {
        switch expense.category {
        case "food":          return "fork.knife"
        case "transport":     return "car.fill"
        case "accommodation": return "house.fill"
        case "entertainment": return "theatermasks.fill"
        case "shopping":      return "cart.fill"
        case "utilities":     return "bolt.fill"
        case "travel":        return "airplane"
        default:              return "square.grid.2x2.fill"
        }
    }

    private var paidByLabel: String {
        if let payer = expense.paidBy {
            return payer.id == currentUserID ? "\(payer.name) (you)" : payer.name
        }
        return "You"
    }

    var body: some View {
        List {
            headerSection
            detailsSection
            if let participants = expense.participants, !participants.isEmpty {
                splitSection(participants)
            }
            deleteSection
        }
        .navigationTitle("Expense Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) { EditExpenseView(expense: expense) }
        .alert("Delete Expense?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { modelContext.delete(expense); dismiss() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This cannot be undone.") }
    }

    private var headerSection: some View {
        Section {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color.cyan.opacity(0.15)).frame(width: 64, height: 64)
                    Image(systemName: categoryIcon).font(.system(size: 28)).foregroundStyle(.cyan)
                }
                Text(expense.expenseDescription)
                    .font(.title2).fontWeight(.bold).multilineTextAlignment(.center)
                Text("₹\(expense.amount, specifier: "%.2f")")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text(expense.category.capitalized)
                    .font(.caption).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.15))).foregroundStyle(.cyan)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8).listRowBackground(Color.clear)
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            detailRow("Date",       value: expense.date.formatted(date: .long, time: .omitted), icon: "calendar")
            detailRow("Paid by",    value: paidByLabel, icon: "person.fill")
            detailRow("Split type", value: expense.splitType.capitalized, icon: "arrow.triangle.branch")
            if let group = expense.group {
                HStack {
                    Label("Group", systemImage: group.iconName).foregroundStyle(.secondary)
                    Spacer()
                    Text(group.name).fontWeight(.medium)
                }
            }
            if let notes = expense.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Notes", systemImage: "note.text").font(.subheadline).foregroundStyle(.secondary)
                    Text(notes)
                }.padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func splitSection(_ participants: [ExpenseParticipant]) -> some View {
        Section("Split Breakdown") {
            ForEach(participants) { p in
                if let friend = p.friend {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: friend.profileColor).opacity(0.2)).frame(width: 34, height: 34)
                            Text(String(friend.name.prefix(1))).font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(Color(hex: friend.profileColor))
                        }
                        Text(friend.id == currentUserID ? "\(friend.name) (you)" : friend.name)
                        Spacer()
                        Text("₹\(p.amountOwed, specifier: "%.2f")").fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) { showDeleteAlert = true } label: {
                Label("Delete Expense", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}

#Preview {
    let container = previewContainer()
    let context   = container.mainContext

    // Grab the "me" user that resolve() created
    let allUsers  = (try? context.fetch(FetchDescriptor<User>())) ?? []
    let me        = allUsers.first

    // Sample friend
    let friend    = User(name: "Alex", profileColor: "#007AFF")
    context.insert(friend)

    // Sample expense with a participant split
    let expense   = Expense(expenseDescription: "Dinner at Spice Garden", amount: 900, category: "food")
    let p1        = ExpenseParticipant(friend: me,     amountOwed: 450)
    let p2        = ExpenseParticipant(friend: friend, amountOwed: 450)
    context.insert(p1); context.insert(p2)
    expense.participants = [p1, p2]
    context.insert(expense)
    try? context.save()

    return NavigationStack {
        ExpenseDetailView(expense: expense)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
