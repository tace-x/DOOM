import Foundation

public enum ConfigurationError: Error, Equatable, Sendable {
    case missingValue(key: String)
    case invalidValue(key: String, reason: Reason)

    public enum Reason: String, Sendable {
        case notReverseDNS
        case notVersionFormat
        case notBuildFormat
    }

    public var key: String {
        switch self {
        case .missingValue(let key):
            return key
        case .invalidValue(let key, _):
            return key
        }
    }
}
