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

    static let regular = GlassEffectType(material: .headerView, tintColor: nil)
    static let thick = GlassEffectType(material: .contentBackground, tintColor: nil)
    static let thin = GlassEffectType(material: .hudWindow, tintColor: nil)
    static let ultraThin = GlassEffectType(material: .underPageBackground, tintColor: nil)
    static let clear = GlassEffectType(material: .fullScreenUI, tintColor: nil)

    func tint(_ color: Color?) -> GlassEffectType {
        GlassEffectType(material: self.material, tintColor: color)
    }
}

// MARK: - Extensions

extension View {
    func liquidGlass(_ type: GlassEffectType = .regular, in shape: some Shape) -> some View {
        self.background(
            ZStack {
                GlassEffect(material: type.material, blendingMode: .withinWindow)
                if let color = type.tintColor {
                    color.opacity(0.1) // Subtle tint
                }
            }
            .clipShape(shape)
        )
    }
}

// MARK: - Containers

struct GlassEffectContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(10) // default padding for container
    }
}

// MARK: - Button Style

struct GlassButtonStyle: ButtonStyle {
    var tint: Color? = nil
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    GlassEffect(material: .headerView, blendingMode: .withinWindow)
                    if let tint = tint {
                        tint.opacity(configuration.isPressed ? 0.2 : 0.1)
                    } else {
                        Color.white.opacity(configuration.isPressed ? 0.1 : 0.0)
                    }
                }
                .cornerRadius(8)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
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
}
