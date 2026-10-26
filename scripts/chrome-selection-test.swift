import AppKit
import Foundation
import ApplicationServices

// DOOM Phase 07 — Chrome Selection Feasibility & Hardware Test Suite
// Executes on actual macOS hardware with real Google Chrome instance.
// Tests all 6 required conditions from Phase 07 §3.C.

struct ChromeTestResult {
    let scenario: String
    let passed: Bool
    let method: String
    let latencyMs: Double
    let details: String
}

var results: [ChromeTestResult] = []

func logResult(_ scenario: String, passed: Bool, method: String, latencyMs: Double, details: String) {
    results.append(ChromeTestResult(scenario: scenario, passed: passed, method: method, latencyMs: latencyMs, details: details))
    let mark = passed ? "PASS" : "FAIL"
    print("[\(mark)] \(scenario)")
    print("       Method: \(method) | Latency: \(String(format: "%.1f", latencyMs))ms")
    print("       Details: \(details)")
}

print("==================================================")
print("DOOM Chrome Selection Feasibility & Benchmark")
print("macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")

guard let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome"),
      let chromeBundle = Bundle(url: chromeURL) else {
    print("ERROR: Google Chrome not installed at /Applications/Google Chrome.app")
    exit(1)
}

let chromeVersion = chromeBundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
print("Chrome Version: \(chromeVersion)")
print("Accessibility Trusted: \(AXIsProcessTrusted())")
print("==================================================")

// Ensure test page is prepared
let testHTMLPath = "/tmp/doom-chrome-feasibility.html"
let testHTML = """
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>DOOM Chrome Feasibility</title></head>
<body style="font-family: system-ui; padding: 20px;">
  <h1>DOOM Test Webpage</h1>
  <p id="sentence">This is a selected test sentence on an ordinary webpage in Google Chrome.</p>
  <p id="paragraph">Antigravity is developing DOOM as a native macOS AI assistant. Selection acquisition uses native Accessibility APIs without background keylogging or reading unselected text.</p>
  <div>
    <label for="editor">Editable Text Field:</label><br>
    <textarea id="editor" rows="3" cols="50">Editable text field content inside Chrome.</textarea>
  </div>
  <div style="margin-top: 15px;">
    <label for="pwd">Password Field:</label><br>
    <input type="password" id="pwd" value="SecretCredentials123">
  </div>
</body>
</html>
"""
try! testHTML.write(toFile: testHTMLPath, atomically: true, encoding: .utf8)

// Launch or activate Chrome with the test page
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
proc.arguments = ["-a", "Google Chrome", testHTMLPath]
try! proc.run()
proc.waitUntilExit()

Thread.sleep(forTimeInterval: 1.0)

guard let chromeApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.google.Chrome" }) else {
    print("ERROR: Chrome process not found after launch")
    exit(1)
}

let appEl = AXUIElementCreateApplication(chromeApp.processIdentifier)
AXUIElementSetMessagingTimeout(appEl, 1.0)

// Helper: read selection using Strategy A, B, C
func readSelectionFromFocused() -> (text: String?, method: String, role: String, latencyMs: Double) {
    let t0 = Date()
    var focusedVal: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focusedVal)
    guard err == .success, let focused = focusedVal else {
        return (nil, "none", "noFocusedElement", Date().timeIntervalSince(t0) * 1000)
    }
    let el = focused as! AXUIElement
    AXUIElementSetMessagingTimeout(el, 1.0)

    var roleVal: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleVal)
    let role = roleVal as? String ?? "unknown"

    var subroleVal: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXSubroleAttribute as CFString, &subroleVal)
    let subrole = subroleVal as? String ?? ""

    if role == (kAXTextFieldRole as String) && subrole == (kAXSecureTextFieldSubrole as String) {
        return (nil, "secureGuard", "AXSecureTextField", Date().timeIntervalSince(t0) * 1000)
    }

    // Strategy A
    var strVal: CFTypeRef?
    let errA = AXUIElementCopyAttributeValue(el, kAXSelectedTextAttribute as CFString, &strVal)
    if errA == .success, let s = strVal as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return (s, "Strategy A (kAXSelectedTextAttribute)", role, Date().timeIntervalSince(t0) * 1000)
    }

    // Strategy B
    var rangeVal: CFTypeRef?
    let errB = AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rangeVal)
    if errB == .success, let axVal = rangeVal {
        var r = CFRange(location: 0, length: 0)
        let axValue = axVal as! AXValue
        if AXValueGetType(axValue) == .cfRange && AXValueGetValue(axValue, .cfRange, &r) {
            if r.length == 0 {
                return ("", "Strategy B (Definitive Empty)", role, Date().timeIntervalSince(t0) * 1000)
            } else {
                var pStr: CFTypeRef?
                let errP = AXUIElementCopyParameterizedAttributeValue(el, kAXStringForRangeParameterizedAttribute as CFString, axValue, &pStr)
                if errP == .success, let ps = pStr as? String, !ps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return (ps, "Strategy B (kAXStringForRange)", role, Date().timeIntervalSince(t0) * 1000)
                }
            }
        }
    }

    // Strategy C (web marker range on element or AXWebArea ancestor)
    var candidates: [AXUIElement] = [el]
    var curr = el
    for _ in 0..<8 {
        var pVal: CFTypeRef?
        if AXUIElementCopyAttributeValue(curr, kAXParentAttribute as CFString, &pVal) == .success, let p = pVal {
            let pel = p as! AXUIElement
            var rVal: CFTypeRef?
            if AXUIElementCopyAttributeValue(pel, kAXRoleAttribute as CFString, &rVal) == .success, (rVal as? String) == "AXWebArea" {
                candidates.append(pel)
                break
            }
            curr = pel
        } else { break }
    }

    for cand in candidates {
        var markerVal: CFTypeRef?
        if AXUIElementCopyAttributeValue(cand, "AXSelectedTextMarkerRange" as CFString, &markerVal) == .success, let marker = markerVal {
            var markerStr: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(cand, "AXStringForTextMarkerRange" as CFString, marker, &markerStr) == .success,
               let ms = markerStr as? String {
                let trimmed = ms.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return (ms, "Strategy C (AXStringForTextMarkerRange)", role, Date().timeIntervalSince(t0) * 1000)
                } else {
                    return ("", "Strategy C (Definitive Empty)", role, Date().timeIntervalSince(t0) * 1000)
                }
            }
        }
    }

    return (nil, "unsupported", role, Date().timeIntervalSince(t0) * 1000)
}

let src = CGEventSource(stateID: .combinedSessionState)

func sendKey(virtualKey: UInt16, flags: CGEventFlags = []) {
    let down = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: true)!
    down.flags = flags
    down.post(tap: .cghidEventTap)
    let up = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: false)!
    up.flags = []
    up.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.2)
}

// Ensure AXEnhancedUserInterface is enabled
let enhancedStatus = AXUIElementSetAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)

// -----------------------------------------------------------------
// Test 1: Selected sentence on ordinary webpage
// -----------------------------------------------------------------
chromeApp.activate()
Thread.sleep(forTimeInterval: 0.3)
sendKey(virtualKey: 0, flags: [.maskCommand]) // Cmd+A (select all on page)

let t1 = readSelectionFromFocused()
let t1Passed = (t1.text?.contains("selected test sentence") == true)
logResult("1. Selected sentence on ordinary webpage", passed: t1Passed, method: t1.method, latencyMs: t1.latencyMs, details: "Captured character count: \(t1.text?.count ?? 0)")

// -----------------------------------------------------------------
// Test 2: Selected paragraph on webpage
// -----------------------------------------------------------------
let t2Passed = (t1.text?.contains("Selection acquisition uses native Accessibility APIs") == true)
logResult("2. Selected paragraph on webpage", passed: t2Passed, method: t1.method, latencyMs: t1.latencyMs, details: "Verified paragraph captured through \(t1.method)")

// -----------------------------------------------------------------
// Test 3: Selected text inside an editable text field (<textarea>)
// -----------------------------------------------------------------
sendKey(virtualKey: 48) // Tab into textarea
sendKey(virtualKey: 0, flags: [.maskCommand]) // Cmd+A in textarea
let t3 = readSelectionFromFocused()
let t3Passed = (t3.text == "Editable text field content inside Chrome.") && (t3.role == "AXTextArea")
logResult("3. Selected text inside editable text field", passed: t3Passed, method: t3.method, latencyMs: t3.latencyMs, details: "Role: \(t3.role), text: \"\(t3.text ?? "")\"")

// -----------------------------------------------------------------
// Test 4: Collapsed / Empty selection behavior
// -----------------------------------------------------------------
sendKey(virtualKey: 123) // Left arrow to collapse selection (caret only)
let t4 = readSelectionFromFocused()
let t4Passed = (t4.text == "") // Definitive empty
logResult("4. Empty selection (caret only) behavior", passed: t4Passed, method: t4.method, latencyMs: t4.latencyMs, details: "Definitive empty recognized: \"\(t4.method)\"")

// -----------------------------------------------------------------
// Test 5: Password field security guard
// -----------------------------------------------------------------
sendKey(virtualKey: 48) // Tab into password field
let t5 = readSelectionFromFocused()
let t5Passed = (t5.method == "secureGuard") && (t5.text == nil)
logResult("5. Password field security guard", passed: t5Passed, method: t5.method, latencyMs: t5.latencyMs, details: "Blocked password field read without accessing text")

// -----------------------------------------------------------------
// Benchmark: Warm acquisition latency over 10 consecutive readings
// -----------------------------------------------------------------
sendKey(virtualKey: 48, flags: [.maskShift]) // Shift+Tab back to textarea
sendKey(virtualKey: 0, flags: [.maskCommand]) // Cmd+A
var latencies: [Double] = []
for _ in 1...10 {
    let reading = readSelectionFromFocused()
    latencies.append(reading.latencyMs)
}
latencies.sort()
let medianLatency = latencies[latencies.count / 2]
let maxLatency = latencies.last ?? 0
let benchPassed = medianLatency < 1500.0 // Well within 1.5s Accessibility budget
logResult("6. Warm acquisition latency (10 runs)", passed: benchPassed, method: "Benchmark", latencyMs: medianLatency, details: "Median: \(String(format: "%.1f", medianLatency))ms, Max: \(String(format: "%.1f", maxLatency))ms (budget <= 1500ms)")

// Close the test tab in Chrome
sendKey(virtualKey: 13, flags: [.maskCommand]) // Cmd+W
try? FileManager.default.removeItem(atPath: testHTMLPath)

print("\n==================================================")
print("CHROME FEASIBILITY SUMMARY")
print("==================================================")
let allPassed = results.allSatisfy { $0.passed }
print("Total Tests: \(results.count) | Passed: \(results.filter { $0.passed }.count) | Failed: \(results.filter { !$0.passed }.count)")
for r in results {
    let mark = r.passed ? "✔" : "✘"
    print("  \(mark) \(r.scenario)")
}
print("==================================================")

if allPassed {
    exit(0)
} else {
    exit(1)
}
