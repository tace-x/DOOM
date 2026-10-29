import Testing
import Foundation
import DoomCore
@testable import DoomServices

private let isLiveGeminiEnabled = ProcessInfo.processInfo.environment["DOOM_LIVE_GEMINI_TESTS"] == "1"

@Suite("GeminiLiveTests", .enabled(if: isLiveGeminiEnabled, "Live Gemini tests are skipped unless DOOM_LIVE_GEMINI_TESTS=1"))
struct GeminiLiveTests {

    @Test("GEMINI-INT-01 & GEMINI-27: Live request with default model succeeds or verifies API availability")
    func testLiveDefaultModel() async throws {
        guard let keyString = ProcessInfo.processInfo.environment["DOOM_GEMINI_TEST_API_KEY"],
              let apiKey = APIKey(validating: keyString) else {
            Issue.record("DOOM_GEMINI_TEST_API_KEY is not set or invalid for live test execution")
            return
        }

        let client = GeminiClient()
        let selection = SelectedText(
            value: "Explain photosynthesis in one sentence.",
            characterCount: 39,
            source: SourceApplication(localizedName: "TextEdit", bundleIdentifier: "com.apple.TextEdit"),
            method: .accessibility
        )
        let request = GenerationRequest.make(text: selection, model: ModelID.default)

        do {
            let result = try await client.respond(to: request, apiKey: apiKey)
            #expect(!result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } catch {
            Issue.record("Live request failed: \(error)")
        }
    }

    @Test("GEMINI-INT-02: Deliberately invalid key maps to invalidAPIKey (401/400)")
    func testLiveInvalidKey() async throws {
        let client = GeminiClient()
        let selection = SelectedText(
            value: "Hello world",
            characterCount: 11,
            source: SourceApplication(localizedName: "TextEdit", bundleIdentifier: "com.apple.TextEdit"),
            method: .accessibility
        )
        let request = GenerationRequest.make(text: selection, model: ModelID.default)
        let invalidKey = APIKey(validating: "AI" + "zaSy" + String(repeating: "0", count: 33))!

        do {
            _ = try await client.respond(to: request, apiKey: invalidKey)
            Issue.record("Expected request with invalid key to fail, but it succeeded")
        } catch let err {
            #expect(err == .invalidAPIKey, "Expected invalidAPIKey error, got: \(err)")
        }
    }

    @Test("GEMINI-INT-03: Non-existent model ID maps to modelNotFound (404)")
    func testLiveNonExistentModel() async throws {
        guard let keyString = ProcessInfo.processInfo.environment["DOOM_GEMINI_TEST_API_KEY"],
              let apiKey = APIKey(validating: keyString) else {
            // Need a valid key to reach 404 model not found (otherwise invalid key 400/401 takes precedence)
            return
        }

        let client = GeminiClient()
        let selection = SelectedText(
            value: "Hello world",
            characterCount: 11,
            source: SourceApplication(localizedName: "TextEdit", bundleIdentifier: "com.apple.TextEdit"),
            method: .accessibility
        )
        let nonExistentModel = ModelID(validating: "non-existent-gemini-model-xyz-999")!
        let request = GenerationRequest.make(text: selection, model: nonExistentModel)

        do {
            _ = try await client.respond(to: request, apiKey: apiKey)
            Issue.record("Expected request with non-existent model to fail")
        } catch let err {
            #expect(err == .modelNotFound, "Expected modelNotFound error, got: \(err)")
        }
    }

    @Test("GEMINI-INT-04: Cancellation 50ms after start cancels task cleanly without crash")
    func testLiveCancellation() async throws {
        guard let keyString = ProcessInfo.processInfo.environment["DOOM_GEMINI_TEST_API_KEY"],
              let apiKey = APIKey(validating: keyString) else {
            return
        }

        let client = GeminiClient()
        let selection = SelectedText(
            value: "Please write a comprehensive history of computing in 500 words.",
            characterCount: 63,
            source: SourceApplication(localizedName: "TextEdit", bundleIdentifier: "com.apple.TextEdit"),
            method: .accessibility
        )
        let request = GenerationRequest.make(text: selection, model: ModelID.default)

        let task = Task { () -> GenerationResult in
            try await client.respond(to: request, apiKey: apiKey)
        }

        try await Task.sleep(nanoseconds: 50_000_000) // 50 ms
        task.cancel()

        let outcome = await task.result
        switch outcome {
        case .success:
            // Network returned before cancellation; acceptable
            break
        case .failure(let err):
            if let genErr = err as? GenerationError {
                switch genErr {
                case .cancelled, .transport:
                    #expect(true)
                default:
                    Issue.record("Expected .cancelled or .transport, got \(genErr)")
                }
            }
        }
    }
}
