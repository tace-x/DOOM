import Testing
import Foundation
@testable import DoomCore
@testable import DoomFeatures

@Suite("MenuStatusFormatterTests")
struct MenuStatusFormatterTests {
    @Test("Menu status during acquisition reflects privacy mode")
    func testAcquiringStatus() {
        let normal = MenuStatusFormatter.statusText(
            phase: .acquiring,
            isPanelVisible: false,
            isPrivacyModeEnabled: false,
            fallbackText: "Ready"
        )
        #expect(normal == "Working…")

        let privacy = MenuStatusFormatter.statusText(
            phase: .acquiring,
            isPanelVisible: false,
            isPrivacyModeEnabled: true,
            fallbackText: "Ready"
        )
        #expect(privacy == "Privacy Mode: Working…")
    }

    @Test("Menu status during request reflects privacy mode")
    func testRequestingStatus() {
        let summary = SelectionSummary(appName: "Safari", characterCount: 42)
        let normal = MenuStatusFormatter.statusText(
            phase: .requesting(summary),
            isPanelVisible: false,
            isPrivacyModeEnabled: false,
            fallbackText: "Ready"
        )
        #expect(normal == "Working…")

        let privacy = MenuStatusFormatter.statusText(
            phase: .requesting(summary),
            isPanelVisible: false,
            isPrivacyModeEnabled: true,
            fallbackText: "Ready"
        )
        #expect(privacy == "Privacy Mode: Working…")
    }

    @Test("Menu status when response succeeded and panel is hidden reflects ready status")
    func testSucceededHiddenStatus() {
        let response = ResponseContent(text: "Here is the answer")

        // Hidden without privacy mode
        let normalHidden = MenuStatusFormatter.statusText(
            phase: .succeeded(response),
            isPanelVisible: false,
            isPrivacyModeEnabled: false,
            fallbackText: "Ready"
        )
        #expect(normalHidden == "Response ready")

        // Hidden with privacy mode
        let privacyHidden = MenuStatusFormatter.statusText(
            phase: .succeeded(response),
            isPanelVisible: false,
            isPrivacyModeEnabled: true,
            fallbackText: "Ready"
        )
        #expect(privacyHidden == "Privacy Mode: Response ready")

        // Visible with privacy mode (e.g. user reopened panel)
        let privacyVisible = MenuStatusFormatter.statusText(
            phase: .succeeded(response),
            isPanelVisible: true,
            isPrivacyModeEnabled: true,
            fallbackText: "Ready"
        )
        #expect(privacyVisible == "Ready")

        // Visible without privacy mode
        let normalVisible = MenuStatusFormatter.statusText(
            phase: .succeeded(response),
            isPanelVisible: true,
            isPrivacyModeEnabled: false,
            fallbackText: "Ready"
        )
        #expect(normalVisible == "Ready")
    }

    @Test("Menu status for idle and failed phases falls back to standard status text")
    func testFallbackPhases() {
        let idleStatus = MenuStatusFormatter.statusText(
            phase: .idle,
            isPanelVisible: false,
            isPrivacyModeEnabled: true,
            fallbackText: "Setup needed"
        )
        #expect(idleStatus == "Setup needed")

        let presentation = MessageCatalog.presentation(for: GenerationError.timedOut)
        let failure = FailurePresentation(presentation: presentation, cooldownSeconds: 5)
        let failedStatus = MenuStatusFormatter.statusText(
            phase: .failed(failure),
            isPanelVisible: false,
            isPrivacyModeEnabled: true,
            fallbackText: "Ready"
        )
        #expect(failedStatus == "Ready")
    }
}
