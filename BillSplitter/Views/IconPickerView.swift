//
//  IconPickerView.swift
//  BillSplitter
//
//  Created by Naga Tharun Makkena on 24/11/25.
//

import SwiftUI
import SwiftData
import UIKit

struct IconPickerView: View {
    let availableIcons: [String]
    @Binding var selectedIcon: String
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                            onDismiss()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(.secondarySystemBackground))
                                    .frame(width: 60, height: 60)
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(.primary)
                            }
                            .overlay(
                                Circle().stroke(selectedIcon == icon ? Color.accentColor : .clear, lineWidth: 3)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Icon")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedIcon = "person.3.fill"
    let availableIcons = [
        "person.3.fill", "house.fill", "car.fill", "airplane",
        "fork.knife", "cart.fill", "theatermasks.fill", "sportscourt.fill",
        "beach.umbrella.fill", "suitcase.fill", "briefcase.fill", "backpack.fill"
    ]
    
    IconPickerView(availableIcons: availableIcons, selectedIcon: $selectedIcon, onDismiss: {})
        .preferredColorScheme(.dark)
}
