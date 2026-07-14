import SwiftUI

/// Design Spell: Three staggered breathing dots that replace boring ProgressView spinners.
/// Each dot pulses in opacity and scale with a cascading delay — feels alive, not mechanical.
struct BreathingDotsView: View {
    @ViewState private var phase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let dotSize: CGFloat = 5
    private let delays: [Double] = [0, 0.18, 0.36]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(LivelyBrand.primary)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(phase ? 1.0 : 0.55)
                    .opacity(phase ? 0.85 : 0.25)
                    .animation(
                        reduceMotion ? nil :
                            .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(delays[index]),
                        value: phase
                    )
            }
        }
        .onAppear { phase = true }
        .onDisappear { phase = false }
        .accessibilityHidden(true)
    }

}
