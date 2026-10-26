import Testing
import Foundation
@testable import DoomCore

@Suite("APIKey Tests")
struct APIKeyTests {
    @Test("Valid 39-character key passes validation")
    func validKey() {
        let raw = "TEST-KEY-1234567890abcdefghijklmnopqrst"
        let key = APIKey(validating: raw)
        #expect(key != nil)
        #expect(key?.accessKey() == raw)
    }

    @Test("Key shorter than 20 characters is rejected")
    func tooShortKey() {
        let raw = "1234567890123456789" // 19 chars
        #expect(APIKey(validating: raw) == nil)
    }

    @Test("Key longer than 256 characters is rejected")
    func tooLongKey() {
        let raw = String(repeating: "a", count: 257)
        #expect(APIKey(validating: raw) == nil)
    }

    @Test("Key with whitespace, tabs, or newlines is rejected")
    func whitespaceKey() {
        #expect(APIKey(validating: "TEST-KEY 1234567890abcdefghijklmnopq") == nil)
        #expect(APIKey(validating: "TEST-KEY\t1234567890abcdefghijklmnopq") == nil)
        #expect(APIKey(validating: "TEST-KEY\n1234567890abcdefghijklmnopq") == nil)
        #expect(APIKey(validating: " TEST-KEY-1234567890abcdefghijklmnopq") == nil)
        #expect(APIKey(validating: "TEST-KEY-1234567890abcdefghijklmnopq ") == nil)
    }

    @Test("Key with non-ASCII characters is rejected")
    func nonASCIIKey() {
        let raw = "TEST-KEY-1234567890abcdefghijklmn💡"
        #expect(APIKey(validating: raw) == nil)
    }

    @Test("Description and debugDescription redact secret value")
    func redaction() {
        let raw = "TEST-KEY-1234567890abcdefghijklmnopqrst"
        guard let key = APIKey(validating: raw) else {
            Issue.record("Failed to create key")
            return
        }
        let desc = String(describing: key)
        let debugDesc = String(reflecting: key)
        #expect(!desc.contains(raw))
        #expect(!debugDesc.contains(raw))
        #expect(desc.contains("redacted"))
        #expect(debugDesc.contains("redacted"))
    }
}
