import SwiftUI

/// Shared pill-style tab bar used for primary and secondary navigation.
struct PillTabBar<Selection: Hashable>: View {
    let tabs: [(label: String, value: Selection)]
    @Binding var selection: Selection
    @Namespace private var tabIndicator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                tabButton(tab.label, value: tab.value, index: index, total: tabs.count)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.md)
                .fill(LivelyBrand.foreground.opacity(0.05))
        )
    }

    private func tabButton(_ label: String, value: Selection, index: Int, total: Int) -> some View {
        let isSelected = selection == value
        return Button {
            withAnimation(reduceMotion ? nil : LivelyBrand.Motion.fast) { selection = value }
        } label: {
            Text(label)
                .font(LivelyBrand.Typography.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? LivelyBrand.foreground : LivelyBrand.mutedForeground)
                .padding(.horizontal, LivelyBrand.Spacing.md)
                .padding(.vertical, LivelyBrand.Spacing.sm)
                .frame(minHeight: 32)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                            .fill(LivelyBrand.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                                    .strokeBorder(LivelyBrand.border.opacity(0.45))
                            )
                            .matchedGeometryEffect(id: "pill", in: tabIndicator)
                    }
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Tab \(index + 1) of \(total)")
    }
}

/// Lightweight pressed-state feedback for plain toolbar controls.
struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : LivelyBrand.Motion.fast, value: configuration.isPressed)
    }
}