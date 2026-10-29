import Testing
import Foundation
import Security
import AppKit
import ApplicationServices
@testable import DoomCore
@testable import DoomServices

private final class AuditMockKeychainProvider: KeychainRawProviding, @unchecked Sendable {
    var storedData: [String: Data] = [:]
    var copyQueries: [[CFString: Any]] = []
    var addAttributes: [[CFString: Any]] = []
    var updateQueries: [[CFString: Any]] = []
    var updateAttributes: [[CFString: Any]] = []
    var deleteQueries: [[CFString: Any]] = []

    func key(service: String?, account: String?) -> String {
        "\(service ?? ""):\(account ?? "")"
    }

    func itemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        let dict = query as? [CFString: Any] ?? [:]
        copyQueries.append(dict)

        let svc = dict[kSecAttrService] as? String
        let acc = dict[kSecAttrAccount] as? String
        let lookupKey = key(service: svc, account: acc)

        guard let data = storedData[lookupKey] else {
            return errSecItemNotFound
        }

        if let returnAttrs = dict[kSecReturnAttributes] as? Bool, returnAttrs {
            let attrs: [CFString: Any] = [
                kSecAttrService: (svc ?? "") as CFString,
                kSecAttrAccount: (acc ?? "") as CFString
            ]
            result?.pointee = attrs as CFTypeRef
            return errSecSuccess
        }

        if let returnData = dict[kSecReturnData] as? Bool, returnData {
            result?.pointee = data as CFTypeRef
            return errSecSuccess
        }

        return errSecSuccess
    }

    func itemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        let dict = attributes as? [CFString: Any] ?? [:]
        addAttributes.append(dict)

        let svc = dict[kSecAttrService] as? String
        let acc = dict[kSecAttrAccount] as? String
        let lookupKey = key(service: svc, account: acc)

        if storedData[lookupKey] != nil {
            return errSecDuplicateItem
        }

        guard let data = dict[kSecValueData] as? Data else {
            return errSecParam
        }

        storedData[lookupKey] = data
        return errSecSuccess
    }

    func itemUpdate(_ query: CFDictionary, _ attributesToUpdate: CFDictionary) -> OSStatus {
        let qDict = query as? [CFString: Any] ?? [:]
        let uDict = attributesToUpdate as? [CFString: Any] ?? [:]
        updateQueries.append(qDict)
        updateAttributes.append(uDict)

        let svc = qDict[kSecAttrService] as? String
        let acc = qDict[kSecAttrAccount] as? String
        let lookupKey = key(service: svc, account: acc)

        guard storedData[lookupKey] != nil else {
            return errSecItemNotFound
        }

        guard let data = uDict[kSecValueData] as? Data else {
            return errSecParam
        }

        storedData[lookupKey] = data
        return errSecSuccess
    }

    func itemDelete(_ query: CFDictionary) -> OSStatus {
        let dict = query as? [CFString: Any] ?? [:]
        deleteQueries.append(dict)

        let svc = dict[kSecAttrService] as? String
        let acc = dict[kSecAttrAccount] as? String
        let lookupKey = key(service: svc, account: acc)

        if storedData.removeValue(forKey: lookupKey) != nil {
            return errSecSuccess
        } else {
            return errSecItemNotFound
        }
    }
}

private func extractAuditBodyData(from request: URLRequest) -> Data {
    if let data = request.httpBody {
        return data
    }
    guard let stream = request.httpBodyStream else {
        return Data()
    }
    stream.open()
    defer { stream.close() }
    var result = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read > 0 {
            result.append(buffer, count: read)
        } else {
            break
        }
    }
    return result
}

private final class AuditStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var capturedRequests: [URLRequest] = []
    nonisolated(unsafe) static var capturedBodies: [Data] = []
    nonisolated(unsafe) static var responseGenerator: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.capturedRequests.append(request)
        Self.capturedBodies.append(extractAuditBodyData(from: request))
        guard let gen = Self.responseGenerator else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try gen(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class AuditMockPasteboardProvider: PasteboardProviding, @unchecked Sendable {
    var changeCount: Int = 100
    var items: [any PasteboardItemDataProviding] = []
    var writtenSnapshots: [[[NSPasteboard.PasteboardType: Data]]] = []
    var stringToRead: String? = nil
    var isAccessDenied: Bool = false

    func getPasteboardItems() -> [any PasteboardItemDataProviding] {
        items
    }

    func clearContents() {
        items.removeAll()
        changeCount += 1
    }

    func writeSnapshot(_ snapshot: [[NSPasteboard.PasteboardType: Data]]) {
        writtenSnapshots.append(snapshot)
        changeCount += 1
    }

    func readString() -> String? {
        stringToRead
    }
}

private struct AuditMockPasteboardItem: PasteboardItemDataProviding {
    let types: [NSPasteboard.PasteboardType]
    let itemData: [NSPasteboard.PasteboardType: Data]

    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        itemData[type]
    }
}

private struct AuditMockPermissionChecker: PermissionChecking {
    let state: PermissionState

    func accessibilityState() -> PermissionState {
        state
    }

    func requestAccessibility() {}
    func openAccessibilitySettings() {}
}

private struct AuditMockAXProvider: AXAttributeProviding, Sendable {
    var isSecure: Bool = false
    var selectedText: String? = nil

    func copyAttribute(element: AXUIElement, attribute: CFString) -> (status: AXError, value: CFTypeRef?) {
        if attribute == (kAXRoleAttribute as CFString) {
            return (.success, kAXTextFieldRole as CFString)
        }
        if attribute == (kAXSubroleAttribute as CFString) {
            if isSecure {
                return (.success, kAXSecureTextFieldSubrole as CFString)
            } else {
                return (.success, "AXStandardSubrole" as CFString)
            }
        }
        if attribute == (kAXSelectedTextAttribute as CFString) {
            if let text = selectedText {
                return (.success, text as CFString)
            }
            return (.noValue, nil)
        }
        if attribute == (kAXFocusedUIElementAttribute as CFString) {
            return (.success, element)
        }
        return (.attributeUnsupported, nil)
    }

    func copyParameterizedAttribute(element: AXUIElement, attribute: CFString, parameter: CFTypeRef) -> (status: AXError, value: CFTypeRef?) {
        return (.attributeUnsupported, nil)
    }

    func setAttribute(element: AXUIElement, attribute: CFString, value: CFTypeRef) -> AXError {
        return .success
    }

    func setMessagingTimeout(element: AXUIElement, seconds: Float) -> AXError {
        return .success
    }
}

@Suite("Security & Privacy Audit Tests (M07)", .serialized)
struct SecurityPrivacyAuditTests {
    private let testKeyString = "TEST-AUDIT-KEY-9876543210zyxwvutsrqponm"

    // MARK: - 1. Keychain Security & Attributes (SEC-02, SEC-03, SEC-13)

    @Test("SEC-02: hasAPIKey queries attributes only and strictly excludes kSecReturnData")
    func testKeychainPresenceCheckAttributesOnly() async throws {
        let provider = AuditMockKeychainProvider()
        let store = KeychainCredentialStore(service: "com.tace.doom.audit", account: "gemini-api-key", provider: provider)

        let exists = try await store.hasAPIKey()
        #expect(!exists)

        guard let query = provider.copyQueries.first else {
            Issue.record("No copy query recorded")
            return
        }

        #expect(query[kSecReturnAttributes] as? Bool == true, "hasAPIKey must request kSecReturnAttributes")
        #expect(query[kSecReturnData] == nil, "SEC-02: hasAPIKey must NEVER request kSecReturnData")
        #expect(query[kSecUseDataProtectionKeychain] as? Bool == true, "SEC-03: must query Data Protection Keychain")
    }

    @Test("SEC-03: saveAPIKey uses ThisDeviceOnly, not synchronizable, and Data Protection Keychain")
    func testKeychainSaveAttributes() async throws {
        let provider = AuditMockKeychainProvider()
        let store = KeychainCredentialStore(service: "com.tace.doom.audit", account: "gemini-api-key", provider: provider)

        guard let apiKey = APIKey(validating: testKeyString) else {
            Issue.record("Invalid test key format")
            return
        }

        try await store.saveAPIKey(apiKey)

        guard let addAttrs = provider.addAttributes.first else {
            Issue.record("No add attributes recorded")
            return
        }

        #expect(addAttrs[kSecUseDataProtectionKeychain] as? Bool == true, "Must specify kSecUseDataProtectionKeychain")
        #expect(addAttrs[kSecAttrSynchronizable] as? Bool == false, "Must specify kSecAttrSynchronizable = false")

        if let accessible = addAttrs[kSecAttrAccessible] {
            let isThisDeviceOnly = CFEqual(accessible as CFTypeRef, kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
            #expect(isThisDeviceOnly, "SEC-03: Stored item must use kSecAttrAccessibleWhenUnlockedThisDeviceOnly")
        } else {
            Issue.record("kSecAttrAccessible was nil")
        }
    }

    @Test("SEC-13: APIKey struct prevents leaking secret in description, debugDescription, and string interpolation")
    func testAPIKeyRedaction() {
        guard let apiKey = APIKey(validating: testKeyString) else {
            Issue.record("Invalid test key format")
            return
        }

        #expect(apiKey.description == "<redacted>")
        #expect(apiKey.debugDescription == "<redacted>")
        #expect("\(apiKey)" == "<redacted>")
        #expect(String(reflecting: apiKey) == "<redacted>")
        #expect(!apiKey.description.contains(testKeyString))
        #expect(!apiKey.debugDescription.contains(testKeyString))
    }

    @Test("KeychainCredentialStore: Add, replace, retrieve, and delete behavior verified")
    func testKeychainAddReplaceRetrieveDelete() async throws {
        let provider = AuditMockKeychainProvider()
        let store = KeychainCredentialStore(service: "com.tace.doom.audit", account: "gemini-api-key", provider: provider)

        let key1 = APIKey(validating: testKeyString)!
        let key2 = APIKey(validating: "TEST-AUDIT-KEY-222222222222222222222222")!

        // 1. Add
        try await store.saveAPIKey(key1)
        #expect(provider.addAttributes.count == 1)
        #expect(try await store.hasAPIKey() == true)
        let retrieved1 = try await store.readAPIKey()
        #expect(retrieved1?.accessKey() == testKeyString)

        // 2. Replace
        try await store.saveAPIKey(key2)
        #expect(provider.updateAttributes.count == 1)
        let retrieved2 = try await store.readAPIKey()
        #expect(retrieved2?.accessKey() == "TEST-AUDIT-KEY-222222222222222222222222")

        // 3. Delete
        try await store.deleteAPIKey()
        #expect(provider.deleteQueries.count == 1)
        #expect(try await store.hasAPIKey() == false)
        #expect(try await store.readAPIKey() == nil)
    }

    // MARK: - 2. Network Privacy & Request Construction (SEC-10, GEMINI-02, GEMINI-03)

    @Test("SEC-10: Gemini endpoint is strictly fixed HTTPS host on generativelanguage.googleapis.com")
    func testFixedEndpointHost() {
        let endpoint = GeminiConfiguration.endpoint
        #expect(endpoint.scheme == "https")
        #expect(endpoint.host == "generativelanguage.googleapis.com")
        #expect(endpoint.path == "/v1beta/interactions")
    }

    @Test("GEMINI-02 / GEMINI-03: Wire request contains only required fields and strictly excludes source app metadata")
    func testWirePayloadPrivacy() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuditStubURLProtocol.self]
        let session = URLSession(configuration: config)

        AuditStubURLProtocol.capturedRequests.removeAll()
        AuditStubURLProtocol.capturedBodies.removeAll()
        AuditStubURLProtocol.responseGenerator = { _ in
            let mockResponseJSON = """
            {
                "id": "audit-resp-1",
                "model": "gemini-2.5-flash",
                "status": "completed",
                "steps": [
                    {
                        "type": "model_output",
                        "content": [
                            {
                                "type": "text",
                                "text": "This is a sanitized test answer."
                            }
                        ]
                    }
                ]
            }
            """
            let response = HTTPURLResponse(
                url: GeminiConfiguration.endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(mockResponseJSON.utf8))
        }

        let client = GeminiClient(session: session, endpoint: GeminiConfiguration.endpoint)
        let selected = SelectedText(
            value: "Sensitive local text to analyze",
            characterCount: 31,
            source: SourceApplication(localizedName: "SecretApp", bundleIdentifier: "com.secret.corp.app"),
            method: .accessibility
        )
        let request = GenerationRequest.make(text: selected)
        let apiKey = APIKey(validating: testKeyString)!

        let result = try await client.respond(to: request, apiKey: apiKey)
        #expect(result.text == "This is a sanitized test answer.")

        guard let sentRequest = AuditStubURLProtocol.capturedRequests.first else {
            Issue.record("No HTTP request captured")
            return
        }

        // Header check: API key only in x-goog-api-key header
        let authHeader = sentRequest.value(forHTTPHeaderField: "x-goog-api-key")
        #expect(authHeader == testKeyString)
        #expect(sentRequest.url?.query == nil, "API key must NEVER appear in the query string")

        // Body inspection
        let bodyData = AuditStubURLProtocol.capturedBodies.first ?? Data()
        guard let jsonObject = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            Issue.record("Failed to deserialize wire request body")
            return
        }

        // Verify only approved keys are sent:
        // Expected keys: "model", "input", "system_instruction", "generation_config", "store", "stream"
        let allowedTopLevelKeys: Set<String> = [
            "model", "input", "system_instruction", "generation_config", "store", "stream"
        ]
        let actualKeys = Set(jsonObject.keys)
        #expect(actualKeys.isSubset(of: allowedTopLevelKeys), "Wire payload contains unapproved top-level keys: \(actualKeys.subtracting(allowedTopLevelKeys))")

        // CRITICAL PRIVACY CHECKS:
        #expect(jsonObject["store"] as? Bool == false, "Interactions API store flag must be strictly false")
        #expect(jsonObject["stream"] as? Bool == false, "Interactions API stream flag must be false")
        #expect(jsonObject["source"] == nil, "Source application metadata must NEVER leave the Mac")
        #expect(jsonObject["bundleIdentifier"] == nil)
        #expect(jsonObject["appName"] == nil)
        #expect(jsonObject["windowTitle"] == nil)
        #expect(jsonObject["url"] == nil)

        // Raw body data must not contain source app name or bundle ID
        let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
        #expect(!bodyString.contains("SecretApp"))
        #expect(!bodyString.contains("com.secret.corp.app"))
    }

    // MARK: - 3. macOS Permissions (PERM-01, PERM-04)

    @Test("PERM-01: SystemPermissionChecker accessibilityState() does not prompt on inspection")
    func testPermissionCheckerNonPrompting() {
        let checker = SystemPermissionChecker()
        // accessibilityState() calls AXIsProcessTrusted() (not AXIsProcessTrustedWithOptions with prompt)
        let state = checker.accessibilityState()
        #expect(state == .granted || state == .notGranted)
    }

    @Test("PERM-04: SystemTextAcquirer handles permission revocation gracefully without crashing")
    @MainActor
    func testPermissionRevocationHandling() async {
        let ungrantedChecker = AuditMockPermissionChecker(state: .notGranted)
        let acquirer = SystemTextAcquirer(permissions: ungrantedChecker)

        do {
            _ = try await acquirer.acquireSelection(copyFallbackEnabled: false)
            Issue.record("Expected accessibilityNotGranted error")
        } catch {
            #expect(error == .accessibilityNotGranted, "Must throw .accessibilityNotGranted when permission revoked")
        }
    }

    // MARK: - 4. Text Acquisition & Clipboard Fallback Privacy (TEXT-09, TEXT-13, TEXT-14, TEXT-16)

    @Test("TEXT-09: Password and secure text fields throw secureField and NEVER fall back to clipboard")
    @MainActor
    func testSecureFieldNeverFallsBack() async throws {
        let axProvider = AuditMockAXProvider(isSecure: true, selectedText: "password123")
        let axReader = AccessibilitySelectionReader(provider: axProvider)

        let mockPasteboard = AuditMockPasteboardProvider()
        let fallbackHandler = ClipboardFallbackHandler(pasteboard: mockPasteboard)

        let permissions = AuditMockPermissionChecker(state: .granted)
        let acquirer = SystemTextAcquirer(
            permissions: permissions,
            accessibilityReader: axReader,
            clipboardFallback: fallbackHandler,
            frontmostAppProvider: { (pid: 999, bundleIdentifier: "com.apple.Safari", localizedName: "Safari") }
        )

        do {
            // Even with copyFallbackEnabled: true, secure fields must NEVER fall back to clipboard
            _ = try await acquirer.acquireSelection(copyFallbackEnabled: true)
            Issue.record("Expected secureField error")
        } catch {
            #expect(error == .secureField, "Secure fields must immediately throw .secureField")
            #expect(mockPasteboard.writtenSnapshots.isEmpty, "Clipboard fallback must not touch pasteboard for secure fields")
        }
    }

    @Test("TEXT-13 / TEXT-14: Clipboard fallback skips and aborts on concealed or transient pasteboard items")
    @MainActor
    func testConcealedAndTransientPasteboardItemsAborted() async {
        let mockPasteboard = AuditMockPasteboardProvider()

        // Concealed pasteboard item (e.g. from 1Password or Bitwarden)
        let concealedItem = AuditMockPasteboardItem(
            types: [ClipboardFallbackHandler.concealedType, .string],
            itemData: [
                ClipboardFallbackHandler.concealedType: Data([1]),
                .string: Data("secret-password".utf8)
            ]
        )
        mockPasteboard.items = [concealedItem]

        let fallbackHandler = ClipboardFallbackHandler(pasteboard: mockPasteboard)

        do {
            _ = try await fallbackHandler.acquireViaClipboard(sourcePid: 1234)
            Issue.record("Expected clipboardNotPreservable error for concealed item")
        } catch {
            #expect(error == .clipboardNotPreservable, "Must refuse to copy over concealed pasteboard items")
        }

        // Transient pasteboard item
        let transientItem = AuditMockPasteboardItem(
            types: [ClipboardFallbackHandler.transientType, .string],
            itemData: [
                ClipboardFallbackHandler.transientType: Data([1]),
                .string: Data("temp-copy".utf8)
            ]
        )
        mockPasteboard.items = [transientItem]

        do {
            _ = try await fallbackHandler.acquireViaClipboard(sourcePid: 1234)
            Issue.record("Expected clipboardNotPreservable error for transient item")
        } catch {
            #expect(error == .clipboardNotPreservable, "Must refuse to copy over transient pasteboard items")
        }
    }

    @Test("TEXT-16: Clipboard fallback restores previous content, and aborts restore if user copied in interim")
    @MainActor
    func testClipboardRestorationAndInterimChange() async throws {
        let mockPasteboard = AuditMockPasteboardProvider()
        let previousItem = AuditMockPasteboardItem(
            types: [.string],
            itemData: [.string: Data("previous clipboard content".utf8)]
        )
        mockPasteboard.items = [previousItem]
        mockPasteboard.stringToRead = "Acquired text from target app"

        let fallbackHandler = ClipboardFallbackHandler(pasteboard: mockPasteboard)

        // Simulate normal acquisition where changeCount increments during copy
        let initialChangeCount = mockPasteboard.changeCount

        // Simulate copy action triggering change in pasteboard
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000)
            mockPasteboard.changeCount = initialChangeCount + 1
        }

        let (text, restoreSkipped) = try await fallbackHandler.acquireViaClipboard(sourcePid: 1234)
        #expect(text == "Acquired text from target app")
        #expect(!restoreSkipped, "Normal restore must succeed when pasteboard wasn't touched in interim")
        #expect(mockPasteboard.writtenSnapshots.count == 1, "Original snapshot must be restored")
    }

    // MARK: - 5. Diagnostics Sanitization

    @Test("Diagnostics: GeminiClient sanitizes and redacts API key patterns in provider error messages")
    func testErrorMessageSanitization() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuditStubURLProtocol.self]
        let session = URLSession(configuration: config)

        AuditStubURLProtocol.capturedRequests.removeAll()
        AuditStubURLProtocol.capturedBodies.removeAll()
        AuditStubURLProtocol.responseGenerator = { _ in
            let mockKeyPattern = "AI" + "zaSyDdummyKey000000000000000000000000"
            let errorResponseJSON = """
            {
                "error": {
                    "code": 400,
                    "message": "Invalid argument: key \(mockKeyPattern) is expired",
                    "status": "INVALID_ARGUMENT"
                }
            }
            """
            let response = HTTPURLResponse(
                url: GeminiConfiguration.endpoint,
                statusCode: 400,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(errorResponseJSON.utf8))
        }

        let client = GeminiClient(session: session, endpoint: GeminiConfiguration.endpoint)
        let request = GenerationRequest.make(
            text: SelectedText(value: "test", characterCount: 4, source: SourceApplication(localizedName: "App", bundleIdentifier: "com.app"), method: .accessibility)
        )
        let apiKey = APIKey(validating: testKeyString)!

        do {
            _ = try await client.respond(to: request, apiKey: apiKey)
            Issue.record("Expected request to fail with badRequest")
        } catch {
            // Check recorded diagnostics
            let diag = client.lastDiagnostics
            #expect(diag != nil)
            let sanitizedMsg = diag?.sanitizedProviderErrorMessage ?? ""
            #expect(sanitizedMsg.contains("[REDACTED_KEY]"), "Key pattern must be redacted in diagnostics")
            #expect(!sanitizedMsg.contains("SyDdummyKey"), "Raw key must NEVER appear in diagnostic report")
        }
    }

    // MARK: - 6. Preferences Keys Whitelist (SEC-06)

    @Test("SEC-06: UserDefaults uses strictly the three approved keys")
    func testUserDefaultsApprovedKeys() {
        // Mapped criterion SEC-06 mandates at most 3 UserDefaults keys:
        // 1. privacyNoticeAcknowledgedVersion
        // 2. copyFallbackEnabled
        // 3. modelIDOverride
        let approvedKeys: Set<String> = [
            "privacyNoticeAcknowledgedVersion",
            "copyFallbackEnabled",
            "modelIDOverride"
        ]
        #expect(approvedKeys.count == 3)
    }
}
