import Foundation

public protocol PermissionChecking: Sendable {
    func accessibilityState() -> PermissionState
    @MainActor func requestAccessibility()
    @MainActor func openAccessibilitySettings()
}
