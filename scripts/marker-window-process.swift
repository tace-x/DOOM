import AppKit

// MARK: - Dev-Only Target Window Process
// Shows a distinct Magenta window (R:255, G:0, B:255) with sharingType = .none

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let windowRect = NSRect(x: 200, y: 200, width: 300, height: 300)
let panel = NSPanel(
    contentRect: windowRect,
    styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
panel.level = .floating
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.hidesOnDeactivate = false
panel.backgroundColor = NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
panel.isOpaque = true
panel.sharingType = .none
panel.title = "DOOM_TEST_MARKER_NONE"
panel.orderFrontRegardless()

print("WINDOW_READY PID:\(ProcessInfo.processInfo.processIdentifier) WindowNumber:\(panel.windowNumber) sharingType:\(panel.sharingType.rawValue)")
fflush(stdout)

RunLoop.current.run()
