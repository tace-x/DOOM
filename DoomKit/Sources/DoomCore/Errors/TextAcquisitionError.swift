import Foundation

public enum TextAcquisitionError: Error, Equatable, Sendable {
    case accessibilityNotGranted
    case noSourceApplication
    case ownApplication
    case secureField
    case emptySelection
    case unsupported(reason: String)
    case tooLong(count: Int, limit: Int)
    case timedOut
    case clipboardAccessDenied
    case clipboardNotPreservable
    case clipboardCopyFailed
    case notText
    case cancelled
}
