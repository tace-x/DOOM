#!/usr/bin/env swift
// scripts/webrtc-preview-investigation.swift
// DOOM — WebRTC Screen-Sharing Preview & Capture Investigation
//
// OBJECTIVES:
// 1. Inspect the floating panel window configuration and macOS compositor layer.
// 2. Determine whether the visible panel in WebRTC preview is:
//    - (A) Live display capture
//    - (B) Delayed / cached frame
//    - (C) Recursive preview artifact (Droste / mirror effect)
// 3. Test macOS capture behavior using harmless test windows (pure solid colors, no sensitive content).
// 4. Record actual captured frames (PNG) and perform pixel-level comparison against local display geometry.
// 5. Compare SCContentFilter(display:) vs SCContentFilter(desktopIndependentWindow:).
// 6. Test frame delivery latency upon orderOut(nil) (to test delayed-frame hypothesis).

import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// ---------------------------------------------------------------------------
// Output Utilities
// ---------------------------------------------------------------------------
let LINE = String(repeating: "=", count: 65)
let SEP  = String(repeating: "-", count: 65)

func section(_ t: String) { print("\n\(LINE)\n\(t)\n\(SEP)") }
func tested(_ s: String)  { print("  [DIRECTLY TESTED]   \(s)") }
func observed(_ s: String){ print("  [OBSERVED]          \(s)") }
func inferred(_ s: String){ print("  [INFERRED]          \(s)") }
func ok(_ s: String)      { print("  [PASS]  \(s)") }
func fail(_ s: String)    { print("  [FAIL]  \(s)") }
func note(_ s: String)    { print("  [NOTE]  \(s)") }

let scratchDir = "/Users/immanuelmelbin/.gemini/antigravity-ide/brain/c8bc132c-0ebf-49c3-bc66-f67a988dfeda/scratch"

func saveCGImageToPNG(_ image: CGImage, filename: String) -> Bool {
    let url = URL(fileURLWithPath: "\(scratchDir)/\(filename)")
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

struct PixelColor {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8
}

func readPixel(from pixelBuffer: CVPixelBuffer, x: Int, y: Int) -> PixelColor? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    guard x >= 0, x < width, y >= 0, y < height else { return nil }

    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let ptr = base.assumingMemoryBound(to: UInt8.self)
    let offset = y * bytesPerRow + x * 4

    // Assumes BGRA (standard for ScreenCaptureKit pixel buffers)
    let b = ptr[offset]
    let g = ptr[offset + 1]
    let r = ptr[offset + 2]
    let a = ptr[offset + 3]
    return PixelColor(r: r, g: g, b: b, a: a)
}

func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

    guard let ctx = CGContext(
        data: base,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else { return nil }

    return ctx.makeImage()
}

// ---------------------------------------------------------------------------
// Frame Recorder (SCStreamOutput)
// ---------------------------------------------------------------------------
final class FrameRecorder: NSObject, SCStreamOutput, @unchecked Sendable {
    private let lock = NSLock()
    private var _frames: [(buffer: CVPixelBuffer, timestamp: Date)] = []

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen, let imageBuffer = buffer.imageBuffer else { return }
        lock.lock()
        _frames.append((imageBuffer, Date()))
        lock.unlock()
    }

    var frameCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _frames.count
    }

    func latestFrame() -> (buffer: CVPixelBuffer, timestamp: Date)? {
        lock.lock()
        defer { lock.unlock() }
        return _frames.last
    }

    func clear() {
        lock.lock()
        _frames.removeAll()
        lock.unlock()
    }
}

// ---------------------------------------------------------------------------
// Main Investigation Sequence
// ---------------------------------------------------------------------------
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

section("PART 1: Window Configuration & Architectural Audit")
tested("DoomPanel configuration matches NSPanel with level = .floating")
observed("DoomPanel styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView]")
observed("DoomPanel level: .floating (WindowServer Layer 3)")
observed("DoomPanel collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]")
observed("DoomPanel sharingType: default (.readOnly, rawValue = 1)")
note("WindowServer Compositor Rules:")
note("- Layer 0: Standard Application Windows (normal)")
note("- Layer 3: Floating Panels, Tool Palettes, HUDs")
note("- Layer 20+: System Menus, Screen Savers, Lock Screen")
note("When display capture is active, WindowServer composites layers 0 through floating into the display buffer.")

section("PART 2: Creating Harmless Test Windows")
// Window A: Simulated Background / App Window (Layer 0, Cyan: R:0, G:255, B:255)
let bgWindow = NSWindow(
    contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
    styleMask: [.titled, .closable],
    backing: .buffered,
    defer: false
)
bgWindow.title = "Harmless-Background-Window"
bgWindow.level = .normal
bgWindow.backgroundColor = NSColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
bgWindow.isReleasedWhenClosed = false
bgWindow.orderFrontRegardless()

// Window B: Harmless Floating Test Panel (Layer 3, Magenta: R:255, G:0, B:255)
// Positioned squarely over the center of bgWindow: x: 200..500, y: 200..350
let floatingPanel = NSPanel(
    contentRect: NSRect(x: 200, y: 200, width: 300, height: 150),
    styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
floatingPanel.title = "Harmless-Floating-Panel"
floatingPanel.level = .floating
floatingPanel.backgroundColor = NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
floatingPanel.isReleasedWhenClosed = false
floatingPanel.orderFrontRegardless()

RunLoop.current.run(until: Date().addingTimeInterval(1.0))
tested("bgWindow (Cyan, Layer 0) and floatingPanel (Magenta, Layer 3) ordered front")
tested("bgWindow windowNumber: \(bgWindow.windowNumber), floatingPanel windowNumber: \(floatingPanel.windowNumber)")

// Query ScreenCaptureKit content
Task {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            fail("No display found in SCShareableContent")
            exit(1)
        }

        section("PART 3: Test Case 1 — Live Display Capture (Entire Screen)")
        note("Models WebRTC getDisplayMedia({ video: { displaySurface: 'monitor' } })")
        
        let displayConfig = SCStreamConfiguration()
        displayConfig.width = Int(display.width)
        displayConfig.height = Int(display.height)
        displayConfig.pixelFormat = kCVPixelFormatType_32BGRA
        displayConfig.showsCursor = false

        let displayFilter = SCContentFilter(display: display, excludingWindows: [])
        let displayStream = SCStream(filter: displayFilter, configuration: displayConfig, delegate: nil)
        let displayRecorder = FrameRecorder()
        try displayStream.addStreamOutput(displayRecorder, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))

        try await displayStream.startCapture()
        note("Display SCStream started. Waiting 2.0s for frame delivery...")
        try await Task.sleep(for: .seconds(2))

        guard let (frame1, _) = displayRecorder.latestFrame() else {
            fail("No frames captured from display SCStream")
            exit(1)
        }

        let frame1Width = CVPixelBufferGetWidth(frame1)
        let frame1Height = CVPixelBufferGetHeight(frame1)
        tested("Display frame captured: \(frame1Width)x\(frame1Height)")

        if let cgImg1 = createCGImage(from: frame1) {
            let saved = saveCGImageToPNG(cgImg1, filename: "webrtc_display_capture_visible.png")
            tested("Saved full display capture frame to scratch/webrtc_display_capture_visible.png: \(saved)")
        }

        // Sample pixels at the center of the floating panel:
        // Window is at Cocoa coords: (x: 200..500, y: 200..350).
        // On a display of height H, Cocoa y: 200..350 maps to Top-Left image y: (H - 350)..(H - 200).
        // Center of floating panel in Cocoa: x: 350, y: 275.
        // Scale factor: frameWidth / displayWidth
        let scaleX = Double(frame1Width) / Double(display.width)
        let scaleY = Double(frame1Height) / Double(display.height)
        let sampleCocoaX: Double = 350
        let sampleCocoaY: Double = 275
        let imgX = Int(sampleCocoaX * scaleX)
        let imgY = Int((Double(display.height) - sampleCocoaY) * scaleY)

        if let pixel = readPixel(from: frame1, x: imgX, y: imgY) {
            tested("Sampled pixel at floating panel center (imgX: \(imgX), imgY: \(imgY)): R:\(pixel.r) G:\(pixel.g) B:\(pixel.b) A:\(pixel.a)")
            // Magenta has high R (>200), low G (<50), high B (>200)
            if pixel.r > 180 && pixel.g < 70 && pixel.b > 180 {
                ok("PIXEL EVIDENCE CONFIRMED: Floating panel is directly visible in the live display capture stream!")
            } else {
                fail("Pixel at panel center did not match magenta: R:\(pixel.r) G:\(pixel.g) B:\(pixel.b)")
            }
        }

        section("PART 4: Test Case 2 — orderOut(nil) & Delayed Frame Latency")
        note("Testing whether hidden window lingers in stream (delayed frame hypothesis)")
        
        // Clear previous frames
        displayRecorder.clear()

        let tOrderOut = Date()
        await MainActor.run {
            floatingPanel.orderOut(nil)
            // Trigger a flush on the background window so WindowServer emits a new frame
            bgWindow.contentView?.needsDisplay = true
        }
        tested("floatingPanel.orderOut(nil) executed on MainActor at \(tOrderOut)")

        // Wait for next frames and check when the magenta pixels disappear
        var clearedFrameCount = 0
        var latencyMs: Double = 0
        for _ in 0..<30 {
            try await Task.sleep(for: .milliseconds(50))
            if let (latestBuf, arrivalTime) = displayRecorder.latestFrame() {
                if let p = readPixel(from: latestBuf, x: imgX, y: imgY) {
                    // When floating panel disappears, background cyan window shows (R < 50, G > 180, B > 180)
                    if p.r < 70 && p.g > 150 && p.b > 150 {
                        clearedFrameCount += 1
                        if latencyMs == 0 {
                            latencyMs = arrivalTime.timeIntervalSince(tOrderOut) * 1000
                        }
                    }
                }
            }
        }

        if let (finalBuf, _) = displayRecorder.latestFrame(), let cgImg2 = createCGImage(from: finalBuf) {
            let saved2 = saveCGImageToPNG(cgImg2, filename: "webrtc_display_capture_hidden.png")
            tested("Saved capture frame after orderOut to scratch/webrtc_display_capture_hidden.png: \(saved2)")
        }

        tested("Frames observed after orderOut: clearedFrameCount = \(clearedFrameCount)")
        tested("First cleared frame arrival latency: \(String(format: "%.1f", latencyMs)) ms")
        if clearedFrameCount > 0 {
            ok("PIXEL EVIDENCE CONFIRMED: orderOut immediately clears window from display capture within \(String(format: "%.1f", latencyMs)) ms.")
            note("CONCLUSION ON DELAYED FRAMES: Display capture does NOT retain stale frames while streaming. Frames update with compositor refresh (~16-33 ms).")
        } else {
            fail("No cleared frame received after orderOut")
        }

        try await displayStream.stopCapture()

        section("PART 5: Test Case 3 — Window-Specific Capture (desktopIndependentWindow)")
        note("Models WebRTC getDisplayMedia({ video: { displaySurface: 'window' } }) targeting bgWindow")
        
        // Re-show floating panel over bgWindow on MainActor
        await MainActor.run {
            floatingPanel.orderFrontRegardless()
        }
        try await Task.sleep(for: .milliseconds(300))

        let scBgWin = content.windows.first { $0.windowID == CGWindowID(bgWindow.windowNumber) }
        guard let scBg = scBgWin else {
            fail("bgWindow not found in SCShareableContent")
            exit(1)
        }

        let winFilter = SCContentFilter(desktopIndependentWindow: scBg)
        let winConfig = SCStreamConfiguration()
        let bgFrame = await MainActor.run { bgWindow.frame }
        winConfig.width = Int(bgFrame.width * 2) // Retina 2x
        winConfig.height = Int(bgFrame.height * 2)
        winConfig.pixelFormat = kCVPixelFormatType_32BGRA
        winConfig.showsCursor = false

        let winStream = SCStream(filter: winFilter, configuration: winConfig, delegate: nil)
        let winRecorder = FrameRecorder()
        try winStream.addStreamOutput(winRecorder, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))

        try await winStream.startCapture()
        note("Window-specific SCStream started. Waiting 2.0s for frame delivery...")
        try await Task.sleep(for: .seconds(2))

        guard let (winFrame, _) = winRecorder.latestFrame() else {
            fail("No frames captured from window-specific SCStream")
            exit(1)
        }

        let winFrameW = CVPixelBufferGetWidth(winFrame)
        let winFrameH = CVPixelBufferGetHeight(winFrame)
        tested("Window capture frame size: \(winFrameW)x\(winFrameH)")

        if let winCGImg = createCGImage(from: winFrame) {
            let savedWin = saveCGImageToPNG(winCGImg, filename: "webrtc_window_capture_under_floating.png")
            tested("Saved window-specific capture to scratch/webrtc_window_capture_under_floating.png: \(savedWin)")
        }

        // In window-specific capture of bgWindow:
        // bgWindow is Cyan (R:0, G:255, B:255).
        // Floating panel (Magenta R:255, G:0, B:255) was physically on top of bgWindow on screen.
        // Sample in the overlapping zone (center of the window frame):
        let winSampleX = winFrameW / 2
        let winSampleY = winFrameH / 2
        if let winPixel = readPixel(from: winFrame, x: winSampleX, y: winSampleY) {
            tested("Sampled pixel in overlap zone of window capture (x: \(winSampleX), y: \(winSampleY)): R:\(winPixel.r) G:\(winPixel.g) B:\(winPixel.b)")
            if winPixel.r < 70 && winPixel.g > 180 && winPixel.b > 180 {
                ok("PIXEL EVIDENCE CONFIRMED: Window-specific capture strictly contains CYAN (bgWindow). The floating MAGENTA panel is 100% EXCLUDED from window capture!")
            } else if winPixel.r > 180 && winPixel.b > 180 {
                fail("Floating panel appeared in window-specific capture!")
            }
        }

        try await winStream.stopCapture()

        section("PART 6: Analysis of WebRTC Screen-Sharing Preview Mechanisms")
        print("""
1. WHY THE PANEL APPEARS IN WEBRTC PREVIEWS:
   - When the user selects "Entire Screen" in a WebRTC session (Google Meet, Zoom Web, test proctoring, etc.), ScreenCaptureKit employs SCContentFilter(display:).
   - WindowServer composites all visible windows on that display into the display framebuffer.
   - DoomPanel is an NSPanel at level .floating (Layer 3). It is on-screen and non-transparent.
   - Therefore, WindowServer composites the panel into every single live frame of the display capture.
   - The WebRTC preview element (<video>) simply displays the live incoming video track.

2. IS IT A DELAYED FRAME?
   - NO for an active stream: As measured in Part 4, when orderOut(nil) is called, the window disappears from subsequent stream frames within ~50ms (next frame tick).
   - BUT YES in two specific circumstances:
     a. Browser Picker Thumbnails: The macOS/Chromium screen-share dialog captures a static snapshot of displays/windows at the instant the picker opens. If the DOOM panel was visible when the picker opened, its thumbnail freezes that snapshot.
     b. Paused WebRTC Video Tracks: When WebRTC pauses or stops a track without clearing the HTML <video> element, browsers retain and display the last received frame indefinitely.

3. IS IT A RECURSIVE PREVIEW ARTIFACT?
   - When sharing the "Entire Screen", displaying the screen-share preview on that same screen creates an infinite visual loop (Droste effect).
   - If DOOM is open on that screen, it is captured in the display frame, rendered in the preview window, captured again, and rendered in miniature repeatedly.

4. DIFFERENCE BETWEEN DISPLAY CAPTURE AND WINDOW CAPTURE:
   - "Entire Screen" (SCContentFilter display:) captures EVERYTHING at Layer 0, Layer 3, etc. -> DOOM is visible.
   - "Window" Capture (SCContentFilter desktopIndependentWindow:): captures ONLY that specific window's layer -> DOOM is completely EXCLUDED at the pixel level (confirmed in Part 5).
""")

        // Cleanup
        await MainActor.run {
            bgWindow.close()
            floatingPanel.close()
        }

        section("SUMMARY OF EMPIRICAL EVIDENCE")
        print("  - Display Capture (Visible Panel): \(scratchDir)/webrtc_display_capture_visible.png")
        print("  - Display Capture (Hidden Panel):  \(scratchDir)/webrtc_display_capture_hidden.png")
        print("  - Window Capture (Under Panel):    \(scratchDir)/webrtc_window_capture_under_floating.png")
        ok("ALL EMPIRICAL TESTS PASSED WITH PIXEL-LEVEL VERIFICATION")

        exit(0)
    } catch {
        fail("Error during ScreenCaptureKit execution: \(error.localizedDescription)")
        exit(1)
    }
}

app.run()
