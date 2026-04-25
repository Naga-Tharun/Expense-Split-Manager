//
//  MainTabView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 2

    var body: some View {
        TabView(selection: $selectedTab) {
            GroupsView()
                .tabItem { Label("Groups",    systemImage: "person.3.fill") }.tag(0)
            FriendsView()
                .tabItem { Label("Friends",   systemImage: "person.2.fill") }.tag(1)
            AddSplitView()
                .tabItem { Label("Add Split", systemImage: "plus.circle.fill") }.tag(2)
            BalancesView()
                .tabItem { Label("Balances",  systemImage: "chart.bar.fill") }.tag(3)
            ProfileView()
                .tabItem { Label("Profile",   systemImage: "person.circle.fill") }.tag(4)
        }
        .tint(.cyan)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [User.self, Group.self, Expense.self, Settlement.self, ExpenseParticipant.self], inMemory: true)
        .preferredColorScheme(.dark)
}
