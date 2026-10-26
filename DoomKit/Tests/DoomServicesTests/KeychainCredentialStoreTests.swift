import Testing
import Foundation
import Security
@testable import DoomCore
@testable import DoomServices

private final class MockKeychainRawProvider: KeychainRawProviding, @unchecked Sendable {
    var storedData: [String: Data] = [:]
    var copyCount: Int = 0
    var addCount: Int = 0
    var updateCount: Int = 0
    var deleteCount: Int = 0

    var lastCopyQuery: [CFString: Any]?
    var lastAddAttributes: [CFString: Any]?
    var lastUpdateQuery: [CFString: Any]?
    var lastUpdateAttributes: [CFString: Any]?

    var copyStatusOverride: OSStatus?
    var addStatusOverride: OSStatus?
    var updateStatusOverride: OSStatus?
    var deleteStatusOverride: OSStatus?

    func key(service: String?, account: String?) -> String {
        "\(service ?? ""):\(account ?? "")"
    }

    func itemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        copyCount += 1
        let dict = query as? [CFString: Any] ?? [:]
        lastCopyQuery = dict

        if let override = copyStatusOverride {
            return override
        }

        let svc = dict[kSecAttrService] as? String
        let acc = dict[kSecAttrAccount] as? String
        let lookupKey = key(service: svc, account: acc)

        guard let data = storedData[lookupKey] else {
            return errSecItemNotFound
        }

        if let returnAttrs = dict[kSecReturnAttributes] as? Bool, returnAttrs {
            // SEC-02: Returns attributes only, NO data
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
        addCount += 1
        let dict = attributes as? [CFString: Any] ?? [:]
        lastAddAttributes = dict

        if let override = addStatusOverride {
            return override
        }

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
        updateCount += 1
        let qDict = query as? [CFString: Any] ?? [:]
        let uDict = attributesToUpdate as? [CFString: Any] ?? [:]
        lastUpdateQuery = qDict
        lastUpdateAttributes = uDict

        if let override = updateStatusOverride {
            return override
        }

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
        deleteCount += 1
        let dict = query as? [CFString: Any] ?? [:]

        if let override = deleteStatusOverride {
            return override
        }

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

@Suite("KeychainCredentialStore Tests")
struct KeychainCredentialStoreTests {
    private let testKeyString = "TEST-KEY-1234567890abcdefghijklmnopqrst"

    @Test("Save and read credential succeeds")
    func saveAndRead() async throws {
        let provider = MockKeychainRawProvider()
        let store = KeychainCredentialStore(service: "com.tace.doom.test", account: "gemini-api-key", provider: provider)

        guard let apiKey = APIKey(validating: testKeyString) else {
            Issue.record("Failed to create valid APIKey")
            return
        }

        // Initially no key
        let initialPresence = try await store.hasAPIKey()
        #expect(!initialPresence)
        let initialRead = try await store.readAPIKey()
        #expect(initialRead == nil)

        // Save key
        try await store.saveAPIKey(apiKey)
        #expect(provider.addCount == 1)

        // Check presence
        let presence = try await store.hasAPIKey()
        #expect(presence)

        // Read key
        let readKey = try await store.readAPIKey()
        #expect(readKey?.accessKey() == testKeyString)
    }

    @Test("SEC-02: hasAPIKey queries attributes only and NEVER requests data")
    func presenceCheckAttributesOnly() async throws {
        let provider = MockKeychainRawProvider()
        let store = KeychainCredentialStore(service: "com.tace.doom.test", account: "gemini-api-key", provider: provider)

        _ = try await store.hasAPIKey()

        let query = provider.lastCopyQuery
        #expect(query != nil)
        #expect(query?[kSecReturnAttributes] as? Bool == true)
        #expect(query?[kSecReturnData] == nil)
    }

    @Test("SEC-03: Stored item uses data protection keychain and ThisDeviceOnly accessibility")
    func accessibilityAndDataProtectionAttributes() async throws {
        let provider = MockKeychainRawProvider()
        let store = KeychainCredentialStore(service: "com.tace.doom.test", account: "gemini-api-key", provider: provider)

        guard let apiKey = APIKey(validating: testKeyString) else {
            Issue.record("Failed to create valid APIKey")
            return
        }

        try await store.saveAPIKey(apiKey)

        let addAttrs = provider.lastAddAttributes
        #expect(addAttrs != nil)
        #expect(addAttrs?[kSecUseDataProtectionKeychain] as? Bool == true)
        if let accessible = addAttrs?[kSecAttrAccessible] {
            let matches = CFEqual(accessible as CFTypeRef, kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
            #expect(matches)
        } else {
            Issue.record("kSecAttrAccessible was nil")
        }
        #expect(addAttrs?[kSecAttrSynchronizable] as? Bool == false)
    }

    @Test("Replace existing credential updates existing item")
    func replaceCredential() async throws {
        let provider = MockKeychainRawProvider()
        let store = KeychainCredentialStore(service: "com.tace.doom.test", account: "gemini-api-key", provider: provider)

        let key1 = APIKey(validating: testKeyString)!
        let newKeyString = "TEST-KEY-9876543210zyxwvutsrqponmlkjihgfedcba"
        let key2 = APIKey(validating: newKeyString)!

        try await store.saveAPIKey(key1)
        #expect(provider.addCount == 1)
        #expect(provider.updateCount == 0)

        try await store.saveAPIKey(key2)
        #expect(provider.updateCount == 1)

        let read = try await store.readAPIKey()
        #expect(read?.accessKey() == newKeyString)
    }

    @Test("Delete credential removes item from Keychain")
    func deleteCredential() async throws {
        let provider = MockKeychainRawProvider()
        let store = KeychainCredentialStore(service: "com.tace.doom.test", account: "gemini-api-key", provider: provider)

        let key = APIKey(validating: testKeyString)!
        try await store.saveAPIKey(key)
        #expect(try await store.hasAPIKey())

        try await store.deleteAPIKey()
        #expect(provider.deleteCount == 1)
        #expect(try await store.hasAPIKey() == false)
        #expect(try await store.readAPIKey() == nil)

        // Deleting when absent succeeds cleanly
        try await store.deleteAPIKey()
    }

    @Test("Keychain -34018 error maps to keychainUnavailable")
    func missingEntitlementMapping() async {
        let provider = MockKeychainRawProvider()
        provider.copyStatusOverride = errSecMissingEntitlement // -34018
        let store = KeychainCredentialStore(service: "com.tace.doom.test", account: "gemini-api-key", provider: provider)

        do {
            _ = try await store.hasAPIKey()
            Issue.record("Expected keychainUnavailable error")
        } catch {
            #expect(error == .keychainUnavailable)
        }
    }

    @Test("Invalid key format in Keychain throws invalidKeyFormat")
    func invalidKeyFormatMapping() async {
        let provider = MockKeychainRawProvider()
        let lookupKey = provider.key(service: "com.tace.doom.test", account: "gemini-api-key")
        provider.storedData[lookupKey] = Data("too short".utf8)

        let store = KeychainCredentialStore(service: "com.tace.doom.test", account: "gemini-api-key", provider: provider)

        do {
            _ = try await store.readAPIKey()
            Issue.record("Expected invalidKeyFormat error")
        } catch {
            #expect(error == .invalidKeyFormat)
        }
    }

    @Test("Handling duplicate item on add updates existing item without retrying blindly")
    func duplicateItemHandling() async throws {
        let provider = MockKeychainRawProvider()
        let store = KeychainCredentialStore(service: "com.tace.doom.test", account: "gemini-api-key", provider: provider)

        let initialKey = APIKey(validating: testKeyString)!
        let updatedKeyString = "TEST-KEY-88888888888888888888888888888888888"
        let updatedKey = APIKey(validating: updatedKeyString)!

        // Simulate pre-existing item in Keychain that wasn't detected by a stale check
        let lookupKey = provider.key(service: "com.tace.doom.test", account: "gemini-api-key")
        provider.storedData[lookupKey] = Data(initialKey.accessKey().utf8)

        // Force hasAPIKey to simulate returning false (item not found initially)
        provider.copyStatusOverride = errSecItemNotFound

        try await store.saveAPIKey(updatedKey)

        #expect(provider.addCount == 1)
        #expect(provider.updateCount == 1)

        // Clear copy override to read back the value
        provider.copyStatusOverride = nil
        let readKey = try await store.readAPIKey()
        #expect(readKey?.accessKey() == updatedKeyString)
    }

    @Test("Keychain access denial maps to accessDenied error")
    func accessDenialMapping() async {
        let provider = MockKeychainRawProvider()
        provider.copyStatusOverride = errSecAuthFailed // -25293
        let store = KeychainCredentialStore(service: "com.tace.doom.test", account: "gemini-api-key", provider: provider)

        do {
            _ = try await store.hasAPIKey()
            Issue.record("Expected accessDenied error")
        } catch {
            #expect(error == .accessDenied)
        }

        provider.copyStatusOverride = nil
        provider.addStatusOverride = errSecInteractionNotAllowed // -25308
        let key = APIKey(validating: testKeyString)!
        do {
            try await store.saveAPIKey(key)
            Issue.record("Expected accessDenied error on add")
        } catch {
            #expect(error == .accessDenied)
        }
    }

    @Test("Unexpected Keychain status maps to unexpectedStatus error")
    func unexpectedStatusMapping() async {
        let provider = MockKeychainRawProvider()
        provider.copyStatusOverride = errSecParam // -50
        let store = KeychainCredentialStore(service: "com.tace.doom.test", account: "gemini-api-key", provider: provider)

        do {
            _ = try await store.hasAPIKey()
            Issue.record("Expected unexpectedStatus error")
        } catch {
            #expect(error == .unexpectedStatus(errSecParam))
        }
    }

    @Test("Credentials are never logged or written to disk")
    func credentialsNotLoggedOrWrittenToDisk() async throws {
        let key = APIKey(validating: testKeyString)!
        #expect(key.description == "<redacted>")
        #expect(key.debugDescription == "<redacted>")

        let provider = MockKeychainRawProvider()
        let store = KeychainCredentialStore(service: "com.tace.doom.test", account: "gemini-api-key", provider: provider)
        try await store.saveAPIKey(key)

        // Ensure hasAPIKey never requests kSecReturnData
        _ = try await store.hasAPIKey()
        let copyQuery = provider.lastCopyQuery
        #expect(copyQuery?[kSecReturnData] == nil)
        #expect(copyQuery?[kSecReturnAttributes] as? Bool == true)
    }

    @Test("Real System Keychain operations: save, read, replace, delete")
    func systemKeychainRealOperations() async throws {
        let realStore = KeychainCredentialStore(
            service: "com.tace.doom.unit-test-system",
            account: "gemini-api-key",
            provider: SystemKeychainRawProvider()
        )

        let testKey1 = APIKey(validating: testKeyString)!
        let testKey2 = APIKey(validating: "TEST-KEY-77777777777777777777777777777777777")!

        // Clean initial state
        try await realStore.deleteAPIKey()
        #expect(try await realStore.hasAPIKey() == false)
        #expect(try await realStore.readAPIKey() == nil)

        // 1. Save new key
        try await realStore.saveAPIKey(testKey1)
        #expect(try await realStore.hasAPIKey() == true)
        let readKey1 = try await realStore.readAPIKey()
        #expect(readKey1?.accessKey() == testKeyString)

        // 2. Replace existing key
        try await realStore.saveAPIKey(testKey2)
        #expect(try await realStore.hasAPIKey() == true)
        let readKey2 = try await realStore.readAPIKey()
        #expect(readKey2?.accessKey() == "TEST-KEY-77777777777777777777777777777777777")

        // 3. Delete key
        try await realStore.deleteAPIKey()
        #expect(try await realStore.hasAPIKey() == false)
        #expect(try await realStore.readAPIKey() == nil)
    }
}
