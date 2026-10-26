import Foundation

public enum BlockReason: String, Equatable, Sendable {
    case safety
    case recitation
    case prohibitedContent = "prohibited_content"
    case spii
    case blocklist
    case language
    case other
}

public enum GenerationError: Error, Equatable, Sendable {
    case missingAPIKey
    case keychain(status: Int32)
    case offline
    case timedOut
    case transport(code: Int)
    case cancelled
    case badRequest(code: String?)
    case unavailableForAccount
    case invalidAPIKey
    case paymentRequired
    case permissionDenied
    case modelNotFound
    case rateLimited(retryAfter: Duration?)
    case quotaExceeded
    case server(status: Int, code: String?, message: String?)
    case blocked(reason: BlockReason)
    case emptyResponse
    case malformedResponse

    public static func server(status: Int) -> GenerationError {
        .server(status: status, code: nil, message: nil)
    }

    public static func == (lhs: GenerationError, rhs: GenerationError) -> Bool {
        switch (lhs, rhs) {
        case (.missingAPIKey, .missingAPIKey): return true
        case (.keychain(let a), .keychain(let b)): return a == b
        case (.offline, .offline): return true
        case (.timedOut, .timedOut): return true
        case (.transport(let a), .transport(let b)): return a == b
        case (.cancelled, .cancelled): return true
        case (.badRequest(let a), .badRequest(let b)): return a == b
        case (.unavailableForAccount, .unavailableForAccount): return true
        case (.invalidAPIKey, .invalidAPIKey): return true
        case (.paymentRequired, .paymentRequired): return true
        case (.permissionDenied, .permissionDenied): return true
        case (.modelNotFound, .modelNotFound): return true
        case (.rateLimited(let a), .rateLimited(let b)): return a == b
        case (.quotaExceeded, .quotaExceeded): return true
        case (.server(let s1, let c1, let m1), .server(let s2, let c2, let m2)):
            if s1 != s2 { return false }
            if let c1 = c1, let c2 = c2, c1 != c2 { return false }
            if let m1 = m1, let m2 = m2, m1 != m2 { return false }
            return true
        case (.blocked(let a), .blocked(let b)): return a == b
        case (.emptyResponse, .emptyResponse): return true
        case (.malformedResponse, .malformedResponse): return true
        default: return false
        }
    }
}
