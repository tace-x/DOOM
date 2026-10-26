import Testing
import Foundation
@testable import DoomFeatures

struct PanelGeometryTests {
    let standardScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test("UI-T-01: Default position places 440 pt panel at top-right with 16 pt margin")
    func defaultPlacement() {
        let frame = PanelGeometry.frame(contentHeight: 200, visibleFrame: standardScreen)
        #expect(frame.width == 440)
        #expect(frame.height == 200)
        #expect(frame.maxX == standardScreen.maxX - 16)
        #expect(frame.maxY == standardScreen.maxY - 16)
    }

    @Test("UI-T-02: Height clamping respects min 132 pt and max min(560 pt, 70% height)")
    func heightClamping() {
        // Below min: clamps to 132 pt
        let belowMin = PanelGeometry.frame(contentHeight: 80, visibleFrame: standardScreen)
        #expect(belowMin.height == 132)

        // Above 560 pt: clamps to 560 pt (900 * 0.70 = 630 > 560)
        let aboveCap = PanelGeometry.frame(contentHeight: 800, visibleFrame: standardScreen)
        #expect(aboveCap.height == 560)

        // Small screen (height 600): 600 * 0.70 = 420 < 560, so clamps to 420
        let smallScreen = CGRect(x: 0, y: 0, width: 800, height: 600)
        let smallClamped = PanelGeometry.frame(contentHeight: 500, visibleFrame: smallScreen)
        #expect(smallClamped.height == 420)
    }

    @Test("UI-T-03: User-provided position preserved and clamped to remain on screen")
    func userPositionPreservedAndClamped() {
        let userPos = CGPoint(x: 100, y: 300)
        let frame = PanelGeometry.frame(contentHeight: 200, visibleFrame: standardScreen, userOrigin: userPos)
        #expect(frame.origin.x == 100)
        #expect(frame.origin.y == 300)
        #expect(frame.width == 440)
        #expect(frame.height == 200)

        // If user dragged partially off-screen, it clamps to screen margin
        let offscreenPos = CGPoint(x: -50, y: 800)
        let clampedFrame = PanelGeometry.frame(contentHeight: 200, visibleFrame: standardScreen, userOrigin: offscreenPos)
        #expect(clampedFrame.minX >= standardScreen.minX + 16)
        #expect(clampedFrame.maxY <= standardScreen.maxY - 16)

        // If user origin is completely disconnected from any screen, falls back to default
        let disconnectedPos = CGPoint(x: 5000, y: 5000)
        let fallbackFrame = PanelGeometry.frame(contentHeight: 200, visibleFrame: standardScreen, userOrigin: disconnectedPos)
        #expect(fallbackFrame.maxX == standardScreen.maxX - 16)
        #expect(fallbackFrame.maxY == standardScreen.maxY - 16)
    }
}
