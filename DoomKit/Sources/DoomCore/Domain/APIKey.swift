import Foundation

public struct APIKey: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    private let rawValue: String

    public var description: String { "<redacted>" }
    public var debugDescription: String { "<redacted>" }

    public init?(validating key: String) {
        guard key.count >= 20 && key.count <= 256 else { return nil }
        guard !key.contains(where: { $0.isWhitespace }) else { return nil }
        guard key.allSatisfy({ char in
            guard let ascii = char.asciiValue else { return false }
            return ascii >= 33 && ascii <= 126
        }) else { return nil }
        self.rawValue = key
    }

    /// Access the raw key string. Strictly restricted to HTTP transport authorization headers.
    public func accessKey() -> String {
        rawValue
    }

    public static func == (lhs: APIKey, rhs: APIKey) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}
