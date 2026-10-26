import Foundation
#if canImport(Carbon)
import Carbon
#endif

public enum KeyCodeResolver {
    public static let fallbackKeyCodeH: UInt32 = 4 // kVK_ANSI_H
    public static let fallbackKeyCodeC: UInt32 = 8 // kVK_ANSI_C

    /// Pure resolution function over an injected mapping table (SHORTCUT-T-08)
    public static func resolveKeyCode(for targetChar: Character, using table: [UInt16: Character]) -> (keyCode: UInt32, didFallback: Bool) {
        let lowerTarget = Character(targetChar.lowercased())
        for (code, char) in table {
            if Character(char.lowercased()) == lowerTarget {
                return (UInt32(code), false)
            }
        }
        return (fallbackKeyCodeH, true)
    }

    #if canImport(Carbon)
    /// Resolves the virtual key code for target character in the current ASCII-capable keyboard layout.
    public static func currentKeyCode(for targetChar: Character, fallback: UInt32) -> (keyCode: UInt32, didFallback: Bool) {
        guard let inputSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return (fallback, true)
        }

        guard let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return (fallback, true)
        }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
        let lowerTarget = Character(targetChar.lowercased())

        return layoutData.withUnsafeBytes { rawBuffer -> (UInt32, Bool) in
            guard let headerPtr = rawBuffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return (fallback, true)
            }

            var deadKeyState: UInt32 = 0
            let maxStringLength = 4
            var actualStringLength = 0
            var unicodeString = [UniChar](repeating: 0, count: maxStringLength)

            // Scan standard macOS virtual key codes 0 through 127
            for keyCode: UInt16 in 0..<128 {
                let status = UCKeyTranslate(
                    headerPtr,
                    keyCode,
                    UInt16(kUCKeyActionDown),
                    0, // no modifiers
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    maxStringLength,
                    &actualStringLength,
                    &unicodeString
                )

                if status == noErr && actualStringLength > 0 {
                    let characterString = String(utf16CodeUnits: unicodeString, count: actualStringLength)
                    if let first = characterString.first, Character(first.lowercased()) == lowerTarget {
                        return (UInt32(keyCode), false)
                    }
                }
            }

            return (fallback, true)
        }
    }

    /// Resolves virtual key code for character "h" in the current ASCII-capable layout.
    public static func currentKeyCodeForH() -> (keyCode: UInt32, didFallback: Bool) {
        currentKeyCode(for: "h", fallback: fallbackKeyCodeH)
    }

    /// Resolves virtual key code for character "c" in the current ASCII-capable layout.
    public static func currentKeyCodeForC() -> (keyCode: UInt32, didFallback: Bool) {
        currentKeyCode(for: "c", fallback: fallbackKeyCodeC)
    }
    #endif
}
