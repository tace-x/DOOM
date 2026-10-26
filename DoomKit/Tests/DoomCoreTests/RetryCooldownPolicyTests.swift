import Testing
import Foundation
@testable import DoomCore

@Suite("RetryCooldownPolicy Tests")
struct RetryCooldownPolicyTests {

    @Test("GEMINI-26: First retryable failure has 0s cooldown")
    func firstFailureZeroCooldown() {
        let cd = RetryCooldownPolicy.cooldown(for: .server(status: 500), failureCount: 1)
        #expect(cd == 0)
    }

    @Test("GEMINI-26: Consecutive retryable failures follow sequence 2, 4, 8, 16, 30 with jitter bounds")
    func sequenceAndJitterBounds() {
        // Test base sequence without jitter (factor = 1.0)
        #expect(RetryCooldownPolicy.computeCooldown(failureCount: 1, randomFactor: 1.0) == 0)
        #expect(RetryCooldownPolicy.computeCooldown(failureCount: 2, randomFactor: 1.0) == 2)
        #expect(RetryCooldownPolicy.computeCooldown(failureCount: 3, randomFactor: 1.0) == 4)
        #expect(RetryCooldownPolicy.computeCooldown(failureCount: 4, randomFactor: 1.0) == 8)
        #expect(RetryCooldownPolicy.computeCooldown(failureCount: 5, randomFactor: 1.0) == 16)
        #expect(RetryCooldownPolicy.computeCooldown(failureCount: 6, randomFactor: 1.0) == 30)
        #expect(RetryCooldownPolicy.computeCooldown(failureCount: 7, randomFactor: 1.0) == 30)

        // Test jitter bounds (±20%): min factor 0.8, max factor 1.2
        for count in 2...6 {
            let minVal = RetryCooldownPolicy.computeCooldown(failureCount: count, randomFactor: 0.8)
            let maxVal = RetryCooldownPolicy.computeCooldown(failureCount: count, randomFactor: 1.2)
            let defaultVal = RetryCooldownPolicy.computeCooldown(failureCount: count)

            #expect(defaultVal >= minVal)
            #expect(defaultVal <= maxVal)
        }
    }

    @Test("GEMINI-15: Rate limited cooldown uses Retry-After or defaults to 10s without jitter")
    func rateLimitedCooldown() {
        // Without header -> 10s
        let cdDefault = RetryCooldownPolicy.cooldown(for: .rateLimited(retryAfter: nil), failureCount: 1)
        #expect(cdDefault == 10)

        // With header (e.g. 25s) -> 25s
        let cdCustom = RetryCooldownPolicy.cooldown(for: .rateLimited(retryAfter: .seconds(25)), failureCount: 1)
        #expect(cdCustom == 25)

        // Clamping to [1, 60]
        let cdLow = RetryCooldownPolicy.cooldown(for: .rateLimited(retryAfter: .seconds(0)), failureCount: 1)
        #expect(cdLow == 1)

        let cdHigh = RetryCooldownPolicy.cooldown(for: .rateLimited(retryAfter: .seconds(120)), failureCount: 1)
        #expect(cdHigh == 60)
    }

    @Test("Non-retryable errors return nil cooldown")
    func nonRetryableErrors() {
        #expect(RetryCooldownPolicy.cooldown(for: .invalidAPIKey, failureCount: 1) == nil)
        #expect(RetryCooldownPolicy.cooldown(for: .permissionDenied, failureCount: 1) == nil)
        #expect(RetryCooldownPolicy.cooldown(for: .modelNotFound, failureCount: 1) == nil)
        #expect(RetryCooldownPolicy.cooldown(for: .quotaExceeded, failureCount: 1) == nil)
        #expect(RetryCooldownPolicy.cooldown(for: .unavailableForAccount, failureCount: 1) == nil)
        #expect(RetryCooldownPolicy.cooldown(for: .badRequest(code: "invalid"), failureCount: 1) == nil)
        #expect(RetryCooldownPolicy.cooldown(for: .blocked(reason: .safety), failureCount: 1) == nil)
    }
}
