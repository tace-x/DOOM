import Testing
import Foundation
@testable import DoomFeatures

struct ThemeContrastTests {
    @Test("TextPrimary contrast exceeds 4.5:1 across backgrounds")
    func textPrimaryContrast() {
        let onDeep = DoomTheme.rawTextPrimary.contrastRatio(against: DoomTheme.rawBgDeep)
        let onHigh = DoomTheme.rawTextPrimary.contrastRatio(against: DoomTheme.rawBgHigh)
        let onSurfaceHigh = DoomTheme.rawTextPrimary.contrastRatio(against: DoomTheme.rawSurfaceHigh)
        let onControl = DoomTheme.rawTextPrimary.contrastRatio(against: DoomTheme.rawControl)

        #expect(onDeep >= 4.5)
        #expect(onHigh >= 4.5)
        #expect(onSurfaceHigh >= 4.5)
        #expect(onControl >= 4.5)
    }

    @Test("TextSecondary contrast exceeds 4.5:1 across backgrounds")
    func textSecondaryContrast() {
        let onDeep = DoomTheme.rawTextSecondary.contrastRatio(against: DoomTheme.rawBgDeep)
        let onHigh = DoomTheme.rawTextSecondary.contrastRatio(against: DoomTheme.rawBgHigh)
        let onSurfaceHigh = DoomTheme.rawTextSecondary.contrastRatio(against: DoomTheme.rawSurfaceHigh)
        let onControl = DoomTheme.rawTextSecondary.contrastRatio(against: DoomTheme.rawControl)

        #expect(onDeep >= 4.5)
        #expect(onHigh >= 4.5)
        #expect(onSurfaceHigh >= 4.5)
        #expect(onControl >= 4.5)
    }

    @Test("TextTertiary contrast exceeds 4.5:1 on bgDeep and bgHigh")
    func textTertiaryContrast() {
        let onDeep = DoomTheme.rawTextTertiary.contrastRatio(against: DoomTheme.rawBgDeep)
        let onHigh = DoomTheme.rawTextTertiary.contrastRatio(against: DoomTheme.rawBgHigh)

        #expect(onDeep >= 4.5)
        #expect(onHigh >= 4.5)

        // As specified in UI_SPECIFICATION.md §2.2, textTertiary fails on control (< 4.5) and is forbidden there
        let onControl = DoomTheme.rawTextTertiary.contrastRatio(against: DoomTheme.rawControl)
        #expect(onControl < 4.5)
    }

    @Test("AccentText contrast exceeds 4.5:1 on dark surfaces")
    func accentTextContrast() {
        let onDeep = DoomTheme.rawAccentText.contrastRatio(against: DoomTheme.rawBgDeep)
        let onHigh = DoomTheme.rawAccentText.contrastRatio(against: DoomTheme.rawBgHigh)
        let onSurfaceHigh = DoomTheme.rawAccentText.contrastRatio(against: DoomTheme.rawSurfaceHigh)

        #expect(onDeep >= 4.5)
        #expect(onHigh >= 4.5)
        #expect(onSurfaceHigh >= 4.5)
    }

    @Test("Warning and Error contrast exceeds 4.5:1 on background surfaces")
    func statusColorsContrast() {
        let warningOnDeep = DoomTheme.rawWarning.contrastRatio(against: DoomTheme.rawBgDeep)
        let warningOnHigh = DoomTheme.rawWarning.contrastRatio(against: DoomTheme.rawBgHigh)
        let errorOnDeep = DoomTheme.rawError.contrastRatio(against: DoomTheme.rawBgDeep)
        let errorOnHigh = DoomTheme.rawError.contrastRatio(against: DoomTheme.rawBgHigh)

        #expect(warningOnDeep >= 4.5)
        #expect(warningOnHigh >= 4.5)
        #expect(errorOnDeep >= 4.5)
        #expect(errorOnHigh >= 4.5)

        // Error on control fails (< 4.5) and is forbidden
        let errorOnControl = DoomTheme.rawError.contrastRatio(against: DoomTheme.rawControl)
        #expect(errorOnControl < 4.5)
    }

    @Test("Primary button dark text meets contrast on emerald accent fill")
    func primaryButtonContrast() {
        let contrast = DoomTheme.rawPrimaryButtonText.contrastRatio(against: DoomTheme.rawAccent)
        #expect(contrast >= 4.5)

        // White on accent is prohibited because it fails 4.5:1 (around 3.20:1)
        let white = DoomTheme.HexColor(r: 255, g: 255, b: 255, hex: "#FFFFFF")
        let whiteOnAccent = white.contrastRatio(against: DoomTheme.rawAccent)
        #expect(whiteOnAccent < 4.5)
    }
}
