import Testing
import Foundation
@testable import DoomFeatures

@Suite("PrivacyProtectionStateTests")
struct PrivacyProtectionStateTests {

    @Test("Privacy Mode OFF always yields inactive status")
    func testPrivacyModeOff() {
        let state = PrivacyProtectionState(
            requested: false,
            windowExclusionApplied: false,
            sharingContext: .notSure,
            verification: .notVerified,
            hideLocallyFallbackEnabled: false
        )

        #expect(!state.isVerifiedProtected)
        #expect(state.protectionStatus == .notRequested)
        #expect(state.statusDescription == "Privacy Mode is off.")
        #expect(state.overlayStatusLine == nil)
    }

    @Test("Exclusion property alone never produces verified protected status")
    func testExclusionPropertyAloneNeverVerified() {
        let state = PrivacyProtectionState(
            requested: true,
            windowExclusionApplied: true,
            sharingContext: .notSure,
            verification: .notVerified,
            hideLocallyFallbackEnabled: false
        )

        #expect(!state.isVerifiedProtected, "Exclusion property alone must never yield verified protected status")
        #expect(state.protectionStatus == .requestedUnverified(method: "Unspecified sharing method"))
        #expect(state.statusDescription.contains("not confirmed"))
        #expect(!state.statusDescription.lowercased().contains("protected"))
        #expect(!state.statusDescription.lowercased().contains("secure"))
        #expect(!state.statusDescription.lowercased().contains("invisible"))
    }

    @Test("Not sure sharing context yields requestedUnverified and never verified status")
    func testNotSureSharingContextYieldsRequestedUnverified() {
        let state = PrivacyProtectionState(
            requested: true,
            windowExclusionApplied: true,
            sharingContext: .notSure,
            verification: .notVerified,
            hideLocallyFallbackEnabled: false
        )

        #expect(!state.isVerifiedProtected)
        #expect(state.protectionStatus == .requestedUnverified(method: "Unspecified sharing method"))
        #expect(state.statusDescription.contains("not confirmed for Unspecified sharing method"))
    }

    @Test("Chrome / Google Meet entire screen on macOS 27 yields knownNotEffective")
    func testEntireScreenYieldsKnownNotEffective() {
        let state = PrivacyProtectionState(
            requested: true,
            windowExclusionApplied: true,
            sharingContext: .entireScreen,
            verification: .notVerified,
            hideLocallyFallbackEnabled: false
        )

        #expect(!state.isVerifiedProtected)
        guard case .knownNotEffective(let method, let evidence) = state.protectionStatus else {
            Issue.record("Expected knownNotEffective for entireScreen on macOS 27")
            return
        }
        #expect(method.contains("Entire screen"))
        #expect(evidence.contains("display framebuffer"))
        #expect(state.statusDescription.contains("not effective for entire-screen sharing in Google Meet/Chrome on macOS 27"))
        #expect(state.statusDescription.contains("DOOM may appear on your shared screen"))
        #expect(state.overlayStatusLine == "Exclusion requested; not confirmed for your sharing method. It may appear on your shared screen.")
    }

    @Test("Failed self-test yields selfTestFailed status")
    func testFailedSelfTestYieldsSelfTestFailed() {
        let state = PrivacyProtectionState(
            requested: true,
            windowExclusionApplied: true,
            sharingContext: .singleWindow,
            verification: .selfTestFailed(api: "WindowServer", osVersion: "27.0.1"),
            hideLocallyFallbackEnabled: false
        )

        #expect(!state.isVerifiedProtected)
        #expect(state.protectionStatus == .selfTestFailed(api: "WindowServer", osBuild: "27.0.1"))
        #expect(state.statusDescription.contains("Exclusion setting failed under WindowServer on macOS 27.0.1"))
    }

    @Test("Passed self-test is scoped strictly to tested API and OS build")
    func testPassedSelfTestScopedStrictly() {
        let state = PrivacyProtectionState(
            requested: true,
            windowExclusionApplied: true,
            sharingContext: .singleWindow,
            verification: .selfTestPassed(api: "WindowServer", osVersion: "27.0.1 (Build 26A434)"),
            hideLocallyFallbackEnabled: false
        )

        #expect(!state.isVerifiedProtected, "Self-test passes configuration check only, not third-party WebRTC capture verification")
        #expect(state.protectionStatus == .selfTestPassed(api: "WindowServer", osBuild: "27.0.1 (Build 26A434)"))
        #expect(state.statusDescription.contains("Local self-test passed under WindowServer on macOS 27.0.1 (Build 26A434)"))
        #expect(state.statusDescription.contains("does not verify third-party WebRTC capture"))
    }

    @Test("User confirmed status is verified but invalidated on OS build or browser version mismatch")
    func testUserConfirmationInvalidation() {
        let state = PrivacyProtectionState(
            requested: true,
            windowExclusionApplied: true,
            sharingContext: .entireScreen,
            fallbackMode: .none,
            userConfirmationRecord: UserConfirmationRecord(
                method: "Google Meet in Chrome",
                osBuild: "26A434",
                browserVersion: "156.0.8078.47",
                date: "2026-10-26"
            )
        )

        // Matching environment
        let matchingStatus = state.computeProtectionStatus(currentOSBuild: "26A434", currentBrowserVersion: "156.0.8078.47")
        #expect(matchingStatus == .userConfirmed(method: "Google Meet in Chrome", osBuild: "26A434", browserVersion: "156.0.8078.47", date: "2026-10-26"))

        // Mismatched OS build invalidates user confirmed status
        let osChangedStatus = state.computeProtectionStatus(currentOSBuild: "26A500", currentBrowserVersion: "156.0.8078.47")
        #expect(osChangedStatus != matchingStatus)
        guard case .knownNotEffective = osChangedStatus else {
            Issue.record("Expected fallback to knownNotEffective when OS build changes")
            return
        }

        // Mismatched Chrome version invalidates user confirmed status
        let browserChangedStatus = state.computeProtectionStatus(currentOSBuild: "26A434", currentBrowserVersion: "157.0.0.0")
        #expect(browserChangedStatus != matchingStatus)
        guard case .knownNotEffective = browserChangedStatus else {
            Issue.record("Expected fallback to knownNotEffective when browser version changes")
            return
        }
    }

    @Test("Local-hide fallback is explicit opt-in only and never enabled by default")
    func testFallbackExplicitOptIn() {
        let defaultState = PrivacyProtectionState(
            requested: true,
            windowExclusionApplied: true,
            sharingContext: .entireScreen
        )

        #expect(defaultState.fallbackMode == .none, "Fallback must be none by default")
        #expect(!defaultState.hideLocallyFallbackEnabled, "Local hide fallback must be false by default")

        var optInState = defaultState
        optInState.fallbackMode = .localHideWhileSharing
        #expect(optInState.hideLocallyFallbackEnabled)
        #expect(optInState.overlayStatusLine == nil, "Overlay status line suppressed when locally hidden")
    }

    @Test("No false-positive protection status in any UI string derived from model")
    func testNoFalsePositiveStrings() {
        let contexts: [SharingContext] = [.entireScreen, .notSure, .separateDisplay]
        for ctx in contexts {
            let state = PrivacyProtectionState(
                requested: true,
                windowExclusionApplied: true,
                sharingContext: ctx,
                verification: .notVerified,
                hideLocallyFallbackEnabled: false
            )

            let desc = state.statusDescription.lowercased()
            #expect(!desc.contains("protected"), "Description must not claim 'protected' for \(ctx)")
            #expect(!desc.contains("secure"), "Description must not claim 'secure' for \(ctx)")
            #expect(!desc.contains("invisible"), "Description must not claim 'invisible' for \(ctx)")
            #expect(!desc.contains("hidden from screen share"), "Description must not claim 'hidden from screen share' for \(ctx)")
        }
    }

    @Test("Table-driven test across status combinations verifies honesty guarantees", arguments: [
        // (requested, applied, context, verification, expectedVerified, expectedStatusFragment)
        (false, false, SharingContext.notSure, VerificationStatus.notVerified, false, "Privacy Mode is off."),
        (true, false, SharingContext.notSure, VerificationStatus.notVerified, false, "property is not applied"),
        (true, true, SharingContext.notSure, VerificationStatus.notVerified, false, "not confirmed for Unspecified sharing method"),
        (true, true, SharingContext.entireScreen, VerificationStatus.notVerified, false, "not effective for entire-screen sharing"),
        (true, true, SharingContext.singleWindow, VerificationStatus.notVerified, false, "not confirmed for A single window"),
        (true, true, SharingContext.entireScreen, VerificationStatus.selfTestFailed(api: "WindowServer", osVersion: "27.0.1"), false, "not effective for entire-screen sharing"),
        (true, true, SharingContext.singleWindow, VerificationStatus.selfTestPassed(api: "WindowServer", osVersion: "27.0.1"), false, "Local self-test passed under WindowServer")
    ])
    func testStatusModelTruthMatrix(
        requested: Bool,
        applied: Bool,
        context: SharingContext,
        verification: VerificationStatus,
        expectedVerified: Bool,
        expectedStatusFragment: String
    ) {
        let state = PrivacyProtectionState(
            requested: requested,
            windowExclusionApplied: applied,
            sharingContext: context,
            verification: verification,
            hideLocallyFallbackEnabled: false
        )

        #expect(state.isVerifiedProtected == expectedVerified)
        #expect(state.statusDescription.contains(expectedStatusFragment))
        if !expectedVerified {
            #expect(!state.statusDescription.contains("Protected"))
            #expect(!state.statusDescription.contains("Secure"))
        }
    }
}
