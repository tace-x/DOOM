import Foundation

public enum PermissionState: Equatable, Sendable {
    case granted
    case notGranted
    case grantedNeedsRestart
}
