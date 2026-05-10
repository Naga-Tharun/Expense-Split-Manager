//
//  OnboardingView.swift
//  BillSplitter
//
//  A brief 3-step onboarding walkthrough shown on first launch.
//  Gated by @AppStorage("hasCompletedOnboarding").
//

import SwiftUI
import UIKit

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "rectangle.stack.fill",
            color: .cyan,
            title: "Welcome to BillSplitter",
            subtitle: "Split expenses with friends and groups — no more awkward math."
        ),
        OnboardingPage(
            icon: "person.2.fill",
            color: .green,
            title: "Add Friends & Groups",
            subtitle: "Create a group for your trip, flat, or dinner crew, then add friends to split with."
        ),
        OnboardingPage(
            icon: "bolt.fill",
            color: .orange,
            title: "Track & Settle Up",
            subtitle: "Log expenses, see who owes what, and settle balances in a tap."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Page indicator dots
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.cyan : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentPage ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            .padding(.bottom, 32)

            // Action button
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.cyan)
                    )
            }
            .padding(.horizontal, 32)

            // Skip button (hidden on last page)
            if currentPage < pages.count - 1 {
                Button("Skip") {
                    hasCompletedOnboarding = true
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 12)
            }

            Spacer().frame(height: 32)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: page.icon)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(page.color)
            }

            Text(page.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Page Model

private struct OnboardingPage {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .preferredColorScheme(.dark)
}
