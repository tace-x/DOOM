import Foundation

public struct RetryCooldownPolicy: Sendable {
    /// Computes the cooldown duration in seconds for a sequence of consecutive retryable failures.
    /// - Parameters:
    ///   - failureCount: Consecutive failures on the same captured text (1-indexed).
    ///   - randomFactor: Jitter factor in [0.8, 1.2], default random.
    /// - Returns: Cooldown duration in seconds.
    public static func computeCooldown(failureCount: Int, randomFactor: Double = Double.random(in: 0.8...1.2)) -> Int {
        guard failureCount > 1 else { return 0 }
        let base: Double
        switch failureCount {
        case 2: base = 2
        case 3: base = 4
        case 4: base = 8
        case 5: base = 16
        default: base = 30
        }
        let clampedFactor = max(0.8, min(1.2, randomFactor))
        let jittered = base * clampedFactor
        return max(1, Int(jittered.rounded()))
    }

    /// Determines the cooldown before the manual [Retry] button is enabled.
    /// - Parameters:
    ///   - error: The generation error encountered.
    ///   - failureCount: Consecutive failures on the same captured text (1-indexed).
    ///   - randomFactor: Jitter factor for computed cooldowns.
    /// - Returns: Number of seconds if retryable, nil if error is non-retryable.
    public static func cooldown(
        for error: GenerationError,
        failureCount: Int,
        randomFactor: Double = Double.random(in: 0.8...1.2)
    ) -> Int? {
        switch error {
        case .rateLimited(let retryAfter):
            if let duration = retryAfter {
                let seconds = Int(duration.components.seconds)
                return max(1, min(60, seconds))
            }
            return 10
        case .server, .timedOut, .transport, .offline, .emptyResponse, .malformedResponse:
            return computeCooldown(failureCount: failureCount, randomFactor: randomFactor)
        default:
            return nil
        }
    }
}
