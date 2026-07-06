import SwiftUI
import AppKit

// MARK: - Glass Effect Implementation

struct GlassEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Type System

struct GlassEffectType {
    let material: NSVisualEffectView.Material
    let tintColor: Color?
    let tintOpacity: Double

    static let regular = GlassEffectType(material: .headerView, tintColor: nil, tintOpacity: 0.10)
    static let thick = GlassEffectType(material: .contentBackground, tintColor: nil, tintOpacity: 0.10)
    static let thin = GlassEffectType(material: .hudWindow, tintColor: nil, tintOpacity: 0.10)
    static let ultraThin = GlassEffectType(material: .underPageBackground, tintColor: nil, tintOpacity: 0.10)
    static let clear = GlassEffectType(material: .fullScreenUI, tintColor: nil, tintOpacity: 0.10)

    func tint(_ color: Color?) -> GlassEffectType {
        GlassEffectType(material: material, tintColor: color, tintOpacity: tintOpacity)
    }

    func opacity(_ value: Double) -> GlassEffectType {
        GlassEffectType(material: material, tintColor: tintColor, tintOpacity: value)
    }
}

// MARK: - Extensions

extension View {
    func liquidGlass(_ type: GlassEffectType = .regular, in shape: some Shape) -> some View {
        self.background(
            ZStack {
                GlassEffect(material: type.material, blendingMode: .withinWindow)
                if let color = type.tintColor {
                    color.opacity(type.tintOpacity)
                }
            }
            .clipShape(shape)
        )
    }
}

// MARK: - Button Style

struct GlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tint: Color? = nil
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isProminent ? .white : .primary)
            .background(
                ZStack {
                    GlassEffect(material: .headerView, blendingMode: .withinWindow)
                    if let tint = tint {
                        tint.opacity(configuration.isPressed ? 0.26 : isProminent ? 0.92 : 0.14)
                    } else {
                        LivelyBrand.foreground.opacity(configuration.isPressed ? 0.1 : 0.0)
                    }
                }
                .cornerRadius(8)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.0),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
}

extension GlassButtonStyle {
    func tint(_ color: Color) -> GlassButtonStyle {
        var copy = self
        copy.tint = color
        return copy
    }

    func prominent(_ value: Bool = true) -> GlassButtonStyle {
        var copy = self
        copy.isProminent = value
        return copy
    }
}
