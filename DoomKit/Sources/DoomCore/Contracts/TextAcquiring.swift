import Foundation

@MainActor
public protocol TextAcquiring: AnyObject {
    func acquireSelection(copyFallbackEnabled: Bool) async throws(TextAcquisitionError) -> SelectedText
}
