//
//  PaymentHistoryView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct PaymentHistoryView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Settlement.date, order: .reverse) private var settlements: [Settlement]
    @State private var pendingDelete: IndexSet? = nil
    @State private var saveError = SaveErrorState()

    var body: some View {
        NavigationStack {
            historyContent
                .navigationTitle("Payment History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }.fontWeight(.semibold)
                    }
                }
                .alert("Delete Settlement?", isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                )) {
                    Button("Delete", role: .destructive) {
                        if let offsets = pendingDelete {
                            Haptics.warning()
                            offsets.map { settlements[$0] }.forEach { modelContext.delete($0) }
                            saveError.perform { try modelContext.save() }
                            pendingDelete = nil
                        }
                    }
                    Button("Cancel", role: .cancel) { pendingDelete = nil }
                } message: {
                    Text("This settlement record will be permanently removed.")
                }
                .saveErrorAlert($saveError)
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if settlements.isEmpty {
            ContentUnavailableView(
                "No Settlements Yet",
                systemImage: "clock.arrow.circlepath",
                description: Text("Recorded settlements will appear here")
            )
        } else {
            List {
                ForEach(settlements) { s in
                    settlementRow(s)
                }
                .onDelete { offsets in
                    pendingDelete = offsets
                }
            }
        }
    }

    @ViewBuilder
    private func settlementRow(_ s: Settlement) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: s.paymentMethod.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color.green)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(s.fromFriend?.name ?? "You").fontWeight(.semibold)
                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                    Text(s.toFriend?.name   ?? "You").fontWeight(.semibold)
                }
                .font(.subheadline)

                HStack(spacing: 6) {
                    Text(s.date.formatted(date: .abbreviated, time: .omitted))
                    Text("·")
                    Text(s.paymentMethod.label)
                }
                .font(.caption).foregroundStyle(.secondary)

                if let notes = s.notes, !notes.isEmpty {
                    Text(notes).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Spacer()

            Text("\(CurrencyHelper.symbol)\(s.amount, specifier: "%.2f")")
                .font(.headline).fontWeight(.bold)
                .foregroundColor(Color.green)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PaymentHistoryView()
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
