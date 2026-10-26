import AppKit
import Foundation
import ApplicationServices

// DOOM Phase 07 — TextEdit Selection & Hardware Verification Suite (TEXT-RM-01 / TEXT-03)
// Executes on actual macOS hardware with real TextEdit instance.
// Tests native app selection: word, paragraph, emoji, and RTL text.

struct TestEditResult {
    let scenario: String
    let passed: Bool
    let method: String
    let latencyMs: Double
    let details: String
}

var results: [TestEditResult] = []

func logResult(_ scenario: String, passed: Bool, method: String, latencyMs: Double, details: String) {
    results.append(TestEditResult(scenario: scenario, passed: passed, method: method, latencyMs: latencyMs, details: details))
    let mark = passed ? "PASS" : "FAIL"
    print("[\(mark)] \(scenario)")
    print("       Method: \(method) | Latency: \(String(format: "%.1f", latencyMs))ms")
    print("       Details: \(details)")
}

print("==================================================")
print("DOOM Native App Selection Test (TextEdit - TEXT-RM-01)")
print("macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
print("Accessibility Trusted: \(AXIsProcessTrusted())")
print("==================================================")

guard AXIsProcessTrusted() else {
    print("ERROR: Process not trusted for Accessibility.")
    exit(1)
}

// 1. Launch or activate TextEdit
let textEditConfig = NSWorkspace.OpenConfiguration()
textEditConfig.activates = true

let textEditApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.TextEdit" })
let pid: pid_t
if let app = textEditApp {
    pid = app.processIdentifier
    app.activate()
} else {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") else {
        print("ERROR: TextEdit not found")
        exit(1)
    }
    let sema = DispatchSemaphore(value: 0)
    var launchedApp: NSRunningApplication?
    NSWorkspace.shared.openApplication(at: appURL, configuration: textEditConfig) { app, _ in
        launchedApp = app
        sema.signal()
    }
    _ = sema.wait(timeout: .now() + 5.0)
    guard let app = launchedApp ?? NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.TextEdit" }) else {
        print("ERROR: Could not launch TextEdit")
        exit(1)
    }
    pid = app.processIdentifier
    Thread.sleep(forTimeInterval: 1.0)
}

let appElement = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(appElement, 1.0)

// Helper: read selection from focused element
func readSelection(from appEl: AXUIElement) -> (text: String?, method: String, latencyMs: Double) {
    let t0 = CFAbsoluteTimeGetCurrent()
    var focusedValue: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focusedValue)
    guard status == .success, let focused = focusedValue else {
        let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        return (nil, "noFocusedElement", elapsed)
    }
    let focusedEl = focused as! AXUIElement
    AXUIElementSetMessagingTimeout(focusedEl, 1.0)

    // Strategy A: kAXSelectedTextAttribute
    var selTextValue: CFTypeRef?
    let aStatus = AXUIElementCopyAttributeValue(focusedEl, kAXSelectedTextAttribute as CFString, &selTextValue)
    if aStatus == .success, let str = selTextValue as? String, !str.isEmpty {
        let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        return (str, "Strategy A (kAXSelectedTextAttribute)", elapsed)
    }

    // Strategy B: kAXSelectedTextRangeAttribute
    var rangeValue: CFTypeRef?
    let bStatus = AXUIElementCopyAttributeValue(focusedEl, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
    if bStatus == .success, let rVal = rangeValue, CFGetTypeID(rVal) == AXValueGetTypeID() {
        let axVal = rVal as! AXValue
        var range = CFRange(location: 0, length: 0)
        if AXValueGetType(axVal) == .cfRange, AXValueGetValue(axVal, .cfRange, &range) {
            if range.length == 0 {
                let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
                return ("", "Strategy B (Range length 0 - empty)", elapsed)
            }
            var paramText: CFTypeRef?
            let pStatus = AXUIElementCopyParameterizedAttributeValue(focusedEl, kAXStringForRangeParameterizedAttribute as CFString, axVal, &paramText)
            if pStatus == .success, let pStr = paramText as? String {
                let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
                return (pStr, "Strategy B (Parameterized)", elapsed)
            }
        }
    }

    let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
    return (nil, "None", elapsed)
}

// Helper: set selection range on focused element
func setSelection(range: CFRange, in appEl: AXUIElement) -> Bool {
    var focusedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
          let focused = focusedValue else { return false }
    let focusedEl = focused as! AXUIElement

    var r = range
    guard let axVal = AXValueCreate(.cfRange, &r) else { return false }
    let status = AXUIElementSetAttributeValue(focusedEl, kAXSelectedTextRangeAttribute as CFString, axVal)
    return status == .success
}

// Helper: set text content of focused element
func setTextContent(_ text: String, in appEl: AXUIElement) -> Bool {
    var focusedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
          let focused = focusedValue else { return false }
    let focusedEl = focused as! AXUIElement
    let status = AXUIElementSetAttributeValue(focusedEl, kAXValueAttribute as CFString, text as CFString)
    return status == .success
}

// Prepare a new untitled document if none open
let testContent = """
Acquisition is the primary objective of DOOM Phase 07.
DOOM is a native macOS companion designed for focused tasks.
Emoji test: 🚀✨🔥 and RTL test: مرحبا بالعالم - שלום עולם
"""

// Set value and run test suite
let script = """
tell application "TextEdit"
    activate
    make new document at front
    set text of front document to "\(testContent)"
end tell
"""
let appleScript = NSAppleScript(source: script)
var scriptError: NSDictionary?
appleScript?.executeAndReturnError(&scriptError)
Thread.sleep(forTimeInterval: 0.8)

// TEST 1: Single Word Selection ("Acquisition")
// "Acquisition" is range location 0, length 11
_ = setSelection(range: CFRange(location: 0, length: 11), in: appElement)
Thread.sleep(forTimeInterval: 0.1)
let t1 = readSelection(from: appElement)
let t1Pass = t1.text == "Acquisition"
logResult("1. Word selection in TextEdit", passed: t1Pass, method: t1.method, latencyMs: t1.latencyMs, details: "Captured: '\(t1.text ?? "nil")'")

// TEST 2: Paragraph Selection ("DOOM is a native macOS companion designed for focused tasks.")
// Location: 55, length: 60
_ = setSelection(range: CFRange(location: 55, length: 60), in: appElement)
Thread.sleep(forTimeInterval: 0.1)
let t2 = readSelection(from: appElement)
let t2Pass = (t2.text?.contains("DOOM is a native macOS companion") ?? false)
logResult("2. Paragraph selection in TextEdit", passed: t2Pass, method: t2.method, latencyMs: t2.latencyMs, details: "Length: \(t2.text?.count ?? 0) characters")

// TEST 3: Emoji Multi-scalar Selection ("🚀✨🔥")
// Location: 128, length: 5 (or search range)
var focusedValue: CFTypeRef?
_ = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
if let focused = focusedValue {
    let focusedEl = focused as! AXUIElement
    var fullVal: CFTypeRef?
    _ = AXUIElementCopyAttributeValue(focusedEl, kAXValueAttribute as CFString, &fullVal)
    if let fullStr = fullVal as? NSString {
        let emojiRange = fullStr.range(of: "🚀✨🔥")
        if emojiRange.location != NSNotFound {
            _ = setSelection(range: CFRange(location: emojiRange.location, length: emojiRange.length), in: appElement)
            Thread.sleep(forTimeInterval: 0.1)
            let t3 = readSelection(from: appElement)
            let t3Pass = t3.text == "🚀✨🔥"
            logResult("3. Emoji selection in TextEdit", passed: t3Pass, method: t3.method, latencyMs: t3.latencyMs, details: "Exact emoji match: \(t3Pass) (Graphemes preserved)")
        }
    }
}

// TEST 4: RTL Multilingual Selection ("مرحبا بالعالم - שלום עולם")
if let focused = focusedValue {
    let focusedEl = focused as! AXUIElement
    var fullVal: CFTypeRef?
    _ = AXUIElementCopyAttributeValue(focusedEl, kAXValueAttribute as CFString, &fullVal)
    if let fullStr = fullVal as? NSString {
        let rtlRange = fullStr.range(of: "مرحبا بالعالم - שלום עולם")
        if rtlRange.location != NSNotFound {
            _ = setSelection(range: CFRange(location: rtlRange.location, length: rtlRange.length), in: appElement)
            Thread.sleep(forTimeInterval: 0.1)
            let t4 = readSelection(from: appElement)
            let t4Pass = t4.text == "مرحبا بالعالم - שלום עולם"
            logResult("4. RTL multilingual selection in TextEdit", passed: t4Pass, method: t4.method, latencyMs: t4.latencyMs, details: "Exact RTL match: \(t4Pass)")
        }
    }
}

// TEST 5: Empty selection (caret only)
_ = setSelection(range: CFRange(location: 0, length: 0), in: appElement)
Thread.sleep(forTimeInterval: 0.1)
let t5 = readSelection(from: appElement)
let t5Pass = (t5.text == "" && t5.method.contains("Strategy B"))
logResult("5. Empty selection in TextEdit", passed: t5Pass, method: t5.method, latencyMs: t5.latencyMs, details: "Definitive empty recognized via Strategy B range 0")

// Close untitled document without saving
let closeScript = """
tell application "TextEdit"
    if (count of documents) > 0 then
        close front document saving no
    end if
end tell
"""
NSAppleScript(source: closeScript)?.executeAndReturnError(nil)

print("==================================================")
let allPassed = results.allSatisfy { $0.passed }
print("Summary: \(results.filter { $0.passed }.count)/\(results.count) tests passed.")
if allPassed {
    print("TEXT-RM-01 (TextEdit native selection): PASS")
    exit(0)
} else {
    print("TEXT-RM-01 (TextEdit native selection): FAIL")
    exit(1)
}
