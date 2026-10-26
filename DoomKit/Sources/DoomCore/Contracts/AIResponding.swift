import Foundation

public protocol AIResponding: Sendable {
    func respond(to request: GenerationRequest, apiKey: APIKey) async throws(GenerationError) -> GenerationResult
}
