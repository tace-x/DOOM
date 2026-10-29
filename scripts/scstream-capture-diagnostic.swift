#!/usr/bin/env swift
// scripts/scstream-capture-diagnostic.swift
// DOOM — Harmless SCStream Capture Diagnostic
//
// PURPOSE
// Distinguishes "enumerating shareable windows" (SCShareableContent) from
// "actually starting a capture stream and receiving frames" (SCStream).
//
// WHAT THIS SCRIPT DIRECTLY MEASURES
//   D-1  SCShareableContent permission grant and window enumeration
//   D-2  Display-capture SCStream starts and delivers ≥1 video frame
//   D-3  Window-specific SCStream starts and delivers ≥1 video frame
//   D-4  orderOut removes test window from SCShareableContent on-screen list
//   D-5  orderOut removes test window from display stream's shareable windows
//
// WHAT THIS SCRIPT DOES NOT CLAIM TO MEASURE
//   - Real browser WebRTC getDisplayMedia() behavior
//   - Pixel content of captured frames (complex, requires Core Image analysis)
//   - Third-party application behavior (Zoom, Google Meet, etc.)
//
// REQUIREMENTS
//   - macOS 12.3+ (ScreenCaptureKit)
//   - Screen Recording permission granted to Terminal (or swift interpreter)
//   - Run: swift scripts/scstream-capture-diagnostic.swift
//
// EXIT CODES
//   0  All measured tests passed
//   1  One or more measured tests failed (see FAIL lines in output)
//   2  Screen Recording permission denied — test cannot run
//   3  Unexpected fatal error

import AppKit
import ScreenCaptureKit
import Foundation
import CoreMedia

// ---------------------------------------------------------------------------
// MARK: — Constants & Utilities
// ---------------------------------------------------------------------------

let LINE = String(repeating: "=", count: 60)
let SEP  = String(repeating: "-", count: 60)

func section(_ t: String) { print("\n\(LINE)\n\(t)\n\(SEP)") }
func tested(_ s: String)  { print("  [DIRECTLY TESTED]   \(s)") }
func inferred(_ s: String){ print("  [INFERRED]          \(s)") }
func notTested(_ s: String){ print("  [NOT TESTED]        \(s)") }
func ok(_ s: String)      { print("  [PASS]  \(s)") }
func fail(_ s: String)    { print("  [FAIL]  \(s)") }
func warn(_ s: String)    { print("  [WARN]  \(s)") }
func note(_ s: String)    { print("  [NOTE]  \(s)") }

// Thread-safe result accumulator
final class Results: @unchecked Sendable {
    private let lock = NSLock()
    private var failures: [String] = []
    func addFailure(_ s: String) { lock.lock(); failures.append(s); lock.unlock() }
    var hasFailures: Bool { lock.lock(); defer { lock.unlock() }; return !failures.isEmpty }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return failures }
}
let results = Results()

// ---------------------------------------------------------------------------
// MARK: — SCStream Frame Counter
// ---------------------------------------------------------------------------

/// Counts video frames received from an SCStream output.
/// SCStreamOutput callback arrives on a background serial queue.
final class FrameCounter: NSObject, SCStreamOutput, @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    private var _firstFrameTime: Date?

    func stream(_ stream: SCStream,
                didOutputSampleBuffer buffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        guard outputType == .screen else { return }
        lock.lock()
        _count += 1
        if _firstFrameTime == nil { _firstFrameTime = Date() }
        lock.unlock()
    }

    var count: Int { lock.lock(); defer { lock.unlock() }; return _count }
    var firstFrameTime: Date? { lock.lock(); defer { lock.unlock() }; return _firstFrameTime }
}

// ---------------------------------------------------------------------------
// MARK: — Test Window
// ---------------------------------------------------------------------------

/// A harmless floating test window with a distinctive colored background.
/// Content: no sensitive information.
func makeTestWindow() -> NSWindow {
    let win = NSPanel(
        contentRect: NSRect(x: 300, y: 400, width: 340, height: 120),
        styleMask:   [.titled, .nonactivatingPanel],
        backing:     .buffered,
        defer:       false
    )
    win.title  = "DOOM-SCStream-Diagnostic-Test-Window"
    win.level  = .floating
    win.isReleasedWhenClosed = false

    let view = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 120))
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.9).cgColor

    let label = NSTextField(labelWithString: "DOOM Diagnostic: SCStream Test")
    label.frame = NSRect(x: 20, y: 45, width: 300, height: 30)
    label.font = .systemFont(ofSize: 14, weight: .semibold)
    label.textColor = .black
    label.backgroundColor = .clear
    view.addSubview(label)

    let sub = NSTextField(labelWithString: "Harmless test window. No sensitive content.")
    sub.frame = NSRect(x: 20, y: 20, width: 300, height: 20)
    sub.font = .systemFont(ofSize: 11)
    sub.textColor = .darkGray
    view.addSubview(sub)

    win.contentView = view
    win.orderFrontRegardless()
    return win
}

// ---------------------------------------------------------------------------
// MARK: — Main async runner
// ---------------------------------------------------------------------------

let appInstance = NSApplication.shared
appInstance.setActivationPolicy(.accessory)

print(LINE)
print("DOOM — SCStream Capture Diagnostic")
print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
print(LINE)

Task { @MainActor in
    // Allow compositor to register the window
    try? await Task.sleep(nanoseconds: 300_000_000)
    let testWindow = makeTestWindow()
    try? await Task.sleep(nanoseconds: 400_000_000)
    let testWindowID = testWindow.windowNumber

    note("Test window created: '\(testWindow.title)' (windowNumber: \(testWindowID))")
    note("Window level: \(testWindow.level.rawValue) (floating = \(NSWindow.Level.floating.rawValue))")

    // -----------------------------------------------------------------------
    // D-1: SCShareableContent permission + window enumeration
    // -----------------------------------------------------------------------
    section("D-1: SCShareableContent Permission & Window Enumeration")

    let content: SCShareableContent
    do {
        content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        tested("SCShareableContent.excludingDesktopWindows succeeded — Screen Recording permission GRANTED")
        ok("Screen Recording permission: GRANTED")
    } catch {
        fail("SCShareableContent failed: \(error)")
        note("Grant Screen Recording permission to Terminal in System Settings > Privacy & Security > Screen Recording")
        print("\nExit code: 2 (permission denied)")
        exit(2)
    }

    let scTestWindow = content.windows.first { $0.windowID == CGWindowID(testWindowID) }
    if let scTestWindow {
        tested("Test window found in SCShareableContent on-screen list")
        tested("  Window title: '\(scTestWindow.title ?? "<no title>")' windowID: \(scTestWindow.windowID)")
        tested("  isOnScreen: \(scTestWindow.isOnScreen)  layer: \(scTestWindow.windowLayer)")
        ok("D-1: Test window visible in SCShareableContent")
    } else {
        fail("D-1: Test window NOT found in SCShareableContent (windowID: \(testWindowID))")
        warn("Window may not be registered yet; this can happen if Screen Recording was just granted")
        results.addFailure("D-1: Test window absent from SCShareableContent")
    }

    // -----------------------------------------------------------------------
    // D-2: Display-capture SCStream — start stream, receive frames
    // -----------------------------------------------------------------------
    section("D-2: Display-Capture SCStream — Actual Frame Delivery")
    notTested("Remote browser WebRTC stream — not tested here")
    note("Testing: SCStream with SCContentFilter(display:) delivers ≥1 video frame")

    guard let primaryDisplay = content.displays.first else {
        fail("D-2: No display found in SCShareableContent")
        results.addFailure("D-2: No display available")
        print("\nExit code: 3")
        exit(3)
    }

    let displayFilter = SCContentFilter(display: primaryDisplay, excludingWindows: [])
    let displayConfig = SCStreamConfiguration()
    displayConfig.width  = 320
    displayConfig.height = 200
    displayConfig.minimumFrameInterval = CMTime(value: 1, timescale: 10) // 10 fps max
    displayConfig.pixelFormat = kCVPixelFormatType_32BGRA

    let displayCounter = FrameCounter()
    let displayStream  = SCStream(filter: displayFilter, configuration: displayConfig, delegate: nil)

    do {
        let outputQueue = DispatchQueue(label: "com.doom.diagnostic.display", qos: .userInitiated)
        try displayStream.addStreamOutput(displayCounter, type: .screen, sampleHandlerQueue: outputQueue)
        try await displayStream.startCapture()
        tested("SCStream(display:) startCapture() succeeded — no error thrown")
    } catch {
        fail("D-2: SCStream(display:) startCapture() failed: \(error)")
        results.addFailure("D-2: Display stream start failed: \(error)")
    }

    // Wait up to 3 seconds for at least one frame
    let d2Deadline = Date(timeIntervalSinceNow: 3)
    while Date() < d2Deadline && displayCounter.count == 0 {
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    let d2Frames = displayCounter.count
    if d2Frames > 0 {
        tested("SCStream(display:) delivered \(d2Frames) video frame(s) within 3 seconds")
        if let t = displayCounter.firstFrameTime {
            tested("  First frame received at: \(t)")
        }
        ok("D-2: Display SCStream delivered \(d2Frames) frame(s) — stream is functional")
        inferred("Display capture stream would include floating panel at Layer \(scTestWindow?.windowLayer ?? 3)")
        notTested("Pixel content of frames was not inspected to verify panel presence in pixels")
    } else {
        fail("D-2: Display SCStream received 0 frames in 3 seconds")
        results.addFailure("D-2: Display stream received no frames")
    }

    try? await displayStream.stopCapture()

    // -----------------------------------------------------------------------
    // D-3: Window-specific SCStream — start stream, receive frames
    // -----------------------------------------------------------------------
    section("D-3: Window-Specific SCStream — Actual Frame Delivery")
    note("Testing: SCStream with SCContentFilter(desktopIndependentWindow:) delivers ≥1 frame")
    note("The window targeted is the test window itself (harmless; no production DOOM panel)")

    var scTargetForStream = content.windows.first(where: {
        $0.windowID == CGWindowID(testWindowID)
    })

    if scTargetForStream == nil {
        if let refreshed = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) {
            scTargetForStream = refreshed.windows.first(where: { $0.windowID == CGWindowID(testWindowID) })
            if let scTargetForStream {
                note("D-3: Found window in refreshed query (windowID: \(scTargetForStream.windowID))")
            }
        }
    }

    if let scTargetForStream {
        let windowFilter = SCContentFilter(desktopIndependentWindow: scTargetForStream)
    let windowConfig = SCStreamConfiguration()
    windowConfig.width  = 340
    windowConfig.height = 120
    windowConfig.minimumFrameInterval = CMTime(value: 1, timescale: 10)
    windowConfig.pixelFormat = kCVPixelFormatType_32BGRA

    let windowCounter = FrameCounter()
    let windowStream  = SCStream(filter: windowFilter, configuration: windowConfig, delegate: nil)

    do {
        let wQueue = DispatchQueue(label: "com.doom.diagnostic.window", qos: .userInitiated)
        try windowStream.addStreamOutput(windowCounter, type: .screen, sampleHandlerQueue: wQueue)
        try await windowStream.startCapture()
        tested("SCStream(desktopIndependentWindow:) startCapture() succeeded — no error thrown")
        tested("Filter targets: '\(scTargetForStream.title ?? "<no title>")' (windowID: \(scTargetForStream.windowID))")
    } catch {
        fail("D-3: SCStream(desktopIndependentWindow:) startCapture() failed: \(error)")
        results.addFailure("D-3: Window stream start failed: \(error)")
    }

    // Wait up to 3 seconds for frames
    let d3Deadline = Date(timeIntervalSinceNow: 3)
    while Date() < d3Deadline && windowCounter.count == 0 {
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    let d3Frames = windowCounter.count
    if d3Frames > 0 {
        tested("SCStream(desktopIndependentWindow:) delivered \(d3Frames) video frame(s) within 3 seconds")
        ok("D-3: Window SCStream delivered \(d3Frames) frame(s) — filter is functional")
        inferred("desktopIndependentWindow filter isolates only the target window hierarchy")
        inferred("A DOOM floating panel (Layer 3) on top of this window would NOT appear in this stream")
        notTested("Pixel inspection to confirm panel absence was not performed")
    } else {
        fail("D-3: Window SCStream received 0 frames in 3 seconds")
        results.addFailure("D-3: Window stream received no frames")
    }

    try? await windowStream.stopCapture()
    } else {
        warn("D-3: Test window not found in SCShareableContent — skipping window-stream test")
        results.addFailure("D-3: Test window absent from content for window-stream test")
    }

    // -----------------------------------------------------------------------
    // D-4: orderOut removes window from SCShareableContent
    // -----------------------------------------------------------------------
    section("D-4: orderOut Removes Window from SCShareableContent")
    note("Hiding test window via orderOut(nil)...")
    testWindow.orderOut(nil)
    try? await Task.sleep(nanoseconds: 300_000_000) // compositor update

    let contentAfterHide: SCShareableContent
    do {
        contentAfterHide = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        tested("SCShareableContent re-queried after orderOut")
    } catch {
        fail("D-4: Could not re-query SCShareableContent after hide: \(error)")
        results.addFailure("D-4: SCShareableContent query failed after hide")
        print("\nExit code: 3")
        exit(3)
    }

    let stillPresent = contentAfterHide.windows.contains { $0.windowID == CGWindowID(testWindowID) }
    if !stillPresent {
        tested("Test window NO LONGER in SCShareableContent.onScreenWindowsOnly after orderOut(nil)")
        ok("D-4: orderOut removes window from SCShareableContent — window is capture-invisible")
        inferred("Any SCStream currently capturing the display would stop compositing this window")
        inferred("A new SCContentFilter(display:) would not include this window")
        notTested("An in-progress SCStream was not checked for frame-level absence of the hidden window")
    } else {
        fail("D-4: Window STILL present in SCShareableContent after orderOut(nil) (unexpected)")
        results.addFailure("D-4: Window remained in SCShareableContent after orderOut")
    }

    // -----------------------------------------------------------------------
    // D-5: CGWindowListCopyWindowInfo confirms orderOut behavior
    // -----------------------------------------------------------------------
    section("D-5: CGWindowListCopyWindowInfo Confirms orderOut")

    let cgList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
    let cgPresent = cgList.contains { ($0[kCGWindowNumber as String] as? Int) == testWindowID }

    if !cgPresent {
        tested("Window absent from CGWindowListCopyWindowInfo(.optionOnScreenOnly) after orderOut")
        ok("D-5: CGWindowList confirms window is off-screen after orderOut")
    } else {
        fail("D-5: Window still in CGWindowList after orderOut (unexpected)")
        results.addFailure("D-5: Window remained in CGWindowList after orderOut")
    }

    // Restore and confirm
    testWindow.orderFrontRegardless()
    try? await Task.sleep(nanoseconds: 200_000_000)
    let cgListAfterRestore = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
    let cgBack = cgListAfterRestore.contains { ($0[kCGWindowNumber as String] as? Int) == testWindowID }
    if cgBack {
        tested("Window returns to CGWindowList after orderFrontRegardless()")
        ok("D-5: orderFrontRegardless restores window to CGWindowList")
    } else {
        warn("D-5: Window not found in CGWindowList after orderFrontRegardless (may need more time)")
    }

    testWindow.orderOut(nil) // cleanup

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    section("SUMMARY")

    print("""
    EVIDENCE CLASSIFICATION
    \(SEP)
    D-1  SCShareableContent permission & enumeration        DIRECTLY TESTED
    D-2  Display SCStream starts & delivers frames          DIRECTLY TESTED
    D-3  Window SCStream starts & delivers frames           DIRECTLY TESTED
    D-4  orderOut removes window from SCShareableContent    DIRECTLY TESTED
    D-5  CGWindowList confirms orderOut visibility          DIRECTLY TESTED
    \(SEP)
    NOT TESTED IN THIS SCRIPT
    - Real browser WebRTC getDisplayMedia() stream
    - Pixel content of captured frames (frame delivery confirmed, not pixel analysis)
    - Third-party app capture (Zoom, Google Meet, etc.)
    - In-progress SCStream frame-level response to mid-stream orderOut
    \(SEP)
    INFERRED (from D-2, D-3, D-4 combined + Apple SCKit documentation)
    - Display SCStream would include a floating DOOM panel (Layer 3) that is on-screen
    - Window SCStream (desktopIndependentWindow) would exclude floating panels
    - orderOut makes the window invisible to new SCContentFilter queries
    \(SEP)
    """)

    if results.hasFailures {
        print("[RESULT] FAIL — \(results.all.count) test(s) failed:")
        for f in results.all { print("  • \(f)") }
        print("\nExit code: 1")
        exit(1)
    } else {
        print("[RESULT] PASS — All directly-measured tests passed")
        print(LINE)
        print("Exit code: 0")
        exit(0)
    }
}

CFRunLoopRun()
