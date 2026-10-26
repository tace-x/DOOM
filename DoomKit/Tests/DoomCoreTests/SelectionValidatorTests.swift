import Testing
import Foundation
@testable import DoomCore

@Suite("SelectionValidatorTests")
struct SelectionValidatorTests {
    let source = SourceApplication(localizedName: "TextEdit", bundleIdentifier: "com.apple.TextEdit")

    @Test("TEXT-T-01: Removes NUL characters from raw selection")
    func testNulRemoval() throws {
        let raw = "Hello\0, \0World!\0"
        let result = try SelectionValidator.validate(raw, source: source, method: .accessibility)
        #expect(result.value == "Hello, World!")
        #expect(result.characterCount == 13)
        #expect(result.method == .accessibility)
    }

    @Test("TEXT-T-02: Trims leading and trailing whitespace and newlines")
    func testTrimming() throws {
        let raw = "\n\t  Important instruction.   \r\n"
        let result = try SelectionValidator.validate(raw, source: source, method: .accessibility)
        #expect(result.value == "Important instruction.")
        #expect(result.characterCount == 22)
    }

    @Test("TEXT-T-03: Empty and whitespace-only selections throw emptySelection")
    func testEmptySelection() {
        #expect(throws: TextAcquisitionError.emptySelection) {
            try SelectionValidator.validate("", source: source, method: .accessibility)
        }
        #expect(throws: TextAcquisitionError.emptySelection) {
            try SelectionValidator.validate("   \n\t  \r\n", source: source, method: .accessibility)
        }
        #expect(throws: TextAcquisitionError.emptySelection) {
            try SelectionValidator.validate("\0\0\0", source: source, method: .accessibility)
        }
    }

    @Test("TEXT-T-04: Exactly 20,000 characters accepted")
    func testExact20000Limit() throws {
        let exactText = String(repeating: "a", count: 20_000)
        let result = try SelectionValidator.validate(exactText, source: source, method: .accessibility)
        #expect(result.characterCount == 20_000)
        #expect(result.value.count == 20_000)
    }

    @Test("TEXT-T-05: 20,001 characters throws tooLong without truncation")
    func testExceedsLimitThrowsTooLong() {
        let tooLongText = String(repeating: "x", count: 20_001)
        #expect(throws: TextAcquisitionError.tooLong(count: 20_001, limit: 20_000)) {
            try SelectionValidator.validate(tooLongText, source: source, method: .accessibility)
        }
    }

    @Test("TEXT-T-06: Multi-scalar graphemes counted as single characters")
    func testGraphemeClusterCounting() throws {
        // Flag emoji: 2 scalars, 1 grapheme
        // Combined technologist emoji: 5 scalars, 1 grapheme
        // Accented letter: 2 scalars ("e" + combining acute), 1 grapheme
        let text = "🇺🇸 👨🏽‍💻 e\u{0301}"
        let result = try SelectionValidator.validate(text, source: source, method: .accessibility)
        // "🇺🇸" (1) + " " (1) + "👨🏽‍💻" (1) + " " (1) + "é" (1) = 5 characters
        #expect(result.characterCount == 5)
        #expect(result.value == "🇺🇸 👨🏽‍💻 é")
    }
}
