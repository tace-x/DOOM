import Foundation
import DoomCore
import OSLog
#if canImport(AppKit)
import AppKit
#endif
#if canImport(Carbon)
import Carbon
#endif

private func carbonHotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData = userData else { return noErr }
    let monitor = Unmanaged<SystemShortcutMonitor>.fromOpaque(userData).takeUnretainedValue()
    #if canImport(Carbon)
    let eventKind = event.map { GetEventKind($0) } ?? UInt32(kEventHotKeyPressed)
    MainActor.assumeIsolated {
        monitor.handleCarbonHotKeyEvent(kind: eventKind)
    }
    #else
    MainActor.assumeIsolated {
        monitor.handleCarbonHotKey()
    }
    #endif
    return noErr
}

@MainActor
public final class SystemShortcutMonitor: ShortcutMonitoring {
    public let events: AsyncStream<ShortcutEvent>
    private let continuation: AsyncStream<ShortcutEvent>.Continuation

    public private(set) var status: ShortcutStatus

    private let permissions: any PermissionChecking
    private var recognizer = ChordRecognizer()

    #if canImport(AppKit)
    private var localMonitor: Any?
    private var globalMonitor: Any?
    #endif

    #if canImport(Carbon)
    private var carbonHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var isDistributedObserverInstalled: Bool = false
    #endif

    private var isStarted: Bool = false
    private let logger = Logger(subsystem: "com.tace.doom", category: "shortcuts")

    public init(permissions: any PermissionChecking) {
        self.permissions = permissions
        let (stream, cont) = AsyncStream<ShortcutEvent>.makeStream(bufferingPolicy: .bufferingNewest(8))
        self.events = stream
        self.continuation = cont

        let isTrusted = permissions.accessibilityState() == .granted
        self.status = ShortcutStatus(
            activation: isTrusted ? .active : .needsAccessibility,
            panelToggle: .available
        )
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true

        installMonitors()
        registerCarbonHotKey()
        installLayoutChangeObserver()
        updateStatus()
    }

    public func refreshAfterPermissionChange() {
        let isTrusted = permissions.accessibilityState() == .granted
        let previousState = status.activation

        if isTrusted && previousState != .active {
            // F-13: Reinstall global monitor when trust transitions to granted
            logger.notice("Accessibility granted while running. Reinstalling event monitors.")
            removeMonitors()
            installMonitors()
        }

        updateStatus()
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false

        isHotKeyHeld = false
        removeMonitors()
        unregisterCarbonHotKey()
        removeLayoutChangeObserver()
        continuation.finish()
    }

    private func updateStatus() {
        let isTrusted = permissions.accessibilityState() == .granted
        self.status = ShortcutStatus(
            activation: isTrusted ? .active : .needsAccessibility,
            panelToggle: self.status.panelToggle
        )
    }

    // MARK: - Event Monitors (Chord Recognizer)

    private func installMonitors() {
        #if canImport(AppKit)
        // Local monitor (events directed to DOOM itself)
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
                self?.handleEvent(event)
                return event
            }
        }

        // Global monitor (events directed to other applications)
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
                self?.handleEvent(event)
            }
        }
        #endif
    }

    private func removeMonitors() {
        #if canImport(AppKit)
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            localMonitor = nil
        }
        if let global = globalMonitor {
            NSEvent.removeMonitor(global)
            globalMonitor = nil
        }
        #endif
        recognizer.reset()
    }

    #if canImport(AppKit)
    private func handleEvent(_ event: NSEvent) {
        // Privacy rule §3.5: Read ONLY event.type, modifierFlags, and timestamp.
        // Never read characters or key code of keyDown events.
        switch event.type {
        case .flagsChanged:
            let snapshot = ModifierSnapshot(flags: event.modifierFlags)
            if recognizer.handle(event: .flagsChanged(snapshot), timestamp: event.timestamp) {
                logger.notice("Activation chord detected via flagsChanged release")
                continuation.yield(.activate(origin: .chord))
            }
        case .keyDown:
            if recognizer.handle(event: .keyDown, timestamp: event.timestamp) {
                continuation.yield(.activate(origin: .chord))
            }
        default:
            break
        }
    }
    #endif

    // MARK: - Carbon HotKey (Control + Shift + H)

    private func registerCarbonHotKey() {
        #if canImport(Carbon)
        if carbonHandlerRef == nil {
            var eventTypes = [
                EventTypeSpec(
                    eventClass: OSType(kEventClassKeyboard),
                    eventKind: UInt32(kEventHotKeyPressed)
                ),
                EventTypeSpec(
                    eventClass: OSType(kEventClassKeyboard),
                    eventKind: UInt32(kEventHotKeyReleased)
                )
            ]

            let ptr = Unmanaged.passUnretained(self).toOpaque()
            let installStatus = InstallEventHandler(
                GetEventDispatcherTarget(),
                carbonHotKeyCallback,
                eventTypes.count,
                &eventTypes,
                ptr,
                &carbonHandlerRef
            )

            if installStatus != noErr {
                logger.error("Failed to install Carbon event handler with OSStatus: \(installStatus)")
                self.status = ShortcutStatus(
                    activation: self.status.activation,
                    panelToggle: .unavailable(status: installStatus)
                )
                return
            }
        }

        unregisterOnlyHotKey()

        let (keyCode, didFallback) = KeyCodeResolver.currentKeyCodeForH()
        if didFallback {
            logger.info("Using layout fallback keycode for 'H'")
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x444F4F4D), id: 1) // 'DOOM'
        let regStatus = RegisterEventHotKey(
            keyCode,
            UInt32(controlKey | shiftKey),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if regStatus == noErr {
            self.status = ShortcutStatus(
                activation: self.status.activation,
                panelToggle: .available
            )
        } else {
            logger.error("RegisterEventHotKey failed with OSStatus: \(regStatus)")
            self.status = ShortcutStatus(
                activation: self.status.activation,
                panelToggle: .unavailable(status: regStatus)
            )
        }
        #endif
    }

    private func unregisterOnlyHotKey() {
        #if canImport(Carbon)
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        #endif
    }

    private func unregisterCarbonHotKey() {
        #if canImport(Carbon)
        unregisterOnlyHotKey()
        if let handler = carbonHandlerRef {
            RemoveEventHandler(handler)
            carbonHandlerRef = nil
        }
        #endif
    }

    private var isHotKeyHeld: Bool = false
    private var lastHotKeyInstant: ContinuousClock.Instant = .now - .seconds(10)
    private let hotKeyDebounceDuration: Duration = .milliseconds(300)

    func handleCarbonHotKeyEvent(kind: UInt32) {
        #if canImport(Carbon)
        if kind == UInt32(kEventHotKeyReleased) {
            isHotKeyHeld = false
            logger.debug("Control+Shift+H hotkey released.")
            return
        }
        guard kind == UInt32(kEventHotKeyPressed) else { return }
        #endif

        let now = ContinuousClock.now
        if isHotKeyHeld {
            logger.notice("Ignoring repeat hotkey press while key is held down")
            return
        }
        isHotKeyHeld = true

        guard now - lastHotKeyInstant >= hotKeyDebounceDuration else {
            logger.notice("Ignoring duplicate/rapid hotkey press within debounce window")
            return
        }
        lastHotKeyInstant = now
        logger.notice("Control+Shift+H hotkey pressed. Toggling panel.")
        continuation.yield(.togglePanel)
    }

    func handleCarbonHotKey() {
        let now = ContinuousClock.now
        guard now - lastHotKeyInstant >= hotKeyDebounceDuration else {
            logger.notice("Ignoring duplicate/rapid hotkey press within debounce window")
            return
        }
        lastHotKeyInstant = now
        logger.notice("Control+Shift+H hotkey pressed. Toggling panel.")
        continuation.yield(.togglePanel)
    }

    func handleCarbonHotKeyRelease() {
        isHotKeyHeld = false
    }

    // MARK: - Keyboard Layout Change Notification

    private func installLayoutChangeObserver() {
        #if canImport(Carbon)
        guard !isDistributedObserverInstalled else { return }
        isDistributedObserverInstalled = true

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleLayoutChanged()
            }
        }
        #endif
    }

    private func removeLayoutChangeObserver() {
        #if canImport(Carbon)
        guard isDistributedObserverInstalled else { return }
        isDistributedObserverInstalled = false
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
        #endif
    }

    private func handleLayoutChanged() {
        logger.info("Keyboard input source changed. Re-registering Control+Shift+H hotkey.")
        registerCarbonHotKey()
    }
}
