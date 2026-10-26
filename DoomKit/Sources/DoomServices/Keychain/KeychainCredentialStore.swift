import Foundation
import Security
import DoomCore
import OSLog

private let logger = Logger(subsystem: "com.tace.doom", category: "keychain")

public protocol KeychainRawProviding: Sendable {
    func itemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    func itemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    func itemUpdate(_ query: CFDictionary, _ attributesToUpdate: CFDictionary) -> OSStatus
    func itemDelete(_ query: CFDictionary) -> OSStatus
}

public struct SystemKeychainRawProvider: KeychainRawProviding {
    public init() {}

    public func itemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        SecItemCopyMatching(query, result)
    }

    public func itemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        SecItemAdd(attributes, result)
    }

    public func itemUpdate(_ query: CFDictionary, _ attributesToUpdate: CFDictionary) -> OSStatus {
        SecItemUpdate(query, attributesToUpdate)
    }

    public func itemDelete(_ query: CFDictionary) -> OSStatus {
        SecItemDelete(query)
    }
}

public final class KeychainCredentialStore: CredentialStoring, Sendable {
    public let service: String
    public let account: String
    private let provider: any KeychainRawProviding

    public init(
        service: String = Bundle.main.bundleIdentifier ?? "com.tace.doom",
        account: String = "gemini-api-key",
        provider: any KeychainRawProviding = SystemKeychainRawProvider()
    ) {
        self.service = service
        self.account = account
        self.provider = provider
    }

    public func hasAPIKey() async throws(CredentialStoreError) -> Bool {
        // SEC-02: Query attributes only, NEVER kSecReturnData
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service as CFString,
            kSecAttrAccount: account as CFString,
            kSecUseDataProtectionKeychain: kCFBooleanTrue as Any,
            kSecReturnAttributes: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        var status = provider.itemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return true
        }

        // If not found in Data Protection Keychain or Data Protection is unentitled (-34018),
        // query the standard macOS Keychain.
        if status == errSecItemNotFound || status == errSecMissingEntitlement {
            query.removeValue(forKey: kSecUseDataProtectionKeychain)
            status = provider.itemCopyMatching(query as CFDictionary, &result)
            if status == errSecSuccess {
                return true
            } else if status == errSecItemNotFound {
                return false
            }
        }

        if status == errSecAuthFailed || status == errSecInteractionNotAllowed {
            logger.error("Keychain presence check access denied (\(status))")
            throw CredentialStoreError.accessDenied
        } else if status == errSecMissingEntitlement { // -34018
            logger.error("Keychain access failed: missing entitlement (-34018)")
            throw CredentialStoreError.keychainUnavailable
        } else {
            logger.error("Keychain presence check unexpected status: \(status)")
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    public func readAPIKey() async throws(CredentialStoreError) -> APIKey? {
        // Secret read: only performed immediately before making a request
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service as CFString,
            kSecAttrAccount: account as CFString,
            kSecUseDataProtectionKeychain: kCFBooleanTrue as Any,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        var status = provider.itemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound || status == errSecMissingEntitlement {
            query.removeValue(forKey: kSecUseDataProtectionKeychain)
            status = provider.itemCopyMatching(query as CFDictionary, &result)
        }

        if status == errSecItemNotFound {
            return nil
        } else if status == errSecAuthFailed || status == errSecInteractionNotAllowed {
            logger.error("Keychain read access denied (\(status))")
            throw CredentialStoreError.accessDenied
        } else if status == errSecMissingEntitlement {
            logger.error("Keychain access failed: missing entitlement (-34018)")
            throw CredentialStoreError.keychainUnavailable
        } else if status != errSecSuccess {
            logger.error("Keychain read unexpected status: \(status)")
            throw CredentialStoreError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let apiKey = APIKey(validating: string) else {
            logger.error("Stored API key format invalid in Keychain")
            throw CredentialStoreError.invalidKeyFormat
        }

        return apiKey
    }

    public func saveAPIKey(_ key: APIKey) async throws(CredentialStoreError) {
        let keyData = Data(key.accessKey().utf8)

        let exists = try await hasAPIKey()
        var status: OSStatus = errSecSuccess

        if exists {
            var updateQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service as CFString,
                kSecAttrAccount: account as CFString,
                kSecUseDataProtectionKeychain: kCFBooleanTrue as Any
            ]
            let attributesToUpdate: [CFString: Any] = [
                kSecValueData: keyData
            ]

            status = provider.itemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
            if status == errSecMissingEntitlement || status == errSecItemNotFound {
                updateQuery.removeValue(forKey: kSecUseDataProtectionKeychain)
                status = provider.itemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
            }
            if status == errSecItemNotFound || status == errSecAuthFailed || status == errSecInteractionNotAllowed {
                // If update returned not found or access denied due to old ACL, delete and re-add cleanly
                _ = try? await deleteAPIKey()
                status = try performAdd(keyData: keyData)
            }
        } else {
            status = try performAdd(keyData: keyData)
            if status == errSecDuplicateItem {
                // Duplicate item encountered on insertion; update the existing item instead of blindly retrying
                var updateQuery: [CFString: Any] = [
                    kSecClass: kSecClassGenericPassword,
                    kSecAttrService: service as CFString,
                    kSecAttrAccount: account as CFString,
                    kSecUseDataProtectionKeychain: kCFBooleanTrue as Any
                ]
                let attributesToUpdate: [CFString: Any] = [
                    kSecValueData: keyData
                ]
                status = provider.itemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
                if status == errSecMissingEntitlement || status == errSecItemNotFound {
                    updateQuery.removeValue(forKey: kSecUseDataProtectionKeychain)
                    status = provider.itemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
                }
            }
        }

        if status == errSecSuccess {
            logger.notice("Successfully saved API key in Keychain")
            return
        } else if status == errSecAuthFailed || status == errSecInteractionNotAllowed {
            logger.error("Keychain save access denied (\(status))")
            throw CredentialStoreError.accessDenied
        } else if status == errSecMissingEntitlement {
            logger.error("Keychain save failed: missing entitlement (-34018)")
            throw CredentialStoreError.keychainUnavailable
        } else {
            logger.error("Keychain save failed with status: \(status)")
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    private func performAdd(keyData: Data) throws(CredentialStoreError) -> OSStatus {
        var addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service as CFString,
            kSecAttrAccount: account as CFString,
            kSecValueData: keyData,
            kSecUseDataProtectionKeychain: kCFBooleanTrue as Any,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable: kCFBooleanFalse as Any
        ]

        var status = provider.itemAdd(addQuery as CFDictionary, nil)
        if status == errSecMissingEntitlement {
            addQuery.removeValue(forKey: kSecUseDataProtectionKeychain)
            status = provider.itemAdd(addQuery as CFDictionary, nil)
        }
        return status
    }

    public func deleteAPIKey() async throws(CredentialStoreError) {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service as CFString,
            kSecAttrAccount: account as CFString,
            kSecUseDataProtectionKeychain: kCFBooleanTrue as Any
        ]

        var status = provider.itemDelete(query as CFDictionary)
        if status == errSecMissingEntitlement || status == errSecItemNotFound {
            query.removeValue(forKey: kSecUseDataProtectionKeychain)
            let fallbackStatus = provider.itemDelete(query as CFDictionary)
            if fallbackStatus == errSecSuccess {
                status = errSecSuccess
            } else if status == errSecMissingEntitlement {
                status = fallbackStatus
            }
        }

        if status == errSecSuccess || status == errSecItemNotFound {
            logger.notice("Successfully removed API key from Keychain (or item absent)")
            return
        } else if status == errSecAuthFailed || status == errSecInteractionNotAllowed {
            logger.error("Keychain delete access denied (\(status))")
            throw CredentialStoreError.accessDenied
        } else if status == errSecMissingEntitlement {
            logger.error("Keychain delete failed: missing entitlement (-34018)")
            throw CredentialStoreError.keychainUnavailable
        } else {
            logger.error("Keychain delete failed with status: \(status)")
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }
}
