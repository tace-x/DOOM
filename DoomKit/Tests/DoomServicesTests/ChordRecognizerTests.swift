import Testing
import Foundation
@testable import DoomServices

@Suite("ChordRecognizerTests")
struct ChordRecognizerTests {
    // SHORTCUT-T-01: Press F in all 6 orderings, release within 2.0 s -> exactly one .activate
    @Test("All 6 orderings of pressing Fn, Control, Option activate on release within 2.0s")
    func testAllSixOrderingsActivate() {
        enum Key { case fn, ctrl, opt }
        let orderings: [[Key]] = [
            [.fn, .ctrl, .opt],
            [.fn, .opt, .ctrl],
            [.ctrl, .fn, .opt],
            [.ctrl, .opt, .fn],
            [.opt, .fn, .ctrl],
            [.opt, .ctrl, .fn]
        ]

        for ordering in orderings {
            var recognizer = ChordRecognizer()
            var fnDown = false
            var ctrlDown = false
            var optDown = false
            var t: TimeInterval = 100.0

            for key in ordering {
                switch key {
                case .fn: fnDown = true
                case .ctrl: ctrlDown = true
                case .opt: optDown = true
                }
                let snap = ModifierSnapshot(function: fnDown, control: ctrlDown, option: optDown)
                let triggered = recognizer.handle(event: .flagsChanged(snap), timestamp: t)
                #expect(!triggered, "Should not trigger while keys are being pressed down")
                t += 0.05
            }

            #expect(recognizer.state == .armed(t0: t - 0.05))

            // Now release all three
            let emptySnap = ModifierSnapshot()
            let activated = recognizer.handle(event: .flagsChanged(emptySnap), timestamp: t + 0.2)
            #expect(activated, "Should activate upon full release within 2.0s for ordering \(ordering)")
            #expect(recognizer.state == .idle)
        }
    }

    // SHORTCUT-T-02: Any keyDown while ARMED -> no activate. Clean chord afterwards activates.
    @Test("KeyDown cancels armed state")
    func testKeyDownCancelsArmedState() {
        var recognizer = ChordRecognizer()
        let t: TimeInterval = 100.0

        // Arm
        _ = recognizer.handle(
            event: .flagsChanged(ModifierSnapshot(function: true, control: true, option: true)),
            timestamp: t
        )
        #expect(recognizer.state == .armed(t0: t))

        // Key down (e.g., user pressed an arrow key or letter while holding modifiers)
        _ = recognizer.handle(event: .keyDown, timestamp: t + 0.1)
        #expect(recognizer.state == .cancelled)

        // Release modifiers
        let activatedOnRelease = recognizer.handle(
            event: .flagsChanged(ModifierSnapshot()),
            timestamp: t + 0.2
        )
        #expect(!activatedOnRelease, "Should not activate after cancellation")
        #expect(recognizer.state == .idle)

        // Subsequent clean chord works
        _ = recognizer.handle(
            event: .flagsChanged(ModifierSnapshot(function: true, control: true, option: true)),
            timestamp: t + 1.0
        )
        let secondActivated = recognizer.handle(
            event: .flagsChanged(ModifierSnapshot()),
            timestamp: t + 1.2
        )
        #expect(secondActivated, "Subsequent clean chord must activate")
    }

    // SHORTCUT-T-03: Command or Shift added -> cancelled until fully released
    @Test("Command or Shift cancels armed state")
    func testExcludedModifiersCancel() {
        var recognizer = ChordRecognizer()
        let t: TimeInterval = 100.0

        // Arm
        _ = recognizer.handle(
            event: .flagsChanged(ModifierSnapshot(function: true, control: true, option: true)),
            timestamp: t
        )
        #expect(recognizer.state == .armed(t0: t))

        // Add Shift
        _ = recognizer.handle(
            event: .flagsChanged(ModifierSnapshot(function: true, control: true, option: true, shift: true)),
            timestamp: t + 0.1
        )
        #expect(recognizer.state == .cancelled)

        // Release
        let activated = recognizer.handle(event: .flagsChanged(ModifierSnapshot()), timestamp: t + 0.3)
        #expect(!activated)
        #expect(recognizer.state == .idle)
    }

    // SHORTCUT-T-04: Hold duration > 2.0s -> no activate; <= 2.0s -> activate
    @Test("Hold duration boundary at exactly 2.0s and 2.01s")
    func testHoldDurationLimit() {
        // Hold exactly 2.0s -> activate
        var r1 = ChordRecognizer()
        _ = r1.handle(
            event: .flagsChanged(ModifierSnapshot(function: true, control: true, option: true)),
            timestamp: 10.0
        )
        let act1 = r1.handle(event: .flagsChanged(ModifierSnapshot()), timestamp: 12.0)
        #expect(act1, "Hold of exactly 2.0s must activate")

        // Hold 2.01s -> no activate
        var r2 = ChordRecognizer()
        _ = r2.handle(
            event: .flagsChanged(ModifierSnapshot(function: true, control: true, option: true)),
            timestamp: 10.0
        )
        let act2 = r2.handle(event: .flagsChanged(ModifierSnapshot()), timestamp: 12.01)
        #expect(!act2, "Hold of 2.01s must NOT activate")
        #expect(r2.state == .idle)
    }

    // SHORTCUT-T-05: Partial release then re-press -> one activate on final release
    @Test("Partial release and re-press preserves armed state")
    func testPartialReleaseAndRepress() {
        var recognizer = ChordRecognizer()
        let t0: TimeInterval = 50.0

        // Arm with all three down
        _ = recognizer.handle(
            event: .flagsChanged(ModifierSnapshot(function: true, control: true, option: true)),
            timestamp: t0
        )
        #expect(recognizer.state == .armed(t0: t0))

        // Release option while fn and ctrl remain down
        _ = recognizer.handle(
            event: .flagsChanged(ModifierSnapshot(function: true, control: true, option: false)),
            timestamp: t0 + 0.1
        )
        #expect(recognizer.state == .armed(t0: t0), "Should remain armed with original t0 on partial release")

        // Re-press option
        _ = recognizer.handle(
            event: .flagsChanged(ModifierSnapshot(function: true, control: true, option: true)),
            timestamp: t0 + 0.2
        )
        #expect(recognizer.state == .armed(t0: t0), "Should remain armed with original t0 on re-press")

        // Final release of all three
        let activated = recognizer.handle(event: .flagsChanged(ModifierSnapshot()), timestamp: t0 + 0.4)
        #expect(activated, "Should activate once on final full release")
    }

    // SHORTCUT-T-06: Function flag arriving with keyDown (arrow keys) never arms on its own
    @Test("Function flag arriving with keyDown never arms")
    func testFunctionFlagWithKeyDownNeverArms() {
        var recognizer = ChordRecognizer()
        // Arrow keys can trigger .function flag along with keyDown
        _ = recognizer.handle(event: .keyDown, timestamp: 10.0)
        #expect(recognizer.state == .idle)

        _ = recognizer.handle(
            event: .flagsChanged(ModifierSnapshot(function: true, control: false, option: false)),
            timestamp: 10.05
        )
        #expect(recognizer.state == .idle, "Lone function flag must not arm")
    }

    // SHORTCUT-T-07: Incomplete combinations -> no activate
    @Test("Incomplete combinations do not arm or activate")
    func testIncompleteCombinations() {
        var r1 = ChordRecognizer()
        _ = r1.handle(
            event: .flagsChanged(ModifierSnapshot(function: true, control: true, option: false)),
            timestamp: 1.0
        )
        #expect(r1.state == .idle)
        let act1 = r1.handle(event: .flagsChanged(ModifierSnapshot()), timestamp: 1.2)
        #expect(!act1)

        var r2 = ChordRecognizer()
        _ = r2.handle(
            event: .flagsChanged(ModifierSnapshot(function: false, control: true, option: true)),
            timestamp: 1.0
        )
        #expect(r2.state == .idle)
        let act2 = r2.handle(event: .flagsChanged(ModifierSnapshot()), timestamp: 1.2)
        #expect(!act2)
    }
}
