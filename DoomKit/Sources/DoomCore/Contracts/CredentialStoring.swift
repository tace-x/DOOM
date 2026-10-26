import Foundation

public protocol CredentialStoring: Sendable {
    func hasAPIKey() async throws(CredentialStoreError) -> Bool
    func readAPIKey() async throws(CredentialStoreError) -> APIKey?
    func saveAPIKey(_ key: APIKey) async throws(CredentialStoreError)
    func deleteAPIKey() async throws(CredentialStoreError)
}
