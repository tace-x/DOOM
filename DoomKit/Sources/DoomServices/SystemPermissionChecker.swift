import Foundation
import DoomCore
#if canImport(ApplicationServices)
import ApplicationServices
#endif
#if canImport(AppKit)
import AppKit
#endif

public struct SystemPermissionChecker: PermissionChecking, Sendable {
    public init() {}

    public func accessibilityState() -> PermissionState {
        #if canImport(ApplicationServices)
        return AXIsProcessTrusted() ? .granted : .notGranted
        #else
        return .notGranted
        #endif
    }

    @MainActor
    public func requestAccessibility() {
        #if canImport(ApplicationServices)
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        #endif
    }

    @MainActor
    public func openAccessibilitySettings() {
        #if canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}
