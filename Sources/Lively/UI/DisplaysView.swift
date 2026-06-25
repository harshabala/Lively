import SwiftUI
import AppKit

// MARK: - DisplaysView

public struct DisplaysView: View {
    @ObservedObject public var spaceMonitor: SpaceMonitor
    public let configStore: ConfigStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    public init(spaceMonitor: SpaceMonitor, configStore: ConfigStore) {
        self.spaceMonitor = spaceMonitor
        self.configStore = configStore
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.xl) {
                screensSection
            }
            .padding(.horizontal, LivelyBrand.Spacing.xl)
            .padding(.vertical, LivelyBrand.Spacing.xl)
        }
        .foregroundStyle(LivelyBrand.foreground)
    }

    // MARK: - Screens Section

    private var screensSection: some View {
        VStack(alignment: .leading, spacing: LivelyBrand.Spacing.md) {
            sectionLabel("Displays", icon: "display.2")

            if spaceMonitor.screenSpaces.isEmpty {
                detectingView
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
                                reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.1).delay(Double(index) * 0.07),
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
    }

    private var detectingView: some View {
        HStack(spacing: LivelyBrand.Spacing.md) {
            ProgressView()
                .scaleEffect(0.75)
                .tint(Color.secondary)
            Text("Detecting displays...")
                .font(.system(size: 13))
                .foregroundStyle(LivelyBrand.mutedForeground)
        }
        .padding(LivelyBrand.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isPulsing ? 0.6 : 1.0)
        .liquidGlass(.regular.tint(LivelyBrand.accent).opacity(0.12), in: RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg)
                .strokeBorder(LivelyBrand.border.opacity(0.42))
        )
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(LivelyBrand.mutedForeground)
            .textCase(.uppercase)
    }
}
