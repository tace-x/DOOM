import Foundation

@MainActor
public protocol ShortcutMonitoring: AnyObject {
    var events: AsyncStream<ShortcutEvent> { get }
    var status: ShortcutStatus { get }
    func start()
    func refreshAfterPermissionChange()
    func stop()
}
