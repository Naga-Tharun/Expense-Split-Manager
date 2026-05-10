//
//  ExpenseFilterBar.swift
//  BillSplitter
//
//  Compact search + category filter + sort controls for expense lists.
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

// MARK: - Expense List Header (search + filter chips + sort — always visible)

/// A compact, always-visible header that sits directly above the expense rows.
/// Row 1: Search field with sort menu on the right.
/// Row 2: Horizontally scrolling category chips.
struct ExpenseListHeader: View {
    @Binding var searchText: String
    @Binding var filterCategory: ExpenseCategory?
    @Binding var sortOrder: ExpenseSortOption

    var body: some View {
        // Search + sort row
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Search…", text: $searchText)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemBackground)))

            // Sort menu
            Menu {
                ForEach(ExpenseSortOption.allCases) { opt in
                    Button {
                        sortOrder = opt
                    } label: {
                        HStack {
                            Text(opt.rawValue)
                            if sortOrder == opt {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.subheadline)
                    .foregroundStyle(.cyan)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.cyan.opacity(0.12)))
            }
        }
        .listRowInsets(.init(top: 6, leading: 16, bottom: 2, trailing: 16))
        .listRowSeparator(.hidden)

        // Category chips row
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chipButton("All", icon: nil, isActive: filterCategory == nil) {
                    filterCategory = nil
                }
                ForEach(ExpenseCategory.allCases) { cat in
                    chipButton(cat.label, icon: cat.icon, isActive: filterCategory == cat) {
                        filterCategory = (filterCategory == cat) ? nil : cat
                    }
                }
            }
        }
        .listRowInsets(.init(top: 2, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func chipButton(_ label: String?, icon: String?, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.caption2)
                }
                if let label {
                    Text(label).font(.caption2).fontWeight(.medium)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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

/// Reusable expense list section with search/filter/sort header and empty state.
struct FilteredExpensesList: View {
    let filtered: [Expense]
    let total: Int
    let headerTitle: String
    let emptyTitle: String
    let emptyIcon: String
    let emptyMessage: String

    @Binding var searchText: String
    @Binding var filterCategory: ExpenseCategory?
    @Binding var sortOrder: ExpenseSortOption

    var onDelete: ((IndexSet) -> Void)? = nil

    var body: some View {
        Section {
            // Search + filter + sort controls (always visible when expenses exist)
            if total > 0 {
                ExpenseListHeader(
                    searchText: $searchText,
                    filterCategory: $filterCategory,
                    sortOrder: $sortOrder
                )
            }

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
