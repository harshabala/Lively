import SwiftUI
import AppKit

// MARK: - DisplaysView

public struct DisplaysView: View {
    @ObservedObject public var spaceMonitor: SpaceMonitor
    public let configStore: ConfigStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(spaceMonitor: SpaceMonitor, configStore: ConfigStore) {
        self.spaceMonitor = spaceMonitor
        self.configStore = configStore
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.xl) {
                screensSection
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
                    ForEach(spaceMonitor.screenSpaces.enumerated(), id: \.element.id) { index, space in
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
            ProgressView()
                .scaleEffect(0.75)
                .tint(LivelyBrand.mutedForeground)
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
}