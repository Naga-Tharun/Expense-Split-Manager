//
//  PreviewSampleData.swift
//  BillSplitter
//
//  Populates an in-memory container with realistic sample data
//  for Xcode previews. Covers multiple friends, groups, expense
//  categories, split types, and settlements.
//

import SwiftData
import Foundation

@MainActor
enum PreviewSampleData {

    /// Call once per preview. Returns a fully populated ModelContainer.
    static func container() -> ModelContainer {
        let container = previewContainer()   // sets up "me" user
        populate(container)
        return container
    }

    // MARK: - Populate

    static func populate(_ container: ModelContainer) {
        let ctx = container.mainContext

        // ── Current user ("me") ──
        let allUsers = (try? ctx.fetch(FetchDescriptor<User>())) ?? []
        guard let me = allUsers.first else { return }
        me.name = "Tharun"
        me.profileColor = "#00BCD4"

        // ── Friends ──
        let alex   = User(name: "Alex",   profileColor: "#007AFF")
        let priya  = User(name: "Priya",  profileColor: "#FF2D55")
        let jordan = User(name: "Jordan", profileColor: "#FF9500")
        let sam    = User(name: "Sam",    profileColor: "#34C759")
        let riya   = User(name: "Riya",   profileColor: "#5856D6")

        [alex, priya, jordan, sam, riya].forEach { ctx.insert($0) }

        // ── Groups ──
        let flatmates = Group(name: "Flatmates", groupDescription: "Rent & shared bills",
                              iconName: "house.fill", colorHex: "#FF9500")
        flatmates.members = [me, alex, priya]

        let tripGoa = Group(name: "Goa Trip 2025", groupDescription: "Beach vacation expenses",
                            iconName: "beach.umbrella.fill", colorHex: "#007AFF")
        tripGoa.members = [me, jordan, sam, riya]

        let officeLunch = Group(name: "Office Lunch", groupDescription: "Daily lunch pool",
                                iconName: "fork.knife", colorHex: "#34C759")
        officeLunch.members = [me, alex, jordan]

        [flatmates, tripGoa, officeLunch].forEach { ctx.insert($0) }

        // ── Expenses ──

        // 1. Equal split — Flatmates electricity
        let elec = Expense(expenseDescription: "Electricity Bill", amount: 3600,
                           category: .utilities, date: daysAgo(2))
        elec.paidBy = me; elec.group = flatmates
        let elecP = equalParticipants([me, alex, priya], amount: 3600, ctx: ctx)
        elec.participants = elecP
        ctx.insert(elec)
        appendToGroup(flatmates, elec)

        // 2. Equal split — Dinner
        let dinner = Expense(expenseDescription: "Dinner at Spice Garden", amount: 2400,
                             category: .food, date: daysAgo(5))
        dinner.paidBy = alex; dinner.group = flatmates
        let dinnerP = equalParticipants([me, alex, priya], amount: 2400, ctx: ctx)
        dinner.participants = dinnerP
        ctx.insert(dinner)
        appendToGroup(flatmates, dinner)

        // 3. Custom split — Groceries
        let grocery = Expense(expenseDescription: "Weekly Groceries", amount: 1800,
                              category: .shopping, date: daysAgo(3), splitType: .custom)
        grocery.paidBy = me; grocery.group = flatmates
        let gP1 = ExpenseParticipant(friend: me,    amountOwed: 800)
        let gP2 = ExpenseParticipant(friend: alex,  amountOwed: 500)
        let gP3 = ExpenseParticipant(friend: priya, amountOwed: 500)
        [gP1, gP2, gP3].forEach { ctx.insert($0) }
        grocery.participants = [gP1, gP2, gP3]
        ctx.insert(grocery)
        appendToGroup(flatmates, grocery)

        // 4. Percentage split — Goa hotel
        let hotel = Expense(expenseDescription: "Beach Resort (3 nights)", amount: 18000,
                            category: .accommodation, date: daysAgo(10), splitType: .percentage)
        hotel.paidBy = jordan; hotel.group = tripGoa
        let hP1 = ExpenseParticipant(friend: me,     amountOwed: 5400)  // 30%
        let hP2 = ExpenseParticipant(friend: jordan,  amountOwed: 5400) // 30%
        let hP3 = ExpenseParticipant(friend: sam,     amountOwed: 3600) // 20%
        let hP4 = ExpenseParticipant(friend: riya,    amountOwed: 3600) // 20%
        [hP1, hP2, hP3, hP4].forEach { ctx.insert($0) }
        hotel.participants = [hP1, hP2, hP3, hP4]
        ctx.insert(hotel)
        appendToGroup(tripGoa, hotel)

        // 5. Equal split — Cab to airport
        let cab = Expense(expenseDescription: "Cab to Airport", amount: 2800,
                          category: .transport, date: daysAgo(9))
        cab.paidBy = me; cab.group = tripGoa
        let cabP = equalParticipants([me, jordan, sam, riya], amount: 2800, ctx: ctx)
        cab.participants = cabP
        ctx.insert(cab)
        appendToGroup(tripGoa, cab)

        // 6. Equal split — Office lunch
        let lunch = Expense(expenseDescription: "Biryani Friday", amount: 900,
                            category: .food, date: daysAgo(1))
        lunch.paidBy = jordan; lunch.group = officeLunch
        let lunchP = equalParticipants([me, alex, jordan], amount: 900, ctx: ctx)
        lunch.participants = lunchP
        ctx.insert(lunch)
        appendToGroup(officeLunch, lunch)

        // 7. No-group expense — Movie tickets
        let movie = Expense(expenseDescription: "Movie: Pushpa 3", amount: 600,
                            category: .entertainment, date: daysAgo(4))
        movie.paidBy = me
        let mP1 = ExpenseParticipant(friend: me,   amountOwed: 200)
        let mP2 = ExpenseParticipant(friend: sam,  amountOwed: 200)
        let mP3 = ExpenseParticipant(friend: riya, amountOwed: 200)
        [mP1, mP2, mP3].forEach { ctx.insert($0) }
        movie.participants = [mP1, mP2, mP3]
        ctx.insert(movie)

        // 8. Travel expense
        let flight = Expense(expenseDescription: "Flight Tickets Goa", amount: 12000,
                             category: .travel, date: daysAgo(14))
        flight.paidBy = me; flight.group = tripGoa
        let fP = equalParticipants([me, jordan, sam, riya], amount: 12000, ctx: ctx)
        flight.participants = fP
        ctx.insert(flight)
        appendToGroup(tripGoa, flight)

        // ── Settlements ──
        let s1 = Settlement(fromFriend: alex, toFriend: me, amount: 800,
                            date: daysAgo(1), paymentMethod: .upi,
                            notes: "Electricity share", isConfirmed: true)
        let s2 = Settlement(fromFriend: priya, toFriend: me, amount: 500,
                            date: daysAgo(1), paymentMethod: .cash,
                            notes: "Groceries", isConfirmed: true)
        let s3 = Settlement(fromFriend: me, toFriend: jordan, amount: 3000,
                            date: daysAgo(7), paymentMethod: .bankTransfer,
                            notes: "Hotel partial", isConfirmed: true)
        [s1, s2, s3].forEach { ctx.insert($0) }

        try? ctx.save()
    }

    // MARK: - Helpers

    private static func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
    }

    private static func equalParticipants(_ users: [User], amount: Double,
                                          ctx: ModelContext) -> [ExpenseParticipant] {
        let share = amount / Double(users.count)
        return users.map { user in
            let p = ExpenseParticipant(friend: user, amountOwed: share)
            ctx.insert(p)
            return p
        }
    }

    private static func appendToGroup(_ group: Group, _ expense: Expense) {
        var list = group.expenses ?? []
        list.append(expense)
        group.expenses = list
    }
}
