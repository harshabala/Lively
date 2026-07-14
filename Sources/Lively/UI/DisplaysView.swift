import SwiftUI
import AppKit

// MARK: - DisplaysView

public struct DisplaysView: View {
    @ObservedObject public var spaceMonitor: SpaceMonitor
    public let configStore: ConfigStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var displayedDays: Int = 0
    @ViewState private var isLibraryButtonHovered = false

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
                    
                    libraryButton
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

    private var libraryButton: some View {
        Button {
            LibraryWindowController.shared.openLibraryWindow(spaceMonitor: spaceMonitor, configStore: configStore)
        } label: {
            HStack(spacing: LivelyBrand.Spacing.md) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(LivelyBrand.Typography.iconSmall)
                    .foregroundStyle(LivelyBrand.primary)
                
                VStack(alignment: .leading, spacing: LivelyBrand.Spacing.tiny) {
                    Text("Wallpaper Library")
                        .font(LivelyBrand.Typography.body.weight(.semibold))
                        .foregroundStyle(LivelyBrand.foreground)
                    Text("Save videos once and reuse them on any display.")
                        .font(LivelyBrand.Typography.footnote)
                        .foregroundStyle(LivelyBrand.mutedForeground)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(LivelyBrand.Typography.footnote)
                    .foregroundStyle(LivelyBrand.mutedForeground)
            }
            .padding(LivelyBrand.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.md)
                .fill(LivelyBrand.card.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.md)
                .strokeBorder(LivelyBrand.border.opacity(0.35), lineWidth: 1)
        )
        .scaleEffect(isLibraryButtonHovered && !reduceMotion ? 1.01 : 1.0)
        .animation(reduceMotion ? nil : LivelyBrand.Motion.fast, value: isLibraryButtonHovered)
        .onHover { hovering in
            isLibraryButtonHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Open Wallpaper Library")
        .accessibilityHint("Open your reusable wallpaper library to add or apply videos.")
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(LivelyBrand.Typography.footnote.weight(.semibold))
            .foregroundStyle(LivelyBrand.mutedForeground)
    }

    @ViewBuilder
    private var metricsFooter: some View {
        let target = AppMetrics.shared.daysWithWallpaperActive
        if target > 0 {
            VStack(spacing: LivelyBrand.Spacing.tiny) {
                HStack(spacing: LivelyBrand.Spacing.xs) {
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Active \(target) days. Counts days Lively was actively rendering. Stored only on this device. Never uploaded.")
            .task {
                guard !reduceMotion else {
                    displayedDays = target
                    return
                }
                let steps = min(target, 20)
                let stepSize = max(1, target / steps)
                for i in 0...steps {
                    do {
                        try await Task.sleep(for: .milliseconds(40))
                        withAnimation(.spring(duration: 0.2, bounce: 0.2)) {
                            displayedDays = (i == steps) ? target : min(i * stepSize, target)
                        }
                    } catch {
                        break // Exit immediately on cancellation
                    }
                }
            }
        }
    }
}