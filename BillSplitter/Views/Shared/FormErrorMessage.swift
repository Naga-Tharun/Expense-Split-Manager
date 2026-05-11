//
//  FormErrorMessage.swift
//  BillSplitter
//
//  Lightweight inline validation label reused across all forms.
//

import SwiftUI

/// Displays a small red error label below a form field.
/// Pass `isVisible: false` to hide the message while
/// preserving layout space (no jarring shifts).
struct FormErrorMessage: View {
    let message: String
    let isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(message)
            }
            .font(.caption)
            .foregroundStyle(.red)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityLabel("Error: \(message)")
        }
    }
}
