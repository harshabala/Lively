import SwiftUI
import AppKit

enum LivelyBrand {
    static let background = adaptive(light: "#F2FFFE", dark: "#031116")
    static let backgroundLifted = adaptive(light: "#E5F3F3", dark: "#071A23")
    static let card = adaptive(light: "#FFFFFF", dark: "#0B1D24")
    static let primary = adaptive(light: "#007078", dark: "#55CAD0")
    static let primarySoft = adaptive(light: "#43B6BB", dark: "#9FE8EA")
    static let foreground = adaptive(light: "#0B1B20", dark: "#F0FBFC")
    static let mutedForeground = adaptive(light: "#516970", dark: "#8CAAB1")
    static let border = adaptive(light: "#C8DADA", dark: "#2B4952")
    static let accent = adaptive(light: "#E3F2F1", dark: "#12313A")
    static let destructive = Color.red

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [background, backgroundLifted],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primarySoft],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let full: CGFloat = 9999
    }

    enum Typography {
        static let title = Font.system(size: 18, weight: .semibold)
        static let section = Font.system(size: 13, weight: .semibold)
        static let body = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 12, weight: .medium)
        static let footnote = Font.system(size: 11, weight: .regular)
        static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
    }

    enum Motion {
        static let fast       = Animation.spring(duration: 0.2, bounce: 0)
        static let normal     = Animation.spring(duration: 0.3, bounce: 0)
        static let dropTarget = Animation.spring(duration: 0.2, bounce: 0)
    }

    private static func adaptive(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255

        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
