//
//  SaveHelper.swift
//  BillSplitter
//
//  Lightweight wrapper around ModelContext.save() that captures
//  errors into a published alert state instead of silently swallowing them.
//

import SwiftUI
import SwiftData
import UIKit
import Observation
import os

private let logger = Logger(subsystem: "com.billsplitter", category: "persistence")

// MARK: - Save Error Alert State

/// Drop this into any view that calls modelContext.save().
///
///     @State private var saveError = SaveErrorState()
///
///     // In your action:
///     saveError.perform { try modelContext.save() }
///
///     // In your body:
///     .saveErrorAlert($saveError)
///
@Observable
final class SaveErrorState {
    var showAlert = false
    var message   = ""

    /// Executes the given throwing closure. On failure, populates
    /// `message` and flips `showAlert` so the view can present it.
    /// Triggers haptic feedback on success or failure.
    func perform(_ work: () throws -> Void) {
        do {
            try work()
            Haptics.success()
        } catch {
            logger.error("Save failed: \(error.localizedDescription)")
            message   = error.localizedDescription
            showAlert = true
            Haptics.error()
        }
    }
}

// MARK: - Haptic Feedback Helper

/// Centralised haptic triggers used across the app.
enum Haptics {
    /// Light tap — used for selection changes, toggles.
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium tap — used for button presses, actions.
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Success notification — save, settle, create completed.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Error notification — save failure, validation error.
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Warning notification — destructive action confirmed.
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// MARK: - View Modifier

struct SaveErrorAlertModifier: ViewModifier {
    @Binding var state: SaveErrorState

    func body(content: Content) -> some View {
        content
            .alert("Couldn't Save", isPresented: $state.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(state.message)
            }
    }
}

extension View {
    func saveErrorAlert(_ state: Binding<SaveErrorState>) -> some View {
        modifier(SaveErrorAlertModifier(state: state))
    }
}
