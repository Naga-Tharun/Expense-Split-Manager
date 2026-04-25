//
//  PreviewHelper.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

// MARK: - Shared preview container

/// Call this once per #Preview block.
/// Returns an in-memory ModelContainer that already has a "me" User
/// and UserDefaults["currentUserID"] set — identical to what
/// BillSplitterApp.init() does in the real app.
@MainActor
func previewContainer() -> ModelContainer {
    let schema = Schema([
        User.self, Group.self, Expense.self,
        ExpenseParticipant.self, Settlement.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    // Resolve "me" — same logic as the real app
    CurrentUserManager.resolve(in: container)

    return container
}

// MARK: - Convenience modifier

/// Wraps a view with the shared preview container.
struct PreviewContainerModifier: ViewModifier {
    let container: ModelContainer
    func body(content: Content) -> some View {
        content
            .modelContainer(container)
            .preferredColorScheme(.dark)
    }
}

extension View {
    /// Apply in #Preview to get a fully-resolved current user.
    func withPreviewContainer() -> some View {
        modifier(PreviewContainerModifier(container: previewContainer()))
    }
}
