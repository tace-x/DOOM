import Testing
import Foundation
import ApplicationServices
import DoomCore
@testable import DoomServices

private final class ScriptedAXAttributeProvider: AXAttributeProviding, @unchecked Sendable {
    var attributeResponses: [String: (AXError, CFTypeRef?)] = [:]
    var paramResponses: [String: (AXError, CFTypeRef?)] = [:]
    var settableAttributes: [String: Bool] = [:]
    var timeoutCalls: [Float] = []

    func copyAttribute(element: AXUIElement, attribute: CFString) -> (status: AXError, value: CFTypeRef?) {
        let key = attribute as String
        if let resp = attributeResponses[key] {
            return resp
        }
        return (.noValue, nil)
    }

    func copyParameterizedAttribute(element: AXUIElement, attribute: CFString, parameter: CFTypeRef) -> (status: AXError, value: CFTypeRef?) {
        let key = attribute as String
        if let resp = paramResponses[key] {
            return resp
        }
        return (.noValue, nil)
    }

    func setAttribute(element: AXUIElement, attribute: CFString, value: CFTypeRef) -> AXError {
        return .success
    }

    func setMessagingTimeout(element: AXUIElement, seconds: Float) -> AXError {
        timeoutCalls.append(seconds)
        return .success
    }
}

@Suite("AccessibilitySelectionReaderTests")
struct AccessibilitySelectionReaderTests {
    @Test("TEXT-T-07 Strategy A: Selected text attribute succeeds immediately")
    func testStrategyASuccess() async throws {
        let provider = ScriptedAXAttributeProvider()
        let fakeElement = AXUIElementCreateApplication(1234)

        provider.attributeResponses[kAXFocusedUIElementAttribute as String] = (.success, fakeElement)
        provider.attributeResponses[kAXRoleAttribute as String] = (.success, "AXTextArea" as CFString)
        provider.attributeResponses[kAXSelectedTextAttribute as String] = (.success, "Direct selection via Strategy A" as CFString)

        let reader = AccessibilitySelectionReader(provider: provider)
        let text = try await reader.readSelectedText(from: 1234, bundleIdentifier: "com.example.app")
        #expect(text == "Direct selection via Strategy A")
    }

    @Test("TEXT-T-07 Strategy B: Range length 0 throws emptySelection (no fallback)")
    func testStrategyBDefinitiveEmpty() async {
        let provider = ScriptedAXAttributeProvider()
        let fakeElement = AXUIElementCreateApplication(1234)

        provider.attributeResponses[kAXFocusedUIElementAttribute as String] = (.success, fakeElement)
        provider.attributeResponses[kAXRoleAttribute as String] = (.success, "AXTextArea" as CFString)
        provider.attributeResponses[kAXSelectedTextAttribute as String] = (.noValue, nil)

        var zeroRange = CFRange(location: 42, length: 0)
        let axValue = AXValueCreate(.cfRange, &zeroRange)!
        provider.attributeResponses[kAXSelectedTextRangeAttribute as String] = (.success, axValue)

        let reader = AccessibilitySelectionReader(provider: provider)
        await #expect(throws: TextAcquisitionError.emptySelection) {
            try await reader.readSelectedText(from: 1234, bundleIdentifier: "com.example.app")
        }
    }

    @Test("TEXT-T-07 Strategy B: Range length > 0 returns parameterized string")
    func testStrategyBParamSuccess() async throws {
        let provider = ScriptedAXAttributeProvider()
        let fakeElement = AXUIElementCreateApplication(1234)

        provider.attributeResponses[kAXFocusedUIElementAttribute as String] = (.success, fakeElement)
        provider.attributeResponses[kAXRoleAttribute as String] = (.success, "AXTextArea" as CFString)
        provider.attributeResponses[kAXSelectedTextAttribute as String] = (.noValue, nil)

        var range = CFRange(location: 0, length: 15)
        let axValue = AXValueCreate(.cfRange, &range)!
        provider.attributeResponses[kAXSelectedTextRangeAttribute as String] = (.success, axValue)
        provider.paramResponses[kAXStringForRangeParameterizedAttribute as String] = (.success, "Strategy B text" as CFString)

        let reader = AccessibilitySelectionReader(provider: provider)
        let text = try await reader.readSelectedText(from: 1234, bundleIdentifier: "com.example.app")
        #expect(text == "Strategy B text")
    }

    @Test("TEXT-T-07 Strategy C: Web text markers return webpage selection")
    func testStrategyCWebMarkers() async throws {
        let provider = ScriptedAXAttributeProvider()
        let fakeElement = AXUIElementCreateApplication(1234)

        provider.attributeResponses[kAXFocusedUIElementAttribute as String] = (.success, fakeElement)
        provider.attributeResponses[kAXRoleAttribute as String] = (.success, "AXWebArea" as CFString)
        provider.attributeResponses[kAXSelectedTextAttribute as String] = (.noValue, nil)
        provider.attributeResponses[kAXSelectedTextRangeAttribute as String] = (.noValue, nil)

        // Web marker range present
        let fakeMarker = "MarkerRangeRef" as CFString
        provider.attributeResponses["AXSelectedTextMarkerRange"] = (.success, fakeMarker)
        provider.paramResponses["AXStringForTextMarkerRange"] = (.success, "Captured web page paragraph" as CFString)

        let reader = AccessibilitySelectionReader(provider: provider)
        let text = try await reader.readSelectedText(from: 1234, bundleIdentifier: "com.google.Chrome")
        #expect(text == "Captured web page paragraph")
    }

    @Test("Password field throws secureField immediately")
    func testSecureFieldGuarded() async {
        let provider = ScriptedAXAttributeProvider()
        let fakeElement = AXUIElementCreateApplication(1234)

        provider.attributeResponses[kAXFocusedUIElementAttribute as String] = (.success, fakeElement)
        provider.attributeResponses[kAXRoleAttribute as String] = (.success, kAXTextFieldRole as CFString)
        provider.attributeResponses[kAXSubroleAttribute as String] = (.success, kAXSecureTextFieldSubrole as CFString)

        // Even if selected text attribute has a value, it must never be read
        provider.attributeResponses[kAXSelectedTextAttribute as String] = (.success, "SuperSecret123" as CFString)

        let reader = AccessibilitySelectionReader(provider: provider)
        await #expect(throws: TextAcquisitionError.secureField) {
            try await reader.readSelectedText(from: 1234, bundleIdentifier: "com.apple.Safari")
        }
    }

    @Test("Missing focused element throws unsupported noFocusedElement")
    func testMissingFocusedElement() async {
        let provider = ScriptedAXAttributeProvider()
        provider.attributeResponses[kAXFocusedUIElementAttribute as String] = (.noValue, nil)

        let reader = AccessibilitySelectionReader(provider: provider)
        await #expect(throws: TextAcquisitionError.unsupported(reason: "noFocusedElement")) {
            try await reader.readSelectedText(from: 1234, bundleIdentifier: "com.example.app")
        }
    }

    @Test("TEXT-T-09: Unresponsive app returning cannotComplete throws timedOut")
    func testCannotCompleteThrowsTimedOut() async {
        let provider = ScriptedAXAttributeProvider()
        let fakeElement = AXUIElementCreateApplication(1234)

        provider.attributeResponses[kAXFocusedUIElementAttribute as String] = (.success, fakeElement)
        provider.attributeResponses[kAXRoleAttribute as String] = (.cannotComplete, nil)

        let reader = AccessibilitySelectionReader(provider: provider)
        await #expect(throws: TextAcquisitionError.timedOut) {
            try await reader.readSelectedText(from: 1234, bundleIdentifier: "com.example.app")
        }
    }
}
