import Foundation

public enum AcquisitionMethod: String, Equatable, Sendable {
    case accessibility
    case clipboard
}

public struct SelectedText: Equatable, Sendable {
    public let value: String
    public let characterCount: Int
    public let source: SourceApplication
    public let method: AcquisitionMethod
    public let restoreSkipped: Bool

    public init(
        value: String,
        characterCount: Int,
        source: SourceApplication,
        method: AcquisitionMethod,
        restoreSkipped: Bool = false
    ) {
        self.value = value
        self.characterCount = characterCount
        self.source = source
        self.method = method
        self.restoreSkipped = restoreSkipped
    }
}
