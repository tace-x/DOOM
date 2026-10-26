import Foundation
import ApplicationServices
import DoomCore
import OSLog

private let logger = Logger(subsystem: "com.tace.doom", category: "selection")

public protocol AXAttributeProviding: Sendable {
    func copyAttribute(element: AXUIElement, attribute: CFString) -> (status: AXError, value: CFTypeRef?)
    func copyParameterizedAttribute(element: AXUIElement, attribute: CFString, parameter: CFTypeRef) -> (status: AXError, value: CFTypeRef?)
    func setAttribute(element: AXUIElement, attribute: CFString, value: CFTypeRef) -> AXError
    func setMessagingTimeout(element: AXUIElement, seconds: Float) -> AXError
}

public struct SystemAXAttributeProvider: AXAttributeProviding {
    public init() {}

    public func copyAttribute(element: AXUIElement, attribute: CFString) -> (status: AXError, value: CFTypeRef?) {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        return (status, value)
    }

    public func copyParameterizedAttribute(element: AXUIElement, attribute: CFString, parameter: CFTypeRef) -> (status: AXError, value: CFTypeRef?) {
        var value: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(element, attribute, parameter, &value)
        return (status, value)
    }

    public func setAttribute(element: AXUIElement, attribute: CFString, value: CFTypeRef) -> AXError {
        return AXUIElementSetAttributeValue(element, attribute, value)
    }

    public func setMessagingTimeout(element: AXUIElement, seconds: Float) -> AXError {
        return AXUIElementSetMessagingTimeout(element, seconds)
    }
}

public protocol AccessibilitySelectionReading: Sendable {
    func readSelectedText(from sourcePid: pid_t, bundleIdentifier: String?) async throws(TextAcquisitionError) -> String
}

public final class AccessibilitySelectionReader: AccessibilitySelectionReading, @unchecked Sendable {
    private let provider: any AXAttributeProviding
    private let queue = DispatchQueue(label: "com.tace.doom.accessibility")

    public static let chromiumFamily: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "com.google.Chrome.canary",
        "org.chromium.Chromium",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Beta",
        "com.microsoft.edgemac.Dev",
        "com.microsoft.edgemac.Canary",
        "com.brave.Browser",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "company.thebrowser.Browser"
    ]

    public init(provider: any AXAttributeProviding = SystemAXAttributeProvider()) {
        self.provider = provider
    }

    public func readSelectedText(from sourcePid: pid_t, bundleIdentifier: String?) async throws(TextAcquisitionError) -> String {
        do {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                queue.async {
                    do {
                        let text = try self.performRead(pid: sourcePid, bundleIdentifier: bundleIdentifier)
                        continuation.resume(returning: text)
                    } catch let error as TextAcquisitionError {
                        continuation.resume(throwing: error)
                    } catch {
                        continuation.resume(throwing: TextAcquisitionError.unsupported(reason: "unexpected"))
                    }
                }
            }
        } catch let error as TextAcquisitionError {
            throw error
        } catch {
            throw TextAcquisitionError.unsupported(reason: "unexpected")
        }
    }

    private func performRead(pid: pid_t, bundleIdentifier: String?) throws(TextAcquisitionError) -> String {
        let appEl = AXUIElementCreateApplication(pid)
        _ = provider.setMessagingTimeout(element: appEl, seconds: 1.0)

        let isChromium = bundleIdentifier.map { Self.chromiumFamily.contains($0) } ?? false
        if isChromium {
            try ensureChromiumWebAccessibility(appEl: appEl)
        }

        var focusedElement: AXUIElement?
        do {
            focusedElement = try copyFocusedElement(appEl: appEl)
        } catch {
            throw error
        }

        if focusedElement == nil && !isChromium {
            // Electron best-effort retry: set AXManualAccessibility = true once and poll up to 1.0s
            let manualAttr = "AXManualAccessibility" as CFString
            _ = provider.setAttribute(element: appEl, attribute: manualAttr, value: kCFBooleanTrue)
            for _ in 0..<10 {
                Thread.sleep(forTimeInterval: 0.1)
                if let el = try copyFocusedElement(appEl: appEl) {
                    focusedElement = el
                    break
                }
            }
        }

        guard let focused = focusedElement else {
            throw TextAcquisitionError.unsupported(reason: "noFocusedElement")
        }

        _ = provider.setMessagingTimeout(element: focused, seconds: 1.0)

        // Step 6: Secure check (never read password fields)
        if try isSecureField(focused) {
            throw TextAcquisitionError.secureField
        }

        // Step 7: Strategy A (kAXSelectedTextAttribute)
        if let text = try strategyA(focused: focused) {
            return text
        }

        // Step 8: Strategy B (kAXSelectedTextRangeAttribute)
        if let text = try strategyB(focused: focused) {
            return text
        }

        // Step 9: Strategy C (web content: AXSelectedTextMarkerRange)
        if let text = try strategyC(focused: focused) {
            return text
        }

        // Step 10: Exhausted without definitive empty
        throw TextAcquisitionError.unsupported(reason: "attributesUnsupported")
    }

    private func copyFocusedElement(appEl: AXUIElement) throws(TextAcquisitionError) -> AXUIElement? {
        let (status, value) = provider.copyAttribute(element: appEl, attribute: kAXFocusedUIElementAttribute as CFString)
        if status == .cannotComplete {
            throw TextAcquisitionError.timedOut
        }
        if status == .success, let val = value {
            return (val as! AXUIElement)
        }
        return nil
    }

    private func ensureChromiumWebAccessibility(appEl: AXUIElement) throws(TextAcquisitionError) {
        let enhancedAttr = "AXEnhancedUserInterface" as CFString
        let (copyStatus, copyVal) = provider.copyAttribute(element: appEl, attribute: enhancedAttr)
        if copyStatus == .cannotComplete {
            throw TextAcquisitionError.timedOut
        }

        let isAlreadyEnhanced = (copyStatus == .success) && ((copyVal as? Bool) == true || (copyVal as? Int) == 1)
        if !isAlreadyEnhanced {
            _ = provider.setAttribute(element: appEl, attribute: enhancedAttr, value: kCFBooleanTrue)

            // Retry step 5 every 100ms for up to 2.5s until a focused element appears
            for _ in 0..<25 {
                Thread.sleep(forTimeInterval: 0.1)
                if (try copyFocusedElement(appEl: appEl)) != nil {
                    break
                }
            }
        }
    }

    private func isSecureField(_ element: AXUIElement) throws(TextAcquisitionError) -> Bool {
        let (roleStatus, roleVal) = provider.copyAttribute(element: element, attribute: kAXRoleAttribute as CFString)
        if roleStatus == .cannotComplete {
            throw TextAcquisitionError.timedOut
        }
        let (subroleStatus, subroleVal) = provider.copyAttribute(element: element, attribute: kAXSubroleAttribute as CFString)
        if subroleStatus == .cannotComplete {
            throw TextAcquisitionError.timedOut
        }

        let role = (roleStatus == .success) ? (roleVal as? String) : nil
        let subrole = (subroleStatus == .success) ? (subroleVal as? String) : nil

        return role == (kAXTextFieldRole as String) && subrole == (kAXSecureTextFieldSubrole as String)
    }

    // MARK: - Strategy A

    private func strategyA(focused: AXUIElement) throws(TextAcquisitionError) -> String? {
        let (status, val) = provider.copyAttribute(element: focused, attribute: kAXSelectedTextAttribute as CFString)
        if status == .cannotComplete {
            throw TextAcquisitionError.timedOut
        }
        if status == .success, let str = val as? String {
            if !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return str
            }
        }
        return nil
    }

    // MARK: - Strategy B

    private func strategyB(focused: AXUIElement) throws(TextAcquisitionError) -> String? {
        let (status, val) = provider.copyAttribute(element: focused, attribute: kAXSelectedTextRangeAttribute as CFString)
        if status == .cannotComplete {
            throw TextAcquisitionError.timedOut
        }
        guard status == .success, let axVal = val else { return nil }

        var range = CFRange(location: 0, length: 0)
        guard CFGetTypeID(axVal) == AXValueGetTypeID() else { return nil }
        let axValue = axVal as! AXValue
        guard AXValueGetType(axValue) == .cfRange, AXValueGetValue(axValue, .cfRange, &range) else { return nil }

        if range.length == 0 {
            // Definitive empty (caret only!) -> throw .emptySelection without fallback
            throw TextAcquisitionError.emptySelection
        }

        // Range > 0: copyParameterized
        let (paramStatus, paramVal) = provider.copyParameterizedAttribute(
            element: focused,
            attribute: kAXStringForRangeParameterizedAttribute as CFString,
            parameter: axValue
        )
        if paramStatus == .cannotComplete {
            throw TextAcquisitionError.timedOut
        }

        if paramStatus == .success, let str = paramVal as? String {
            if !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return str
            }
        }

        return nil
    }

    // MARK: - Strategy C

    private func strategyC(focused: AXUIElement) throws(TextAcquisitionError) -> String? {
        var candidates: [AXUIElement] = [focused]

        // Find nearest ancestor with role "AXWebArea" (up to 8 hops)
        var current = focused
        for _ in 0..<8 {
            let (parentStatus, parentVal) = provider.copyAttribute(element: current, attribute: kAXParentAttribute as CFString)
            if parentStatus == .cannotComplete {
                throw TextAcquisitionError.timedOut
            }
            guard parentStatus == .success, let parent = parentVal else { break }
            let parentEl = (parent as! AXUIElement)

            let (roleStatus, roleVal) = provider.copyAttribute(element: parentEl, attribute: kAXRoleAttribute as CFString)
            if roleStatus == .cannotComplete {
                throw TextAcquisitionError.timedOut
            }
            if roleStatus == .success, let roleStr = roleVal as? String, roleStr == "AXWebArea" {
                candidates.append(parentEl)
                break
            }
            current = parentEl
        }

        let markerRangeAttr = "AXSelectedTextMarkerRange" as CFString
        let stringForMarkerAttr = "AXStringForTextMarkerRange" as CFString

        for candidate in candidates {
            let (status, markerVal) = provider.copyAttribute(element: candidate, attribute: markerRangeAttr)
            if status == .cannotComplete {
                throw TextAcquisitionError.timedOut
            }
            guard status == .success, let marker = markerVal else { continue }

            let (strStatus, strVal) = provider.copyParameterizedAttribute(
                element: candidate,
                attribute: stringForMarkerAttr,
                parameter: marker
            )
            if strStatus == .cannotComplete {
                throw TextAcquisitionError.timedOut
            }

            if strStatus == .success, let str = strVal as? String {
                if !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return str
                } else {
                    // Marker range present but string is empty/whitespace -> definitive empty
                    throw TextAcquisitionError.emptySelection
                }
            }
        }

        return nil
    }
}
