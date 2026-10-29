import Foundation
import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo

let markerPath = "/Users/immanuelmelbin/Downloads/DOOM/DOOM/scripts/marker-window-process.swift"

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
proc.arguments = [markerPath]

let pipe = Pipe()
proc.standardOutput = pipe
proc.standardError = pipe

try proc.run()

let handle = pipe.fileHandleForReading
var outputData = Data()
while true {
    let chunk = handle.availableData
    if chunk.isEmpty { break }
    outputData.append(chunk)
    if let str = String(data: outputData, encoding: .utf8), str.contains("WINDOW_READY") {
        print("Marker window process running: \(str.trimmingCharacters(in: .whitespacesAndNewlines))")
        break
    }
    Thread.sleep(forTimeInterval: 0.1)
}

Thread.sleep(forTimeInterval: 1.0)

defer {
    proc.terminate()
    print("Marker window process terminated.")
}

// Inspect ScreenCaptureKit and CoreGraphics captures
Task { @MainActor in
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    guard let display = content.displays.first else {
        print("No display found")
        exit(1)
    }

    let config = SCStreamConfiguration()
    config.width = Int(display.width)
    config.height = Int(display.height)
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.showsCursor = false

    // 1. SCScreenshotManager display capture
    let filterDisplay = SCContentFilter(display: display, excludingWindows: [])
    let scImage = try await SCScreenshotManager.captureImage(contentFilter: filterDisplay, configuration: config)
    
    // Pixel sample at x: 350, y: (display.height - 350)
    let scaleX = Double(scImage.width) / Double(display.width)
    let scaleY = Double(scImage.height) / Double(display.height)
    let pxX = Int(350.0 * scaleX)
    let pxY = Int((Double(display.height) - 350.0) * scaleY)

    func samplePixel(cgImage: CGImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard let dataProvider = cgImage.dataProvider, let data = dataProvider.data else { return nil }
        let ptr = CFDataGetBytePtr(data)!
        let bpr = cgImage.bytesPerRow
        let offset = y * bpr + x * 4
        let b = ptr[offset]
        let g = ptr[offset + 1]
        let r = ptr[offset + 2]
        let a = ptr[offset + 3]
        return (r, g, b, a)
    }

    if let px = samplePixel(cgImage: scImage, x: pxX, y: pxY) {
        print("1. SCScreenshotManager (display:excludingWindows:[]): R:\(px.r) G:\(px.g) B:\(px.b) A:\(px.a)")
        if px.r > 200 && px.g < 50 && px.b > 200 {
            print("   -> INCLUDED in SCScreenshotManager display capture!")
        } else {
            print("   -> EXCLUDED from SCScreenshotManager display capture (not magenta)")
        }
    }

    print("2. CGWindowListCreateImage: Obsoleted in macOS 15.0 per CGWindow.h header")

    // 3. /usr/sbin/screencapture
    let tempPath = "/tmp/test_screencapture_none.png"
    let scProc = Process()
    scProc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    scProc.arguments = ["-x", "-C", tempPath]
    try scProc.run()
    scProc.waitUntilExit()

    if let img = NSImage(contentsOfFile: tempPath), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        let sX = Double(cg.width) / Double(display.width)
        let sY = Double(cg.height) / Double(display.height)
        let cX = Int(350.0 * sX)
        let cY = Int((Double(display.height) - 350.0) * sY)
        if let px = samplePixel(cgImage: cg, x: cX, y: cY) {
            print("3. /usr/sbin/screencapture: R:\(px.r) G:\(px.g) B:\(px.b) A:\(px.a)")
            if px.r > 200 && px.g < 50 && px.b > 200 {
                print("   -> INCLUDED in /usr/sbin/screencapture!")
            } else {
                print("   -> EXCLUDED from /usr/sbin/screencapture (not magenta)")
            }
        }
    }

    exit(0)
}

RunLoop.current.run()
