import Foundation

public struct ModelID: Equatable, Sendable, CustomStringConvertible {
    public static let `default` = ModelID(rawValue: "gemini-3.5-flash")

    public let rawValue: String

    public var description: String { rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init?(validating rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.validate(trimmed) else { return nil }
        self.rawValue = trimmed
    }

    public var isValid: Bool {
        Self.validate(rawValue)
    }

    public static func validate(_ string: String) -> Bool {
        // Regex: ^[a-z0-9][a-z0-9.\-]{0,63}$ per E-CFG-01 / MODULE_CONTRACTS §3.1
        guard string.count >= 1 && string.count <= 64 else { return false }
        guard let first = string.first, first.isASCII, (first.isLetter && first.isLowercase) || first.isNumber else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        return string.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
