import SwiftUI

/// Indeterminate status: three dots with short stagger (≤50ms) and subtle scale.
struct BreathingDotsView: View {
    @ViewState private var phase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let dotSize: CGFloat = 5
    /// Under 50ms per item (physics-no-excessive-stagger).
    private let delays: [Double] = [0, 0.04, 0.08]

    var body: some View {
        HStack(spacing: LivelyBrand.Spacing.xs) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(LivelyBrand.primary)
                    .frame(width: dotSize, height: dotSize)
                    // Subtle deformation band (~0.92–1.0), not a dramatic pulse.
                    .scaleEffect(reduceMotion ? 1.0 : (phase ? 1.0 : 0.92))
                    .opacity(reduceMotion ? 0.55 : (phase ? 0.9 : 0.35))
                    .animation(
                        reduceMotion ? nil :
                            .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(delays[index]),
                        value: phase
                    )
            }
        }
        .onAppear {
            if reduceMotion {
                phase = false
            } else {
                phase = true
            }
        }
        .onDisappear { phase = false }
        .accessibilityHidden(true)
    }
}
