import Foundation

public enum PanelGeometry {
    public static let defaultWidth: CGFloat = 440.0
    public static let minHeight: CGFloat = 132.0
    public static let maxHeightCap: CGFloat = 560.0
    public static let screenHeightFraction: CGFloat = 0.70
    public static let screenMargin: CGFloat = 16.0

    public static func clampedHeight(requested: CGFloat, screenVisibleHeight: CGFloat) -> CGFloat {
        let maxAllowed = min(maxHeightCap, screenVisibleHeight * screenHeightFraction)
        let effectiveMax = max(minHeight, maxAllowed)
        return max(minHeight, min(requested, effectiveMax))
    }

    public static func frame(
        contentHeight: CGFloat,
        visibleFrame: CGRect,
        userOrigin: CGPoint? = nil
    ) -> CGRect {
        let height = clampedHeight(requested: contentHeight, screenVisibleHeight: visibleFrame.height)
        let width = defaultWidth

        if let origin = userOrigin {
            let candidateRect = CGRect(origin: origin, size: CGSize(width: width, height: height))
            if visibleFrame.intersects(candidateRect) {
                let minX = visibleFrame.minX + screenMargin
                let maxX = max(minX, visibleFrame.maxX - width - screenMargin)
                let clampedX = min(max(origin.x, minX), maxX)

                let minY = visibleFrame.minY + screenMargin
                let maxY = max(minY, visibleFrame.maxY - height - screenMargin)
                let clampedY = min(max(origin.y, minY), maxY)

                return CGRect(x: clampedX, y: clampedY, width: width, height: height)
            }
        }

        // Default: top-right with 16 pt margins
        let x = visibleFrame.maxX - width - screenMargin
        let y = visibleFrame.maxY - height - screenMargin
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
