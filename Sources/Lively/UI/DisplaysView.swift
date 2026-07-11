import SwiftUI
import AppKit

// MARK: - DisplaysView

public struct DisplaysView: View {
    @ObservedObject public var spaceMonitor: SpaceMonitor
    public let configStore: ConfigStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedDays: Int = 0

    public init(spaceMonitor: SpaceMonitor, configStore: ConfigStore) {
        self.spaceMonitor = spaceMonitor
        self.configStore = configStore
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.xl) {
                screensSection
                
                Divider()
                    .overlay(LivelyBrand.border.opacity(0.45))
                
                metricsFooter
            }
            .padding(.horizontal, LivelyBrand.Spacing.xl)
            .padding(.vertical, LivelyBrand.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(LivelyBrand.foreground)
    }

    private var screensSection: some View {
        VStack(alignment: .leading, spacing: LivelyBrand.Spacing.md) {
            sectionLabel("Displays", icon: "display.2")

            if spaceMonitor.isRefreshing && spaceMonitor.screenSpaces.isEmpty {
                detectingView
                    .transition(.opacity.combined(with: .offset(y: 8)))
            } else if spaceMonitor.screenSpaces.isEmpty {
                emptyDisplaysView
                    .transition(.opacity.combined(with: .offset(y: 8)))
            } else {
                VStack(spacing: LivelyBrand.Spacing.md) {
                    ForEach(Array(spaceMonitor.screenSpaces.enumerated()), id: \.element.id) { index, space in
                        ScreenCardView(space: space, configStore: configStore)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 12)),
                                removal: .opacity
                            ))
                            .animation(
                                reduceMotion ? nil : LivelyBrand.Motion.normal.delay(Double(min(index, 2)) * 0.04),
                                value: spaceMonitor.screenSpaces.count
                            )
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 8)),
                    removal: .opacity
                ))
            }
        }
        .animation(reduceMotion ? nil : LivelyBrand.Motion.normal, value: spaceMonitor.screenSpaces.isEmpty)
        .animation(reduceMotion ? nil : LivelyBrand.Motion.normal, value: spaceMonitor.isRefreshing)
    }

    private var emptyDisplaysView: some View {
        VStack(alignment: .leading, spacing: LivelyBrand.Spacing.sm) {
            Text("No displays detected")
                .font(LivelyBrand.Typography.body.weight(.semibold))
                .foregroundStyle(LivelyBrand.foreground)
            Text("Connect a monitor or check that Screen Recording permission is enabled for Lively in System Settings.")
                .font(LivelyBrand.Typography.caption)
                .foregroundStyle(LivelyBrand.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(LivelyBrand.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg)
                .fill(LivelyBrand.card.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg)
                .strokeBorder(LivelyBrand.border.opacity(0.42))
        )
        .accessibilityElement(children: .combine)
    }

    private var detectingView: some View {
        HStack(spacing: LivelyBrand.Spacing.md) {
            BreathingDotsView()
            Text("Detecting displays...")
                .font(LivelyBrand.Typography.body)
                .foregroundStyle(LivelyBrand.mutedForeground)
        }
        .padding(LivelyBrand.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg)
                .fill(LivelyBrand.card.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg)
                .strokeBorder(LivelyBrand.border.opacity(0.42))
        )
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(LivelyBrand.Typography.footnote.weight(.semibold))
            .foregroundStyle(LivelyBrand.mutedForeground)
    }

    private var metricsFooter: some View {
        let target = AppMetrics.shared.daysWithWallpaperActive
        // M-4: Hide when no days recorded yet (fresh install)
        guard target > 0 else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text("Active")
                        .font(LivelyBrand.Typography.caption)
                        .foregroundStyle(LivelyBrand.mutedForeground)
                    // Spell: number roll-up — count animates from 0 to real value on appear
                    Text("\(displayedDays)")
                        .font(LivelyBrand.Typography.caption.weight(.semibold))
                        .foregroundStyle(LivelyBrand.primary)
                        .contentTransition(.numericText(value: Double(displayedDays)))
                        .monospacedDigit()
                    Text("days.")
                        .font(LivelyBrand.Typography.caption)
                        .foregroundStyle(LivelyBrand.mutedForeground)
                }
                // C-3: Split into two lines; together they read the full spec copy:
                // "Counts days Lively was actively rendering."
                // "Stored only on this device. Never uploaded."
                Text("Counts days Lively was actively rendering.")
                    .font(LivelyBrand.Typography.footnote)
                    .foregroundStyle(LivelyBrand.mutedForeground.opacity(0.7))
                    .multilineTextAlignment(.center)
                Text("Stored only on this device. Never uploaded.")
                    .font(LivelyBrand.Typography.footnote)
                    .foregroundStyle(LivelyBrand.mutedForeground.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .onAppear {
                guard !reduceMotion else {
                    displayedDays = target
                    return
                }
                // I-4: Use Task (Swift Concurrency) instead of DispatchQueue.main.asyncAfter
                // so iterations are automatically cancelled when the view disappears.
                Task { @MainActor in
                    let steps = min(target, 20)
                    let stepSize = max(1, target / steps)
                    for i in 0...steps {
                        try? await Task.sleep(for: .milliseconds(40))  // M-1: 0.04s, no dead ternary
                        withAnimation(.spring(duration: 0.2, bounce: 0.2)) {
                            displayedDays = (i == steps) ? target : min(i * stepSize, target)
                        }
                    }
                }
            }
        )
    }
}