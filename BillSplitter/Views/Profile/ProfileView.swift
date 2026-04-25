//
//  ProfileView.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 23/11/25.
//

import SwiftUI

struct ProfileView: View {
    @State private var userName = "You"
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile Header
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                Text(String(userName.prefix(1)))
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundStyle(.cyan)
                            }
                            
                            VStack(spacing: 4) {
                                Text(userName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Local Account")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Button {
                                showingEditProfile = true
                            } label: {
                                Text("Edit Profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Settings
                Section("Preferences") {
                    NavigationLink {
                        Text("Edit Profile Screen")
                    } label: {
                        Label("Edit Profile", systemImage: "person.fill")
                    }
                    
                    NavigationLink {
                        Text("Notifications Settings")
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    
                    Picker(selection: .constant("INR")) {
                        Text("INR (₹)").tag("INR")
                        Text("USD ($)").tag("USD")
                        Text("EUR (€)").tag("EUR")
                    } label: {
                        Label("Currency", systemImage: "dollarsign.circle.fill")
                    }
                }
                
                Section("Data") {
                    Button {
                        // Export data
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up.fill")
                    }
                    
                    Button {
                        // Backup data
                    } label: {
                        Label("Backup Data", systemImage: "icloud.and.arrow.up.fill")
                    }
                }
                
                Section("About") {
                    NavigationLink {
                        Text("About Screen")
                    } label: {
                        Label("About BillSplitter", systemImage: "info.circle.fill")
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        // Clear all data
                    } label: {
                        Label("Clear All Data", systemImage: "trash.fill")
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
}
