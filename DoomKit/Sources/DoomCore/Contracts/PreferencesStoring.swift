import Foundation

public protocol PreferencesStoring: Sendable {
    var privacyNoticeAcknowledgedVersion: Int { get nonmutating set }
    var copyFallbackEnabled: Bool { get nonmutating set }
    var modelIDOverride: String? { get nonmutating set }
}
