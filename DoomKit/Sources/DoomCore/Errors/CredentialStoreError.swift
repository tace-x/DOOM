import Foundation

public enum CredentialStoreError: Error, Equatable, Sendable {
    case keychainUnavailable
    case invalidKeyFormat
    case accessDenied
    case unexpectedStatus(Int32)
}
