import Foundation

public struct SourceApplication: Equatable, Sendable {
    public let localizedName: String?
    public let bundleIdentifier: String?

    public init(localizedName: String?, bundleIdentifier: String?) {
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
    }
}
