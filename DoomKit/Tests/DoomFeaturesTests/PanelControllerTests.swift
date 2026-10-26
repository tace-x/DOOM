import Testing
import Foundation
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
}
