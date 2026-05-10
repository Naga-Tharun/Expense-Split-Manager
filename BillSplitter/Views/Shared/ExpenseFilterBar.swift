//
//  ExpenseFilterBar.swift
//  BillSplitter
//
//  Reusable collapsible filter bar for expense lists.
//  Used in AddSplitView, GroupDetailView, and FriendDetailView.
//

import SwiftUI

// MARK: - Sort Option

enum ExpenseSortOption: String, CaseIterable, Identifiable {
    case dateDesc   = "Newest"
    case dateAsc    = "Oldest"
    case amountHigh = "Highest"
    case amountLow  = "Lowest"
    var id: String { rawValue }
}

// MARK: - Filter Bar

struct ExpenseFilterBar: View {
    @Binding var filterCategory: ExpenseCategory?
    @Binding var sortOrder: ExpenseSortOption
    @Binding var isExpanded: Bool

    var body: some View {
        Section {
            // Toggle button row
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.subheadline)
                        .foregroundStyle(.cyan)

                    Text("Filter & Sort")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    if filterCategory != nil {
                        Text(filterCategory!.label)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.cyan.opacity(0.2)))
                            .foregroundStyle(.cyan)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chipButton("All", icon: nil, isActive: filterCategory == nil) {
                            filterCategory = nil
                        }
                        ForEach(ExpenseCategory.allCases) { cat in
                            chipButton(nil, icon: cat.icon, isActive: filterCategory == cat) {
                                filterCategory = (filterCategory == cat) ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .listRowInsets(.init(top: 2, leading: 10, bottom: 2, trailing: 10))

                // Sort picker
                HStack {
                    Text("Sort by")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(ExpenseSortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
    }

    @ViewBuilder
    private func chipButton(_ label: String?, icon: String?, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon).font(.caption)
                }
                if let label {
                    Text(label).font(.caption).fontWeight(.medium)
                }
            }
            .frame(width: 36, height: 30)
            .frame(minWidth: label != nil ? 44 : 36)
            .background(Capsule().fill(isActive ? Color.cyan.opacity(0.2) : Color(.tertiarySystemBackground)))
            .foregroundColor(isActive ? .cyan : .secondary)
            .overlay(Capsule().stroke(isActive ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filtering + Sorting Helper

extension Array where Element == Expense {
    func filtered(
        searchText: String = "",
        category: ExpenseCategory? = nil,
        sortOrder: ExpenseSortOption = .dateDesc
    ) -> [Expense] {
        var result = self

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.expenseDescription.lowercased().contains(query)
                || $0.paidBy?.name.lowercased().contains(query) == true
                || $0.group?.name.lowercased().contains(query) == true
            }
        }

        if let cat = category {
            result = result.filter { $0.category == cat }
        }

        switch sortOrder {
        case .dateDesc:   result.sort { $0.date > $1.date }
        case .dateAsc:    result.sort { $0.date < $1.date }
        case .amountHigh: result.sort { $0.amount > $1.amount }
        case .amountLow:  result.sort { $0.amount < $1.amount }
        }

        return result
    }
}

// MARK: - Filtered Expenses Section

/// Reusable expense list section with empty state handling.
struct FilteredExpensesList: View {
    let filtered: [Expense]
    let total: Int
    let headerTitle: String
    let emptyTitle: String
    let emptyIcon: String
    let emptyMessage: String
    var onDelete: ((IndexSet) -> Void)? = nil

    var body: some View {
        Section {
            if filtered.isEmpty {
                if total == 0 {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: emptyIcon,
                        description: Text(emptyMessage)
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search or filter")
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(filtered.prefix(100)) { expense in
                    NavigationLink {
                        ExpenseDetailView(expense: expense)
                    } label: {
                        ExpenseRow(expense: expense)
                    }
                }
                .onDelete { offsets in
                    onDelete?(offsets)
                }
            }
        } header: {
            HStack {
                Text(headerTitle)
                Spacer()
                if total > 0 {
                    Text("\(filtered.count) of \(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
