import SwiftUI

/// Soft brand focus outline for keyboard users without the system blue rect.
/// Uses `@FocusState` on a wrapper so we do not depend on Environment isFocused availability.
struct LivelyFocusRing: ViewModifier {
    var cornerRadius: CGFloat = LivelyBrand.Radius.navItem
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusEffectDisabled()
            .focused($isFocused)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LivelyBrand.primary.opacity(isFocused ? 0.55 : 0),
                        lineWidth: 2
                    )
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    /// Disables the system focus effect and draws a subtle Lively focus ring when focused.
    func livelyFocusRing(cornerRadius: CGFloat = LivelyBrand.Radius.navItem) -> some View {
        modifier(LivelyFocusRing(cornerRadius: cornerRadius))
    }
}
