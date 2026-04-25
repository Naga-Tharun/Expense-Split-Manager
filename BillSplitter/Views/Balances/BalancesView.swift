//
//  BalancesView.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftUI
import SwiftData

struct BalancesView: View {
    @Query private var friends: [User]
    @Query private var expenses: [Expense]
    
    var body: some View {
        NavigationStack {
            List {
                // Summary Section
                Section {
                    GroupBox {
                        VStack(spacing: 16) {
                            Text("Total Balance")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text("₹0.00")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            
                            HStack(spacing: 32) {
                                VStack(spacing: 4) {
                                    Text("You owe")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("₹0.00")
                                        .font(.headline)
                                        .foregroundStyle(.red)
                                }
                                
                                Divider()
                                    .frame(height: 30)
                                
                                VStack(spacing: 4) {
                                    Text("Owed to you")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("₹0.00")
                                        .font(.headline)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
                
                // Individual Balances
                Section("Individual Balances") {
                    if friends.isEmpty {
                        Text("No friends added yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(friends) { friend in
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: friend.profileColor).opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Text(String(friend.name.prefix(1)))
                                        .font(.headline)
                                        .foregroundStyle(Color(hex: friend.profileColor))
                                }
                                
                                Text(friend.name)
                                    .font(.body)
                                
                                Spacer()
                                
                                Text("₹0.00")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Settlement Options
                Section {
                    Button {
                        // Settle all action
                    } label: {
                        Label("Settle All Balances", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(friends.isEmpty)
                    
                    Button {
                        // Payment history
                    } label: {
                        Label("Payment History", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .navigationTitle("Balances")
        }
    }
}

#Preview {
    BalancesView()
        .modelContainer(for: [User.self, Expense.self], inMemory: true)
        .preferredColorScheme(.dark)
}
