import SwiftUI

public enum DoomTheme {
    public struct HexColor: Sendable, Equatable {
        public let r: Double
        public let g: Double
        public let b: Double
        public let hex: String

        public init(r: Int, g: Int, b: Int, hex: String) {
            self.r = Double(r) / 255.0
            self.g = Double(g) / 255.0
            self.b = Double(b) / 255.0
            self.hex = hex
        }

        public var color: Color {
            Color(red: r, green: g, blue: b)
        }

        public var relativeLuminance: Double {
            func channelLuminance(_ c: Double) -> Double {
                if c <= 0.04045 {
                    return c / 12.92
                } else {
                    return pow((c + 0.055) / 1.055, 2.4)
                }
            }
            let rl = channelLuminance(r)
            let gl = channelLuminance(g)
            let bl = channelLuminance(b)
            return 0.2126 * rl + 0.7152 * gl + 0.0722 * bl
        }

        public func contrastRatio(against other: HexColor) -> Double {
            let l1 = self.relativeLuminance
            let l2 = other.relativeLuminance
            let lighter = max(l1, l2)
            let darker = min(l1, l2)
            return (lighter + 0.05) / (darker + 0.05)
        }
    }

    // Raw Hex Tokens (UI_SPECIFICATION.md §2.1)
    public static let rawBgDeep = HexColor(r: 0x0B, g: 0x0D, b: 0x10, hex: "#0B0D10")
    public static let rawBgHigh = HexColor(r: 0x1B, g: 0x20, b: 0x26, hex: "#1B2026")
    public static let rawSurface = HexColor(r: 0x14, g: 0x17, b: 0x1B, hex: "#14171B")
    public static let rawSurfaceHigh = HexColor(r: 0x1C, g: 0x20, b: 0x26, hex: "#1C2026")
    public static let rawControl = HexColor(r: 0x2A, g: 0x30, b: 0x38, hex: "#2A3038")
    public static let rawMetalHigh = HexColor(r: 0xE6, g: 0xEA, b: 0xEE, hex: "#E6EAEE")
    public static let rawMetalLow = HexColor(r: 0x8A, g: 0x94, b: 0x9E, hex: "#8A949E")
    public static let rawTextPrimary = HexColor(r: 0xE6, g: 0xEA, b: 0xEE, hex: "#E6EAEE")
    public static let rawTextSecondary = HexColor(r: 0x9A, g: 0xA4, b: 0xAE, hex: "#9AA4AE")
    public static let rawTextTertiary = HexColor(r: 0x8A, g: 0x94, b: 0x9E, hex: "#8A949E")
    public static let rawSteel = HexColor(r: 0x5C, g: 0x66, b: 0x70, hex: "#5C6670")
    public static let rawAccent = HexColor(r: 0x2F, g: 0xA3, b: 0x6B, hex: "#2FA36B")
    public static let rawAccentText = HexColor(r: 0x4C, g: 0xC3, b: 0x8A, hex: "#4CC38A")
    public static let rawWarning = HexColor(r: 0xD9, g: 0xA4, b: 0x41, hex: "#D9A441")
    public static let rawError = HexColor(r: 0xE5, g: 0x67, b: 0x5F, hex: "#E5675F")
    public static let rawPrimaryButtonText = HexColor(r: 0x0B, g: 0x0D, b: 0x10, hex: "#0B0D10")

    // SwiftUI Colors
    public static var bgDeep: Color { rawBgDeep.color }
    public static var bgHigh: Color { rawBgHigh.color }
    public static var surface: Color { rawSurface.color }
    public static var surfaceHigh: Color { rawSurfaceHigh.color }
    public static var control: Color { rawControl.color }
    public static var textPrimary: Color { rawTextPrimary.color }
    public static var textSecondary: Color { rawTextSecondary.color }
    public static var textTertiary: Color { rawTextTertiary.color }
    public static var steel: Color { rawSteel.color }
    public static var accent: Color { rawAccent.color }
    public static var accentText: Color { rawAccentText.color }
    public static var warning: Color { rawWarning.color }
    public static var error: Color { rawError.color }
    public static var primaryButtonText: Color { rawPrimaryButtonText.color }

    // Gradients
    public static var background: LinearGradient {
        LinearGradient(
            colors: [bgDeep, bgHigh],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public static var panelBackground: LinearGradient {
        LinearGradient(
            colors: [surface, surfaceHigh],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public static var metal: LinearGradient {
        LinearGradient(
            colors: [rawMetalHigh.color, rawMetalLow.color],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Corner Radius
    public static var cornerRadius: CGFloat { 10.0 }
    public static var cardRadius: CGFloat { 10.0 }
    public static var controlRadius: CGFloat { 6.0 }

    // Spacing
    public enum Spacing {
        public static let xxs: CGFloat = 4.0
        public static let xs: CGFloat = 8.0
        public static let s: CGFloat = 12.0
        public static let m: CGFloat = 16.0
        public static let l: CGFloat = 24.0
    }
}
