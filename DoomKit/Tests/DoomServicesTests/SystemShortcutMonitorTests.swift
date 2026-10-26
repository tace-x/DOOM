import Testing
import Foundation
import DoomCore
@testable import DoomServices

private final class MutableFakePermissionChecker: PermissionChecking, @unchecked Sendable {
    var trusted: Bool

    init(trusted: Bool) {
        self.trusted = trusted
    }

    func accessibilityState() -> PermissionState {
        trusted ? .granted : .notGranted
    }

    @MainActor func requestAccessibility() {}
    @MainActor func openAccessibilitySettings() {}
}

@Suite("SystemShortcutMonitorTests", .serialized)
struct SystemShortcutMonitorTests {
    @Test("Status reflects initial permission state")
    @MainActor
    func testInitialStatus() {
        let untrustedChecker = MutableFakePermissionChecker(trusted: false)
        let monitorUntrusted = SystemShortcutMonitor(permissions: untrustedChecker)
        #expect(monitorUntrusted.status.activation == .needsAccessibility)

        let trustedChecker = MutableFakePermissionChecker(trusted: true)
        let monitorTrusted = SystemShortcutMonitor(permissions: trustedChecker)
        #expect(monitorTrusted.status.activation == .active)
    }

    @Test("Stop finishes event stream cleanly")
    @MainActor
    func testStopFinishesStream() async {
        let checker = MutableFakePermissionChecker(trusted: true)
        let monitor = SystemShortcutMonitor(permissions: checker)
        monitor.start()

        let task = Task {
            var eventCount = 0
            for await _ in monitor.events {
                eventCount += 1
            }
            return eventCount
        }

        monitor.stop()
        let count = await task.value
        #expect(count == 0)
    }

    @Test("Refresh after permission transition updates status")
    @MainActor
    func testRefreshAfterPermissionChange() {
        let checker = MutableFakePermissionChecker(trusted: false)
        let monitor = SystemShortcutMonitor(permissions: checker)
        monitor.start()
        #expect(monitor.status.activation == .needsAccessibility)

        checker.trusted = true
        monitor.refreshAfterPermissionChange()
        #expect(monitor.status.activation == .active)

        monitor.stop()
    }

    @Test("Start and stop are idempotent")
    @MainActor
    func testIdempotentStartStop() {
        let checker = MutableFakePermissionChecker(trusted: true)
        let monitor = SystemShortcutMonitor(permissions: checker)

        // Multiple starts
        monitor.start()
        monitor.start()
        #expect(monitor.status.panelToggle == .available)

        // Multiple stops
        monitor.stop()
        monitor.stop()
    }

    @Test("Carbon hotkey debounces duplicate rapid triggers")
    @MainActor
    func testCarbonHotKeyDebounce() async throws {
        let checker = MutableFakePermissionChecker(trusted: true)
        let monitor = SystemShortcutMonitor(permissions: checker)
        monitor.start()

        let task = Task { @MainActor () -> [ShortcutEvent] in
            var received: [ShortcutEvent] = []
            for await event in monitor.events {
                received.append(event)
                if received.count >= 2 {
                    break
                }
            }
            return received
        }

        // Rapid duplicate triggers
        monitor.handleCarbonHotKey()
        monitor.handleCarbonHotKey()
        monitor.handleCarbonHotKey()

        // Wait for debounce window to elapse before second valid trigger
        try await Task.sleep(for: .milliseconds(350))
        monitor.handleCarbonHotKey()

        let events = await task.value
        #expect(events.count == 2)
        #expect(events == [.togglePanel, .togglePanel])

        monitor.stop()
    }

    @Test("Carbon hotkey ignores repeats while held down and triggers exactly once")
    @MainActor
    func testCarbonHotKeyIgnoresRepeatsWhileHeldDown() async throws {
        let checker = MutableFakePermissionChecker(trusted: true)
        let monitor = SystemShortcutMonitor(permissions: checker)
        monitor.start()

        let task = Task { @MainActor () -> [ShortcutEvent] in
            var received: [ShortcutEvent] = []
            for await event in monitor.events {
                received.append(event)
                if received.count >= 2 {
                    break
                }
            }
            return received
        }

        // 1. Initial key press (kEventHotKeyPressed = 5)
        monitor.handleCarbonHotKeyEvent(kind: 5)

        // 2. Simulated key repeats while key is held down (same event kind, no release)
        monitor.handleCarbonHotKeyEvent(kind: 5)
        monitor.handleCarbonHotKeyEvent(kind: 5)

        // Wait beyond debounce window, still held down
        try await Task.sleep(for: .milliseconds(350))
        monitor.handleCarbonHotKeyEvent(kind: 5)

        // 3. Key is finally released (kEventHotKeyReleased = 6)
        monitor.handleCarbonHotKeyEvent(kind: 6)

        // 4. New key press after release
        monitor.handleCarbonHotKeyEvent(kind: 5)

        let events = await task.value
        // Only 2 toggle events should be received: the initial press and the second press after release
        #expect(events.count == 2)
        #expect(events == [.togglePanel, .togglePanel])

        monitor.stop()
    }

    @Test("Carbon hotkey release resets held state")
    @MainActor
    func testCarbonHotKeyReleaseResetsHeldState() async throws {
        let checker = MutableFakePermissionChecker(trusted: true)
        let monitor = SystemShortcutMonitor(permissions: checker)
        monitor.start()

        let task = Task { @MainActor () -> [ShortcutEvent] in
            var received: [ShortcutEvent] = []
            for await event in monitor.events {
                received.append(event)
                if received.count >= 1 {
                    break
                }
            }
            return received
        }

        // Release without prior press is a safe no-op
        monitor.handleCarbonHotKeyEvent(kind: 6)
        monitor.handleCarbonHotKeyRelease()

        // Press fires cleanly
        monitor.handleCarbonHotKeyEvent(kind: 5)
        let events = await task.value
        #expect(events == [.togglePanel])

        monitor.stop()
    }
}
