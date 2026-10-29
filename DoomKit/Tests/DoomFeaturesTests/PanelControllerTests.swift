import Testing
import Foundation
#if canImport(AppKit)
import AppKit
#endif
@testable import DoomCore
@testable import DoomFeatures

@Suite("PanelControllerTests")
struct PanelControllerTests {
    @Test("Panel visibility toggles cleanly without cancelling in-flight requests")
    @MainActor
    func testPanelToggleAndInFlightPreservation() {
        let controller = PanelController()
        #expect(!controller.isVisible)

        // Show panel
        controller.show()
        #expect(controller.isVisible)

        // Put in requesting state
        let requestingState = PanelContentState.requesting(appName: "Safari", characterCount: 120, isTakingLonger: false)
        controller.updateState(requestingState)
        #expect(controller.state == requestingState)

        var cancelled = false
        controller.onCancelHandler = {
            cancelled = true
        }

        // Toggle (hide) while requesting
        controller.toggle()
        #expect(!controller.isVisible)
        #expect(controller.state == requestingState)
        #expect(!cancelled, "Hiding panel must never cancel in-flight request")

        // Response arrives while hidden
        let succeededState = PanelContentState.succeeded(text: "AI response arrived", isTruncated: false, restoreSkipped: false)
        controller.updateState(succeededState)
        #expect(!controller.isVisible, "Panel must remain hidden when response arrives")
        #expect(controller.state == succeededState)

        // Toggle again to show
        controller.toggle()
        #expect(controller.isVisible)
        #expect(controller.state == succeededState)
    }

    @Test("Repeated toggles alternate visibility state reliably")
    @MainActor
    func testRepeatedToggles() {
        let controller = PanelController()
        #expect(!controller.isVisible)

        controller.toggle()
        #expect(controller.isVisible)

        controller.toggle()
        #expect(!controller.isVisible)

        controller.toggle()
        #expect(controller.isVisible)

        controller.hide()
        #expect(!controller.isVisible)

        // Redundant hide
        controller.hide()
        #expect(!controller.isVisible)

        controller.show()
        #expect(controller.isVisible)

        // Redundant show
        controller.show()
        #expect(controller.isVisible)
    }

    @Test("Explicit show and hide lifecycle behaves predictably")
    @MainActor
    func testExplicitShowAndHideLifecycle() {
        let controller = PanelController()
        #expect(!controller.isVisible)
        #expect(controller.panel == nil)

        controller.show()
        #expect(controller.isVisible)
        #expect(controller.panel != nil)

        // Redundant show does not recreate panel
        let panelInstance = controller.panel
        controller.show()
        #expect(controller.isVisible)
        #expect(controller.panel === panelInstance)

        controller.hide()
        #expect(!controller.isVisible)

        // Redundant hide remains hidden
        controller.hide()
        #expect(!controller.isVisible)

        // Show again re-orders front
        controller.show()
        #expect(controller.isVisible)
    }

    @Test("Response arriving while hidden is preserved when panel is shown again")
    @MainActor
    func testResponseArrivingWhileHiddenRemainsAvailableWhenReopened() {
        let controller = PanelController()
        controller.show()

        let requestingState = PanelContentState.requesting(appName: "TextEdit", characterCount: 42, isTakingLonger: false)
        controller.updateState(requestingState)
        #expect(controller.isVisible)

        // Hide panel while request is active
        controller.hide()
        #expect(!controller.isVisible)

        // Gemini response arrives while hidden
        let expectedText = "Here is your concise explanation of the text."
        let responseState = PanelContentState.succeeded(text: expectedText, isTruncated: false, restoreSkipped: true)
        controller.updateState(responseState)

        // Panel must remain hidden
        #expect(!controller.isVisible)
        #expect(controller.state == responseState)

        // Reopen panel via show
        controller.show()
        #expect(controller.isVisible)
        #expect(controller.state == responseState)
        #expect(controller.state == responseState)
    }

    @Test("Error arriving while hidden is preserved when panel is reopened")
    @MainActor
    func testErrorArrivingWhileHiddenPreservedWhenReopened() {
        let controller = PanelController()
        controller.show()
        controller.updateState(.requesting(appName: "Pages", characterCount: 88, isTakingLonger: false))

        controller.hide()
        #expect(!controller.isVisible)

        let presentation = MessageCatalog.presentation(for: GenerationError.timedOut)
        controller.updateState(.failed(presentation: presentation, cooldownSeconds: 5))

        #expect(!controller.isVisible)
        #expect(controller.state == .failed(presentation: presentation, cooldownSeconds: 5))

        controller.toggle()
        #expect(controller.isVisible)
        #expect(controller.state == .failed(presentation: presentation, cooldownSeconds: 5))
    }

    @Test("Reopening panel does not trigger cancellation or state reset")
    @MainActor
    func testReopeningPanelDoesNotTriggerCancellationOrStateReset() {
        let controller = PanelController()
        let initialSuccess = PanelContentState.succeeded(text: "Preserved output", isTruncated: false, restoreSkipped: false)
        controller.updateState(initialSuccess)
        controller.show()

        var cancelInvoked = false
        var closeInvoked = false
        controller.onCancelHandler = { cancelInvoked = true }
        controller.onCloseHandler = { closeInvoked = true }

        // Hide then show repeatedly
        for _ in 0..<3 {
            controller.hide()
            #expect(!controller.isVisible)
            controller.show()
            #expect(controller.isVisible)
        }

        #expect(!cancelInvoked, "Reopening/toggling panel must never invoke cancel handler")
        #expect(!closeInvoked, "Reopening/toggling panel must never invoke close handler")
        #expect(controller.state == initialSuccess, "Panel content state must remain intact across reopenings")
    }

    @Test("Acquiring state is preserved across hide and show, then receives response")
    @MainActor
    func testAcquiringStatePreservedAcrossShowHide() {
        let controller = PanelController()
        var cancelInvoked = false
        controller.onCancelHandler = { cancelInvoked = true }

        // Start in acquiring
        controller.updateState(.acquiring)
        controller.show()
        #expect(controller.isVisible)
        #expect(controller.state == .acquiring)

        // Hide while acquiring
        controller.hide()
        #expect(!controller.isVisible)
        #expect(controller.state == .acquiring)
        #expect(!cancelInvoked, "Hiding during text acquisition must not trigger cancel handler")

        // Progresses to requesting while still hidden
        let requesting = PanelContentState.requesting(appName: "Notes", characterCount: 50, isTakingLonger: false)
        controller.updateState(requesting)
        #expect(!controller.isVisible)
        #expect(controller.state == requesting)

        // Receives response while still hidden
        let success = PanelContentState.succeeded(text: "Final response text", isTruncated: false, restoreSkipped: false)
        controller.updateState(success)
        #expect(!controller.isVisible)
        #expect(controller.state == success)

        // Reopened by user
        controller.show()
        #expect(controller.isVisible)
        #expect(controller.state == success)
        #expect(!cancelInvoked)
    }

    @Test("In-flight requesting state survives repeated toggles without cancelling")
    @MainActor
    func testInFlightRequestPreservedAcrossMultipleToggles() {
        let controller = PanelController()
        var cancelCount = 0
        var closeCount = 0
        controller.onCancelHandler = { cancelCount += 1 }
        controller.onCloseHandler = { closeCount += 1 }

        let inFlight = PanelContentState.requesting(appName: "Xcode", characterCount: 200, isTakingLonger: true)
        controller.updateState(inFlight)
        controller.show()

        // Toggle 5 times while in-flight
        for i in 1...5 {
            controller.toggle()
            let expectedVisible = (i % 2 == 0)
            #expect(controller.isVisible == expectedVisible)
            #expect(controller.state == inFlight)
            #expect(cancelCount == 0, "Repeated toggling must never cancel active request")
            #expect(closeCount == 0, "Repeated toggling must never invoke close handler")
        }

        // Response arrives
        let finalResponse = PanelContentState.succeeded(text: "Response after toggling", isTruncated: false, restoreSkipped: false)
        controller.updateState(finalResponse)

        if !controller.isVisible {
            controller.show()
        }
        #expect(controller.isVisible)
        #expect(controller.state == finalResponse)
        #expect(cancelCount == 0)
        #expect(closeCount == 0)
    }

    #if canImport(AppKit)
    @Test("HARDEN-03: DoomPanel cancelOperation and performKeyEquivalent with ⌘W trigger onCancelOrClose")
    @MainActor
    func testDoomPanelEscapeAndCommandWHandling() {
        let controller = PanelController()
        controller.show()
        guard let panel = controller.panel else {
            Issue.record("Expected panel to be created")
            return
        }

        var closeCalled = false
        controller.onCloseHandler = { closeCalled = true }

        // Test cancelOperation (Escape)
        panel.cancelOperation(nil)
        #expect(!controller.isVisible)
        #expect(closeCalled)

        // Show again
        controller.show()
        #expect(controller.isVisible)

        // Test performKeyEquivalent (⌘W)
        let cmdWEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "w",
            charactersIgnoringModifiers: "w",
            isARepeat: false,
            keyCode: 13
        )
        if let event = cmdWEvent {
            let handled = panel.performKeyEquivalent(with: event)
            #expect(handled)
            #expect(!controller.isVisible)
        }
    }
    #endif

    // MARK: - Privacy Mode Tests

    @MainActor
    private func makeAssistant() -> AssistantController {
        let deps = AssistantDependencies(
            permissions: PanelFakePermissionChecker(),
            credentials: PanelFakeCredentialStore(),
            textAcquirer: PanelFakeTextAcquirer(),
            ai: PanelFakeAIResponder(),
            preferences: PanelFakePreferences(),
            copyToPasteboard: { _ in },
            sleep: { _ in }
        )
        return AssistantController(dependencies: deps)
    }

    // MARK: - Privacy Mode Tests (Phase 4 Coverage)

    @Test("Overlay visibility behaves identically in both Privacy Mode states (locally visible by default)")
    @MainActor
    func testOverlayVisibilityInBothPrivacyStates() {
        let controller = PanelController()
        #expect(!controller.isPrivacyModeEnabled)
        #expect(!controller.isVisible)

        // Privacy Mode OFF: show, hide, toggle work normally
        controller.show()
        #expect(controller.isVisible)
        controller.hide()
        #expect(!controller.isVisible)
        controller.toggle()
        #expect(controller.isVisible)

        // Turn Privacy Mode ON: overlay remains visible locally by default!
        controller.setPrivacyMode(true)
        #expect(controller.isPrivacyModeEnabled)
        #expect(controller.isVisible, "Overlay must remain visible locally when Privacy Mode is enabled")

        // In Privacy Mode ON: show, hide, toggle work normally
        controller.hide()
        #expect(!controller.isVisible)
        controller.show()
        #expect(controller.isVisible, "Overlay must be visible locally when show() is called in Privacy Mode")
        controller.toggle()
        #expect(!controller.isVisible)
        controller.toggle()
        #expect(controller.isVisible, "Overlay must be visible locally when toggle() is called in Privacy Mode")
    }

    @Test("Shortcuts (toggle, activation, and dismiss) work identically in both Privacy Mode states")
    @MainActor
    func testShortcutsInBothPrivacyStates() {
        let assistant = makeAssistant()
        let controller = PanelController(assistant: assistant)

        // Test in Privacy Mode OFF
        assistant.onShowRequested?()
        #expect(controller.isVisible, "Activation shortcut handler must show panel in Privacy Mode OFF")

        guard let panel = controller.panel else {
            Issue.record("Expected panel to be created")
            return
        }

        // Dismiss via Escape
        panel.cancelOperation(nil)
        #expect(!controller.isVisible, "Escape dismiss must hide panel in Privacy Mode OFF")

        // Toggle shortcut
        controller.toggle()
        #expect(controller.isVisible, "Toggle shortcut must show panel in Privacy Mode OFF")

        // Dismiss via Command+W
        let cmdWEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "w",
            charactersIgnoringModifiers: "w",
            isARepeat: false,
            keyCode: 13
        )
        if let event = cmdWEvent {
            _ = panel.performKeyEquivalent(with: event)
            #expect(!controller.isVisible, "⌘W dismiss must hide panel in Privacy Mode OFF")
        }

        // Test in Privacy Mode ON
        controller.setPrivacyMode(true)
        #expect(controller.isPrivacyModeEnabled)

        // Activation shortcut handler in Privacy Mode ON
        assistant.onShowRequested?()
        #expect(controller.isVisible, "Activation shortcut handler must show panel in Privacy Mode ON")

        // Dismiss via Escape in Privacy Mode ON
        panel.cancelOperation(nil)
        #expect(!controller.isVisible, "Escape dismiss must hide panel in Privacy Mode ON")

        // Toggle shortcut in Privacy Mode ON
        controller.toggle()
        #expect(controller.isVisible, "Toggle shortcut must show panel in Privacy Mode ON")

        // Dismiss via Command+W in Privacy Mode ON
        if let event = cmdWEvent {
            _ = panel.performKeyEquivalent(with: event)
            #expect(!controller.isVisible, "⌘W dismiss must hide panel in Privacy Mode ON")
        }
    }

    @Test("In-flight request continues and completed response is preserved across Privacy Mode toggles")
    @MainActor
    func testInFlightRequestPreservedAcrossPrivacyModeToggle() {
        let assistant = makeAssistant()
        let controller = PanelController(assistant: assistant)

        var cancelCount = 0
        controller.onCancelHandler = { cancelCount += 1 }

        controller.show()
        #expect(controller.isVisible)

        let inFlightState = PanelContentState.requesting(appName: "Safari", characterCount: 150, isTakingLonger: false)
        controller.updateState(inFlightState)
        #expect(controller.state == inFlightState)

        // Toggle Privacy Mode ON while request is in flight
        controller.setPrivacyMode(true)
        #expect(controller.isPrivacyModeEnabled)
        #expect(controller.isVisible, "Overlay remains visible locally unless user opted into hide fallback")
        #expect(cancelCount == 0, "Toggling Privacy Mode must never cancel in-flight request")
        #expect(controller.state == inFlightState)

        // Hide overlay while request completes
        controller.hide()
        #expect(!controller.isVisible)

        // Response arrives while hidden
        let finalResponse = PanelContentState.succeeded(text: "Private explanation text", isTruncated: false, restoreSkipped: false)
        controller.updateState(finalResponse)
        #expect(!controller.isVisible)
        #expect(controller.state == finalResponse)
        #expect(cancelCount == 0)

        // Toggle Privacy Mode OFF while hidden
        controller.setPrivacyMode(false)
        #expect(!controller.isPrivacyModeEnabled)
        #expect(!controller.isVisible)
        #expect(controller.state == finalResponse)

        // Re-open overlay
        controller.show()
        #expect(controller.isVisible)
        #expect(controller.state == finalResponse, "Preserved response must be available upon reopening")
    }

    #if canImport(AppKit)
    @Test("Window sharingType property configuration: .none when Privacy Mode ON, .readOnly when OFF")
    @MainActor
    func testWindowSharingTypeConfiguration() {
        // NOTE: This test validates only that the NSWindow.sharingType property is set correctly
        // via the public AppKit API. It does NOT validate capture behavior with third-party software.
        let controller = PanelController()

        // Initial creation with Privacy Mode OFF
        controller.show()
        guard let panel1 = controller.panel else {
            Issue.record("Expected panel instance")
            return
        }
        #expect(panel1.sharingType == .readOnly, "Default sharingType must be .readOnly")

        // Toggle Privacy Mode ON at runtime
        controller.setPrivacyMode(true)
        #expect(panel1.sharingType == .none, "Enabling Privacy Mode must set sharingType to .none")

        // Toggle Privacy Mode OFF at runtime
        controller.setPrivacyMode(false)
        #expect(panel1.sharingType == .readOnly, "Disabling Privacy Mode must restore sharingType to .readOnly")

        // Panel created initially with Privacy Mode ON
        let privacyController = PanelController()
        privacyController.setPrivacyMode(true)
        privacyController.show()
        guard let panel2 = privacyController.panel else {
            Issue.record("Expected panel instance")
            return
        }
        #expect(panel2.sharingType == .none, "Window created with Privacy Mode ON must have sharingType == .none")
    }
    #endif

    @Test("Explicit opt-in fallback to hide locally behaves as opt-in only and never silently")
    @MainActor
    func testExplicitHideLocallyFallback() {
        let assistant = makeAssistant()
        let controller = PanelController(assistant: assistant)

        #expect(!controller.hideLocallyFallbackEnabled, "Hide locally fallback must be disabled by default")

        // Show panel
        controller.show()
        #expect(controller.isVisible)

        // Enable Privacy Mode without fallback: remains visible locally
        controller.setPrivacyMode(true)
        #expect(controller.isVisible, "Privacy Mode alone must not hide overlay locally")

        // Now explicitly opt in to the fallback
        controller.setHideLocallyFallback(true)
        #expect(controller.hideLocallyFallbackEnabled)
        #expect(!controller.isVisible, "Enabling fallback when Privacy Mode is ON must hide overlay locally")

        // While fallback is active and Privacy Mode is ON, auto-show is suppressed
        assistant.onShowRequested?()
        #expect(!controller.isVisible, "Auto-show must be suppressed when fallback is enabled in Privacy Mode")

        // Shortcut toggle deliberately reveals the overlay on explicit user action even when fallback is active
        controller.toggle()
        #expect(controller.isVisible, "Toggle deliberately reveals overlay on explicit user action even when fallback is active")
        #expect(controller.visibility == .visibleInteractive)

        // A second press hides it again
        controller.toggle()
        #expect(!controller.isVisible, "Second toggle hides overlay again")
        #expect(controller.visibility == .hiddenByLocalFallback)

        // Opting out of fallback restores local usability
        controller.setHideLocallyFallback(false)
        #expect(!controller.hideLocallyFallbackEnabled)

        // Now toggle reveals panel
        controller.toggle()
        #expect(controller.isVisible, "Overlay can be revealed when fallback is disabled")
        #expect(controller.visibility == .visibleInteractive)
    }

    @Test("Local overlay visibility in Privacy Mode ON and OFF (visible and interactive by default)")
    @MainActor
    func testLocalOverlayVisibilityInPrivacyModeStates() {
        let controller = PanelController()
        #expect(!controller.isVisible)
        #expect(controller.visibility == .hiddenByUser)

        // Privacy Mode OFF: show makes it visibleInteractive
        controller.show()
        #expect(controller.isVisible)
        #expect(controller.visibility == .visibleInteractive)

        // Privacy Mode ON without fallback: remains visibleInteractive locally
        controller.setPrivacyMode(true)
        #expect(controller.isVisible, "Privacy Mode ON alone must never hide overlay")
        #expect(controller.visibility == .visibleInteractive)

        // Toggle hides to hiddenByUser
        controller.toggle()
        #expect(!controller.isVisible)
        #expect(controller.visibility == .hiddenByUser)

        // Toggle restores visibleInteractive
        controller.toggle()
        #expect(controller.isVisible)
        #expect(controller.visibility == .visibleInteractive)
    }

    @Test("Dismissing overlay preserves completed response without cancelling assistant")
    @MainActor
    func testDismissPreservesResponses() async {
        let assistant = makeAssistant()
        let controller = PanelController(assistant: assistant)
        controller.show()

        let task = assistant.handleActivation(origin: .menu)
        _ = await task?.result

        #expect(controller.isVisible)
        guard case .succeeded(let text, _, _) = controller.state else {
            Issue.record("Expected succeeded state")
            return
        }
        #expect(!text.isEmpty)
        guard case .succeeded(let content) = assistant.phase else {
            Issue.record("Expected assistant to be in succeeded phase")
            return
        }

        // User presses Escape / Command+W / Close button (onCancelOrClose when not busy)
        controller.panel?.onCancelOrClose?()

        // Overlay is hidden, but response is preserved in memory
        #expect(!controller.isVisible)
        #expect(controller.visibility == .hiddenByUser)
        #expect(controller.state == .succeeded(text: content.text, isTruncated: content.isTruncated, restoreSkipped: content.restoreSkipped))
        #expect(assistant.phase == .succeeded(content), "Assistant phase must NOT be reset to idle on dismiss")

        // Reopening panel restores the preserved response
        controller.toggle()
        #expect(controller.isVisible)
        #expect(controller.state == .succeeded(text: content.text, isTruncated: content.isTruncated, restoreSkipped: content.restoreSkipped))
    }

    @Test("Response completing while Privacy Mode is ON is stored and displayed")
    @MainActor
    func testResponseCompletingInPrivacyModeIsStoredAndDisplayed() {
        let assistant = makeAssistant()
        let controller = PanelController(assistant: assistant)
        controller.setPrivacyMode(true)

        // Response completes while overlay was not visible
        let content = ResponseContent(text: "Response completed under Privacy Mode")
        assistant.onPhaseChange?(.succeeded(content))

        #expect(controller.isVisible, "Completed response must auto-show overlay when hideLocallyFallback is disabled")
        #expect(controller.visibility == .visibleInteractive)
        guard case .succeeded(let text, _, _) = controller.state else {
            Issue.record("Expected succeeded state")
            return
        }
        #expect(text == "Response completed under Privacy Mode")
    }

    @Test("In-flight requests and completed responses survive state transitions and recreation")
    @MainActor
    func testInFlightAndCompletedResponsesSurviveStateTransitions() {
        let assistant = makeAssistant()
        let controller = PanelController(assistant: assistant)
        controller.show()

        // In-flight requesting state
        let summary = SelectionSummary(appName: "Notes", characterCount: 50)
        assistant.onPhaseChange?(.requesting(summary))
        #expect(controller.state == .requesting(appName: "Notes", characterCount: 50, isTakingLonger: false))

        // Privacy Mode toggle during in-flight
        controller.setPrivacyMode(true)
        #expect(controller.state == .requesting(appName: "Notes", characterCount: 50, isTakingLonger: false))
        controller.setPrivacyMode(false)
        #expect(controller.state == .requesting(appName: "Notes", characterCount: 50, isTakingLonger: false))

        // Hide and show during in-flight
        controller.hide()
        #expect(controller.state == .requesting(appName: "Notes", characterCount: 50, isTakingLonger: false))
        controller.show()
        #expect(controller.state == .requesting(appName: "Notes", characterCount: 50, isTakingLonger: false))

        // Response completes
        let content = ResponseContent(text: "Completed response that must survive recreation")
        assistant.onPhaseChange?(.succeeded(content))
        #expect(controller.state == .succeeded(text: "Completed response that must survive recreation", isTruncated: false, restoreSkipped: false))

        // Recreate panel
        controller.recreatePanel()
        #expect(controller.isVisible)
        #expect(controller.state == .succeeded(text: "Completed response that must survive recreation", isTruncated: false, restoreSkipped: false))
    }

    #if canImport(AppKit)
    @Test("Window sharing exclusion configuration applied, not capture excluded")
    @MainActor
    func testWindowExclusionConfigurationAppliedNotCaptureExcluded() {
        let controller = PanelController()
        controller.show()

        #expect(controller.panel?.sharingType == .readOnly)
        let defaultConf = controller.currentExclusionConfiguration()
        #expect(!defaultConf.allWindowsConfigured)

        // Apply Privacy Mode
        controller.setPrivacyMode(true)
        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)
        let privacyConf = controller.currentExclusionConfiguration()
        #expect(privacyConf.allWindowsConfigured, "Configuration applied must reflect sharingType == .none")
        #expect(privacyConf.windowRecords.first?.configurationDescription == "none")

        // Revert
        controller.setPrivacyMode(false)
        #expect(controller.panel?.sharingType == .readOnly)
        let restoredConf = controller.currentExclusionConfiguration()
        #expect(!restoredConf.allWindowsConfigured)
    }

    @Test("Overlay recreation reapplies configuration to newly created windows")
    @MainActor
    func testOverlayRecreationReappliesConfiguration() {
        let controller = PanelController()
        controller.setPrivacyMode(true)
        controller.show()

        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)
        let oldPanel = controller.panel

        // Recreate
        controller.recreatePanel()
        let newPanel = controller.panel
        #expect(newPanel !== oldPanel, "New panel instance must be created")
        #expect(newPanel?.sharingType == NSWindow.SharingType.none, "Newly created panel must inherit active Privacy Mode configuration")
        #expect(controller.currentExclusionConfiguration().allWindowsConfigured)
    }

    @Test("DoomPanel direct initialization applies requested sharingType immediately on init")
    @MainActor
    func testDoomPanelDirectInitSharingType() {
        let rect = NSRect(x: 100, y: 100, width: 300, height: 200)

        // Default init is .readOnly
        let defaultPanel = DoomPanel(contentRect: rect)
        #expect(defaultPanel.sharingType == .readOnly, "Default DoomPanel init must have sharingType == .readOnly")

        // Explicit .none init
        let privatePanel = DoomPanel(contentRect: rect, sharingType: .none)
        #expect(privatePanel.sharingType == .none, "DoomPanel initialized with .none must have sharingType == .none immediately")

        // Explicit .readOnly init
        let readOnlyPanel = DoomPanel(contentRect: rect, sharingType: .readOnly)
        #expect(readOnlyPanel.sharingType == .readOnly, "DoomPanel initialized with .readOnly must have sharingType == .readOnly")
    }

    @Test("Panel recreation when Privacy Mode is OFF preserves .readOnly sharingType")
    @MainActor
    func testOverlayRecreationWhenPrivacyModeOff() {
        let controller = PanelController()
        #expect(!controller.isPrivacyModeEnabled)
        controller.show()

        #expect(controller.panel?.sharingType == .readOnly)
        let oldPanel = controller.panel

        controller.recreatePanel()
        let newPanel = controller.panel
        #expect(newPanel !== oldPanel, "New panel instance must be created")
        #expect(newPanel?.sharingType == .readOnly, "Recreated panel in Privacy Mode OFF must retain .readOnly")
    }

    @Test("State transitions and answer arrival strictly preserve exclusion configuration")
    @MainActor
    func testStateTransitionsAndAnswerArrivalPreserveExclusionConfiguration() {
        let controller = PanelController()
        controller.setPrivacyMode(true)
        controller.show()

        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)

        // 1. Acquiring state
        controller.updateState(.acquiring)
        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)

        // 2. Requesting state
        controller.updateState(.requesting(appName: "Xcode", characterCount: 50, isTakingLonger: false))
        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)

        // 3. Answer arrives (succeeded state)
        controller.updateState(.succeeded(text: "Here is the completed AI answer.", isTruncated: false, restoreSkipped: false))
        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)

        // 4. Long answer and scrolling
        let longText = String(repeating: "Line of markdown explanation.\n\n", count: 20)
        controller.updateState(.succeeded(text: longText, isTruncated: false, restoreSkipped: false))
        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)

        // 5. Error state
        let dummyError = MessagePresentation(
            id: "test-err",
            title: "Network Error",
            message: "Failed to reach service",
            actions: [.retry, .close],
            isWarning: true
        )
        controller.updateState(.failed(presentation: dummyError, cooldownSeconds: 5))
        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)

        // 6. When Privacy Mode is toggled OFF, transitions preserve .readOnly
        controller.setPrivacyMode(false)
        #expect(controller.panel?.sharingType == .readOnly)

        controller.updateState(.succeeded(text: "Normal capture answer", isTruncated: false, restoreSkipped: false))
        #expect(controller.panel?.sharingType == .readOnly)
    }

    @Test("Updating answer in place preserves the same panel instance without replacement")
    @MainActor
    func testUpdatingAnswerInPlacePreservesSameWindowInstance() {
        let controller = PanelController()
        controller.setPrivacyMode(true)
        controller.show()

        let initialPanel = controller.panel
        #expect(initialPanel != nil)
        #expect(initialPanel?.sharingType == NSWindow.SharingType.none)

        // Transition from requesting to succeeded
        controller.updateState(.requesting(appName: "TextEdit", characterCount: 15, isTakingLonger: false))
        #expect(controller.panel === initialPanel, "Panel instance must not be replaced during loading")
        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)

        controller.updateState(.succeeded(text: "First synthetic answer", isTruncated: false, restoreSkipped: false))
        #expect(controller.panel === initialPanel, "Panel instance must not be replaced when answer arrives")
        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)

        // Repeated question
        controller.updateState(.requesting(appName: "TextEdit", characterCount: 25, isTakingLonger: false))
        #expect(controller.panel === initialPanel)
        controller.updateState(.succeeded(text: "Second synthetic answer", isTruncated: false, restoreSkipped: false))
        #expect(controller.panel === initialPanel, "Panel instance must be updated in place for repeated questions")
        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)
    }

    @Test("Rapid and redundant Privacy Mode toggles are idempotent and strictly bounded")
    @MainActor
    func testRapidAndRedundantPrivacyModeTogglesAreIdempotent() {
        let controller = PanelController()
        var changeNotificationCount = 0
        controller.onPrivacyModeChange = { _ in
            changeNotificationCount += 1
        }

        // Redundant enable: 20 calls must notify exactly once
        for _ in 0..<20 {
            controller.setPrivacyMode(true)
        }
        #expect(changeNotificationCount == 1, "Redundant setPrivacyMode(true) must be idempotent")
        #expect(controller.isPrivacyModeEnabled == true)

        // Redundant disable: 20 calls must notify exactly once more
        for _ in 0..<20 {
            controller.setPrivacyMode(false)
        }
        #expect(changeNotificationCount == 2, "Redundant setPrivacyMode(false) must be idempotent")
        #expect(controller.isPrivacyModeEnabled == false)

        // Rapid alternation: 10 cycles (20 state changes)
        for i in 0..<20 {
            controller.setPrivacyMode(i % 2 == 0)
        }
        #expect(changeNotificationCount == 22, "Notification count must equal exact state changes without recursion")
    }

    @Test("Reopening panel preserves Privacy Mode configuration")
    @MainActor
    func testReopeningPanelPreservesPrivacyModeSetting() {
        let controller = PanelController()
        controller.setPrivacyMode(true)
        controller.show()

        #expect(controller.isVisible)
        #expect(controller.panel?.sharingType == NSWindow.SharingType.none)

        // Hide panel
        controller.hide()
        #expect(!controller.isVisible)

        // Reopen panel
        controller.show()
        #expect(controller.isVisible)
        #expect(controller.panel?.sharingType == NSWindow.SharingType.none, "Reopened panel must retain .none sharingType")
    }
    #endif
}

// MARK: - Test Doubles for PanelControllerTests

private final class PanelFakePermissionChecker: PermissionChecking, @unchecked Sendable {
    var state: PermissionState = .granted
    func accessibilityState() -> PermissionState { state }
    @MainActor func requestAccessibility() {}
    @MainActor func openAccessibilitySettings() {}
}

private final class PanelFakePreferences: PreferencesStoring, @unchecked Sendable {
    var privacyNoticeAcknowledgedVersion: Int = 1
    var copyFallbackEnabled: Bool = false
    var modelIDOverride: String? = nil
}

private final class PanelFakeCredentialStore: CredentialStoring, @unchecked Sendable {
    var keyToReturn: APIKey? = APIKey(validating: "TEST-KEY-1234567890abcdefghijklmnopqrst")
    func hasAPIKey() async throws(CredentialStoreError) -> Bool { keyToReturn != nil }
    func readAPIKey() async throws(CredentialStoreError) -> APIKey? { keyToReturn }
    func saveAPIKey(_ key: APIKey) async throws(CredentialStoreError) { keyToReturn = key }
    func deleteAPIKey() async throws(CredentialStoreError) { keyToReturn = nil }
}

private final class PanelFakeTextAcquirer: TextAcquiring, @unchecked Sendable {
    @MainActor
    func acquireSelection(copyFallbackEnabled: Bool) async throws(TextAcquisitionError) -> SelectedText {
        SelectedText(
            value: "Sample acquired text",
            characterCount: 20,
            source: SourceApplication(localizedName: "TextEdit", bundleIdentifier: "com.apple.TextEdit"),
            method: .accessibility
        )
    }
}

private final class PanelFakeAIResponder: AIResponding, @unchecked Sendable {
    var resultToReturn: Result<GenerationResult, GenerationError> = .success(
        GenerationResult(text: "Here is the AI answer.", isTruncated: false)
    )
    func respond(to request: GenerationRequest, apiKey: APIKey) async throws(GenerationError) -> GenerationResult {
        switch resultToReturn {
        case .success(let result): return result
        case .failure(let error): throw error
        }
    }
}

