//
//  SuccessOverlay.swift
//  BillSplitter
//
//  A brief checkmark animation overlay shown after successful save actions.
//  Automatically dismisses after a short delay.
//

import SwiftUI
import Foundation

struct SuccessOverlay: View {
    @Binding var isPresented: Bool
    var message: String = "Saved"
    var onDismiss: () -> Void = {}

    @State private var checkScale: CGFloat = 0.3
    @State private var checkOpacity: Double = 0

    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                            .scaleEffect(checkScale)
                            .opacity(checkOpacity)
                    }

                    Text(message)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .opacity(checkOpacity)
                }
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    checkScale = 1.0
                    checkOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        checkOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isPresented = false
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Overlays a brief success checkmark animation.
    func successOverlay(
        isPresented: Binding<Bool>,
        message: String = "Saved",
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        overlay {
            SuccessOverlay(
                isPresented: isPresented,
                message: message,
                onDismiss: onDismiss
            )
        }
    }
}
