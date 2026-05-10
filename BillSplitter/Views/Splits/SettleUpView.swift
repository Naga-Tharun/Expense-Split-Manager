//
//  SettleUpView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct SettleUpView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \User.name) private var allUsers: [User]
    @AppStorage("currentUserID") private var currentUserIDString: String = ""

    @State private var selectedFromID: UUID? = nil
    @State private var selectedToID:   UUID? = nil
    @State private var amountText      = ""
    @State private var paymentMethod   = "cash"
    @State private var notes           = ""
    @State private var date            = Date()

    let prefilledFrom:   User?
    let prefilledTo:     User?
    let prefilledAmount: Double?

    init(from: User? = nil, to: User? = nil, amount: Double? = nil) {
        self.prefilledFrom   = from
        self.prefilledTo     = to
        self.prefilledAmount = amount
    }

    private var currentUser: User? {
        guard let uuid = UUID(uuidString: currentUserIDString) else { return nil }
        return allUsers.first { $0.id == uuid }
    }

    private var selectedFrom: User? { allUsers.first { $0.id == selectedFromID } }
    private var selectedTo:   User? { allUsers.first { $0.id == selectedToID } }

    private let methods = ["cash", "upi", "bank transfer", "card", "other"]

    private var isValid: Bool {
        selectedFromID != nil && selectedToID != nil
            && selectedFromID != selectedToID
            && (Double(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                directionSection
                detailsSection
                if isValid { summarySection }
            }
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") { recordSettlement() }
                        .fontWeight(.semibold).disabled(!isValid)
                }
            }
            .onAppear { applyPrefill() }
        }
    }

    // MARK: - Sections

    private var amountSection: some View {
        Section {
            VStack(spacing: 6) {
                Text("Settlement Amount").font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(CurrencyHelper.symbol).font(.system(size: 28, weight: .semibold)).foregroundStyle(.secondary)
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
        }
    }

    private var directionSection: some View {
        Section("Who is paying whom?") {
            Picker("From", selection: $selectedFromID) {
                Text("Select person").tag(UUID?.none)
                ForEach(allUsers) { user in
                    Text(displayName(user)).tag(Optional(user.id))
                }
            }

            if selectedFromID != nil || selectedToID != nil {
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.down.circle.fill").font(.title2).foregroundStyle(.cyan)
                        Text("pays").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Picker("To", selection: $selectedToID) {
                Text("Select person").tag(UUID?.none)
                ForEach(allUsers) { user in
                    Text(displayName(user)).tag(Optional(user.id))
                }
            }
        }
    }

    private var detailsSection: some View {
        Section("Payment Details") {
            DatePicker("Date", selection: $date, displayedComponents: .date)
            Picker("Method", selection: $paymentMethod) {
                ForEach(methods, id: \.self) { m in
                    Label(m.capitalized, systemImage: methodIcon(m)).tag(m)
                }
            }
            TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...4)
        }
    }

    private var summarySection: some View {
        Section {
            if let from = selectedFrom, let to = selectedTo {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text("\(displayName(from)) pays \(CurrencyHelper.symbol)\(Double(amountText) ?? 0, specifier: "%.2f") to \(displayName(to))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func displayName(_ user: User) -> String {
        user.id == currentUser?.id ? "\(user.name) (you)" : user.name
    }

    private func methodIcon(_ method: String) -> String {
        switch method {
        case "upi":           return "iphone.radiowaves.left.and.right"
        case "bank transfer": return "building.columns.fill"
        case "card":          return "creditcard.fill"
        default:              return "banknote.fill"
        }
    }

    private func applyPrefill() {
        if let f = prefilledFrom        { selectedFromID = f.id }
        else if let me = currentUser    { selectedFromID = me.id }
        if let t = prefilledTo          { selectedToID   = t.id }
        if let a = prefilledAmount      { amountText = String(format: "%.2f", a) }
    }

    private func recordSettlement() {
        let s = Settlement(
            fromFriend:    selectedFrom,
            toFriend:      selectedTo,
            amount:        Double(amountText) ?? 0,
            date:          date,
            paymentMethod: paymentMethod,
            notes:         notes.isEmpty ? nil : notes,
            isConfirmed:   true
        )
        modelContext.insert(s)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    SettleUpView()
        .withPreviewContainer()
}
