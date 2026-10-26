import AppKit
import Foundation

// DOOM Phase 06 — Fn Shortcut Hardware Feasibility Diagnostic
// Privacy Compliance:
// - Observes ONLY .flagsChanged and .keyDown
// - Reads ONLY event.type, event.modifierFlags, event.timestamp, and keyCode (on flagsChanged only)
// - NEVER reads event.characters or character data
// - NEVER records history or logs sensitive content

struct DiagnosticRecognizer {
    enum State: Equatable {
        case idle
        case armed(Double)
        case cancelled
    }
    
    private(set) var state: State = .idle
    private(set) var activationCount: Int = 0
    private(set) var armedCount: Int = 0
    private(set) var cancelCount: Int = 0
    
    mutating func handleFlags(flags: NSEvent.ModifierFlags, timestamp: Double, keyCode: UInt16) -> (activated: Bool, stateDescription: String) {
        let hasFn = flags.contains(.function)
        let hasCtrl = flags.contains(.control)
        let hasOpt = flags.contains(.option)
        let hasCmd = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        
        let isChordDown = hasFn && hasCtrl && hasOpt
        let hasExcluded = hasCmd || hasShift
        
        switch state {
        case .idle:
            if isChordDown && !hasExcluded {
                state = .armed(timestamp)
                armedCount += 1
                return (false, "ARMED (t0: \(String(format: "%.3f", timestamp))) [flags: fn=\(hasFn) ctrl=\(hasCtrl) opt=\(optKeyCode(keyCode))]")
            }
            return (false, "IDLE [flags: fn=\(hasFn) ctrl=\(hasCtrl) opt=\(hasOpt) cmd=\(hasCmd) shift=\(hasShift)]")
            
        case .armed(let t0):
            if hasExcluded {
                state = .cancelled
                cancelCount += 1
                return (false, "CANCELLED (excluded modifier pressed: cmd=\(hasCmd) shift=\(hasShift))")
            }
            let isAllReleased = !hasFn && !hasCtrl && !hasOpt
            if isAllReleased {
                let holdDuration = timestamp - t0
                state = .idle
                if holdDuration <= 2.0 {
                    activationCount += 1
                    return (true, "ACTIVATED (clean release after \(String(format: "%.3f", holdDuration))s)")
                } else {
                    return (false, "EXPIRED (held \(String(format: "%.3f", holdDuration))s > 2.0s limit, no activation)")
                }
            }
            return (false, "ARMED (waiting for release, current: fn=\(hasFn) ctrl=\(hasCtrl) opt=\(hasOpt))")
            
        case .cancelled:
            let isAllReleased = !hasFn && !hasCtrl && !hasOpt && !hasExcluded
            if isAllReleased {
                state = .idle
                return (false, "IDLE (reset after cancellation)")
            }
            return (false, "CANCELLED (waiting for full release)")
        }
    }
    
    mutating func handleKeyDown() -> (activated: Bool, stateDescription: String) {
        if case .armed = state {
            state = .cancelled
            cancelCount += 1
            return (false, "CANCELLED by ordinary key press (zero characters read)")
        }
        return (false, "KEY_DOWN ignored while idle/cancelled (zero characters read)")
    }
    
    private func optKeyCode(_ kc: UInt16) -> String {
        return "kc=\(kc)"
    }
}

print("==================================================")
print("DOOM Hardware Feasibility Diagnostic")
print("Target: Fn + Control + Option (Activation Chord)")
print("==================================================")
print("Process AXIsProcessTrusted:", AXIsProcessTrusted())

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

var recognizer = DiagnosticRecognizer()
var eventCount = 0

let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
    eventCount += 1
    if event.type == .flagsChanged {
        let (activated, desc) = recognizer.handleFlags(flags: event.modifierFlags, timestamp: event.timestamp, keyCode: event.keyCode)
        print(" [Global flagsChanged #\(eventCount)] \(desc)")
        if activated {
            print(" >>> ACTIVATION TRIGGERED! Total activations: \(recognizer.activationCount)")
        }
    } else if event.type == .keyDown {
        let (_, desc) = recognizer.handleKeyDown()
        print(" [Global keyDown #\(eventCount)] \(desc)")
    }
}

let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
    eventCount += 1
    if event.type == .flagsChanged {
        let (activated, desc) = recognizer.handleFlags(flags: event.modifierFlags, timestamp: event.timestamp, keyCode: event.keyCode)
        print(" [Local flagsChanged #\(eventCount)] \(desc)")
        if activated {
            print(" >>> ACTIVATION TRIGGERED! Total activations: \(recognizer.activationCount)")
        }
    } else if event.type == .keyDown {
        let (_, desc) = recognizer.handleKeyDown()
        print(" [Local keyDown #\(eventCount)] \(desc)")
    }
    return event
}

print("Monitors installed. Listening for events...")
print("Test Plan:")
print(" 1. Press and release Fn + Control + Option together.")
print(" 2. Verify arming and activation.")
print(" 3. Verify releasing the keys does NOT cause repeated activation.")
print(" 4. Verify typing an ordinary key cancels armed state.")
print(" 5. Verify no characters or sensitive data are read.")
