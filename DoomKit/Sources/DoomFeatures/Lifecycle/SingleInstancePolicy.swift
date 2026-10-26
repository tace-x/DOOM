import Foundation
#if canImport(AppKit)
import AppKit
#endif

public enum SingleInstancePolicy {
    public static func shouldTerminateDuplicate(currentPID: pid_t, existingPIDs: [pid_t]) -> Bool {
        return existingPIDs.contains { $0 != currentPID }
    }

    #if canImport(AppKit)
    @MainActor
    public static func checkAndHandleDuplicate(bundleIdentifier: String, currentPID: pid_t) -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        let otherInstances = runningApps.filter { $0.processIdentifier != currentPID }
        if let existing = otherInstances.first {
            existing.activate()
            return true
        }
        return false
    }
    #endif
}
