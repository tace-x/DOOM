import Foundation
import OSLog

public enum LogCategory: String, Sendable {
    case lifecycle
    case configuration
}

extension Logger {
    public init(category: LogCategory, configuration: AppConfiguration) {
        self.init(subsystem: configuration.bundleIdentifier, category: category.rawValue)
    }
}
