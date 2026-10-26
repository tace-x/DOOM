import Testing
import Foundation
@testable import DoomServices

@Suite("KeyCodeResolverTests")
struct KeyCodeResolverTests {
    // SHORTCUT-T-08: "h" resolves to 4 on US table, to correct code on Dvorak table. Missing character -> fallback flag.
    @Test("Resolve 'h' on simulated US and Dvorak layout tables")
    func testResolveKeyCode() {
        // Simulated US QWERTY table: keycode 4 is 'h'
        let usTable: [UInt16: Character] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z"
        ]
        let (usCode, usFallback) = KeyCodeResolver.resolveKeyCode(for: "h", using: usTable)
        #expect(usCode == 4)
        #expect(!usFallback)

        // Simulated Dvorak table: 'h' is at keycode 44 (standard Mac virtual keycode for Dvorak H / QWERTY J)
        let dvorakTable: [UInt16: Character] = [
            4: "d", 44: "h", 38: "j"
        ]
        let (dvorakCode, dvorakFallback) = KeyCodeResolver.resolveKeyCode(for: "h", using: dvorakTable)
        #expect(dvorakCode == 44)
        #expect(!dvorakFallback)

        // Missing character table -> fallback to 4 and didFallback true
        let incompleteTable: [UInt16: Character] = [
            0: "a", 1: "b", 2: "c"
        ]
        let (fallbackCode, didFallback) = KeyCodeResolver.resolveKeyCode(for: "h", using: incompleteTable)
        #expect(fallbackCode == 4)
        #expect(didFallback)
    }

    #if canImport(Carbon)
    @Test("Current ASCII layout keycode resolution returns valid keycode")
    func testCurrentLayoutResolution() {
        let (keyCode, _) = KeyCodeResolver.currentKeyCodeForH()
        #expect(keyCode < 128)
    }
    #endif
}
