//
//  MainTabView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData
import CoreSpotlight

struct MainTabView: View {
    @State private var selectedTab = 2
    @State private var deepLinkFriendID: UUID?
    @State private var deepLinkExpenseID: UUID?
    @State private var deepLinkGroupID: UUID?

    /// Tab indices — avoids magic numbers scattered across the file.
    private enum Tab: Int {
        case groups = 0, friends, activity, balances, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GroupsView(deepLinkGroupID: $deepLinkGroupID)
                .tabItem { Label("Groups",    systemImage: "person.3.fill") }.tag(Tab.groups.rawValue)
            FriendsView(deepLinkFriendID: $deepLinkFriendID)
                .tabItem { Label("Friends",   systemImage: "person.2.fill") }.tag(Tab.friends.rawValue)
            AddSplitView(deepLinkExpenseID: $deepLinkExpenseID)
                .tabItem { Label("Activity", systemImage: "bolt.fill") }.tag(Tab.activity.rawValue)
            BalancesView()
                .tabItem { Label("Balances",  systemImage: "chart.bar.fill") }.tag(Tab.balances.rawValue)
            ProfileView()
                .tabItem { Label("Profile",   systemImage: "person.circle.fill") }.tag(Tab.profile.rawValue)
        }
        .tint(.cyan)
        .onOpenURL { url in
            // Deep link from widget: billsplitter://balances
            if url.host == "balances" {
                selectedTab = Tab.balances.rawValue
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            handleSpotlightActivity(activity)
        }
    }

    // MARK: - Spotlight Deep Link

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }

        if identifier.hasPrefix("com.billsplitter.expense.") {
            let uuidString = String(identifier.dropFirst("com.billsplitter.expense.".count))
            if let expenseID = UUID(uuidString: uuidString) {
                deepLinkExpenseID = expenseID
            }
            selectedTab = Tab.activity.rawValue
        } else if identifier.hasPrefix("com.billsplitter.group.") {
            let uuidString = String(identifier.dropFirst("com.billsplitter.group.".count))
            if let groupID = UUID(uuidString: uuidString) {
                deepLinkGroupID = groupID
            }
            selectedTab = Tab.groups.rawValue
        } else if identifier.hasPrefix("com.billsplitter.friend.") {
            // Extract friend UUID from identifier: "com.billsplitter.friend.<UUID>"
            let uuidString = String(identifier.dropFirst("com.billsplitter.friend.".count))
            if let friendID = UUID(uuidString: uuidString) {
                deepLinkFriendID = friendID
            }
            selectedTab = Tab.friends.rawValue
        }
    }
}

#Preview {
    MainTabView()
        .environment(BalanceCache())
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
