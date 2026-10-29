import AppKit
import CoreGraphics

// Launch DOOM or find running DOOM
let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.tace.doom")
print("Found \(apps.count) running instances of com.tace.doom")
for a in apps {
    print("PID: \(a.processIdentifier)")
    guard let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
        continue
    }
    for w in windowList {
        let pid = w[kCGWindowOwnerPID as String] as? Int32
        if pid == a.processIdentifier {
            let windowID = w[kCGWindowNumber as String] ?? 0
            let name = w[kCGWindowName as String] ?? "(no name)"
            let bounds = w[kCGWindowBounds as String] ?? [:]
            let layer = w[kCGWindowLayer as String] ?? 0
            let alpha = w[kCGWindowAlpha as String] ?? 1.0
            let isOnScreen = w[kCGWindowIsOnscreen as String] ?? false
            let sharingState = w[kCGWindowSharingState as String] ?? -1
            print("  Window ID: \(windowID), Name: '\(name)', Layer: \(layer), Alpha: \(alpha), OnScreen: \(isOnScreen), SharingState: \(sharingState), Bounds: \(bounds)")
        }
    }
}
