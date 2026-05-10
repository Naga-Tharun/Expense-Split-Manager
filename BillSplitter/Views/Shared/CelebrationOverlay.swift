//
//  CelebrationOverlay.swift
//  BillSplitter
//
//  Confetti-style celebration shown when all balances are settled.
//

import SwiftUI
import Foundation

struct CelebrationOverlay: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var showBanner = false
    @State private var viewSize: CGSize = .zero

    private let colors: [Color] = [.cyan, .green, .orange, .pink, .purple, .yellow]

    var body: some View {
        ZStack {
            // Confetti particles
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: 2)
                    .fill(particle.color)
                    .frame(width: particle.size.width, height: particle.size.height)
                    .rotationEffect(.degrees(particle.rotation))
                    .position(particle.position)
                    .opacity(particle.opacity)
            }

            // Banner
            if showBanner {
                VStack(spacing: 8) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)
                    Text("All Settled Up!")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { viewSize = geo.size }
            }
        )
        .onAppear { launchConfetti() }
        .onChange(of: viewSize) { _, _ in
            if particles.isEmpty { launchConfetti() }
        }
    }

    private func launchConfetti() {
        guard viewSize.width > 0 else { return }
        let screenWidth = viewSize.width
        let screenHeight = viewSize.height

        // Create particles
        for i in 0..<40 {
            let particle = ConfettiParticle(
                id: i,
                color: colors.randomElement() ?? .cyan,
                size: CGSize(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 4...8)),
                position: CGPoint(x: CGFloat.random(in: 0...screenWidth), y: -20),
                rotation: Double.random(in: 0...360),
                opacity: 1.0
            )
            particles.append(particle)
        }

        // Animate particles falling
        withAnimation(.easeIn(duration: 2.0)) {
            for i in particles.indices {
                particles[i].position.y = screenHeight + 50
                particles[i].position.x += CGFloat.random(in: -80...80)
                particles[i].rotation += Double.random(in: 180...720)
            }
        }

        // Show banner
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
            showBanner = true
        }

        // Fade out banner
        withAnimation(.easeOut(duration: 0.4).delay(2.5)) {
            showBanner = false
        }

        // Clean up particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.5)) {
                for i in particles.indices {
                    particles[i].opacity = 0
                }
            }
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id: Int
    var color: Color
    var size: CGSize
    var position: CGPoint
    var rotation: Double
    var opacity: Double
}

// MARK: - View Modifier

extension View {
    func celebrationOverlay(isPresented: Bool) -> some View {
        overlay {
            if isPresented {
                CelebrationOverlay()
            }
        }
    }
}
