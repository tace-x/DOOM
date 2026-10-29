import Testing
import Foundation
import DoomCore
@testable import DoomFeatures

// MARK: - Test Doubles

private final class AssistantFakePermissionChecker: PermissionChecking, @unchecked Sendable {
    var state: PermissionState = .granted
    var requestCalled: Bool = false
    var openSettingsCalled: Bool = false

    func accessibilityState() -> PermissionState {
        state
    }

    @MainActor
    func requestAccessibility() {
        requestCalled = true
    }

    @MainActor
    func openAccessibilitySettings() {
        openSettingsCalled = true
    }
}

private final class AssistantFakePreferences: PreferencesStoring, @unchecked Sendable {
    var privacyNoticeAcknowledgedVersion: Int = 1
    var copyFallbackEnabled: Bool = false
    var modelIDOverride: String? = nil
}

private final class AssistantFakeCredentialStore: CredentialStoring, @unchecked Sendable {
    var keyToReturn: APIKey? = APIKey(validating: "TEST-KEY-1234567890abcdefghijklmnopqrst")
    var hasKeyError: CredentialStoreError? = nil
    var readKeyError: CredentialStoreError? = nil
    var hasKeyCallCount: Int = 0
    var readKeyCallCount: Int = 0

    func hasAPIKey() async throws(CredentialStoreError) -> Bool {
        hasKeyCallCount += 1
        if let error = hasKeyError {
            throw error
        }
        return keyToReturn != nil
    }

    func readAPIKey() async throws(CredentialStoreError) -> APIKey? {
        readKeyCallCount += 1
        if let error = readKeyError {
            throw error
        }
        return keyToReturn
    }

    func saveAPIKey(_ key: APIKey) async throws(CredentialStoreError) {
        keyToReturn = key
    }

    func deleteAPIKey() async throws(CredentialStoreError) {
        keyToReturn = nil
    }
}

private final class AssistantFakeTextAcquirer: TextAcquiring, @unchecked Sendable {
    var acquireCount: Int = 0
    var resultToReturn: Result<SelectedText, TextAcquisitionError> = .success(
        SelectedText(
            value: "Sample acquired text",
            characterCount: 20,
            source: SourceApplication(localizedName: "TextEdit", bundleIdentifier: "com.apple.TextEdit"),
            method: .accessibility
        )
    )
    var delay: Duration? = nil

    @MainActor
    func acquireSelection(copyFallbackEnabled: Bool) async throws(TextAcquisitionError) -> SelectedText {
        acquireCount += 1
        if let delay = delay {
            try? await Task.sleep(for: delay)
        }
        switch resultToReturn {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }
}

private final class AssistantFakeAIResponder: AIResponding, @unchecked Sendable {
    var respondCount: Int = 0
    var lastRequest: GenerationRequest?
    var resultToReturn: Result<GenerationResult, GenerationError> = .success(
        GenerationResult(text: "Here is the AI answer.", isTruncated: false)
    )
    var delay: Duration? = nil
    var onRespond: (() -> Void)?

    func respond(to request: GenerationRequest, apiKey: APIKey) async throws(GenerationError) -> GenerationResult {
        respondCount += 1
        lastRequest = request
        onRespond?()
        if let delay = delay {
            try? await Task.sleep(for: delay)
        }
        switch resultToReturn {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - AssistantControllerTests

@Suite("AssistantControllerTests")
struct AssistantControllerTests {

    @MainActor
    private func makeHarness(
        sleepHandler: (@Sendable (Duration) async throws -> Void)? = nil
    ) -> (
        controller: AssistantController,
        permissions: AssistantFakePermissionChecker,
        credentials: AssistantFakeCredentialStore,
        textAcquirer: AssistantFakeTextAcquirer,
        ai: AssistantFakeAIResponder,
        preferences: AssistantFakePreferences,
        copiedText: Box<String?>
    ) {
        let perms = AssistantFakePermissionChecker()
        let creds = AssistantFakeCredentialStore()
        let acquirer = AssistantFakeTextAcquirer()
        let ai = AssistantFakeAIResponder()
        let prefs = AssistantFakePreferences()
        let copied = Box<String?>(nil)

        let deps = AssistantDependencies(
            permissions: perms,
            credentials: creds,
            textAcquirer: acquirer,
            ai: ai,
            preferences: prefs,
            copyToPasteboard: { text in
                copied.value = text
            },
            sleep: sleepHandler ?? { _ in }
        )

        let controller = AssistantController(dependencies: deps)
        return (controller, perms, creds, acquirer, ai, prefs, copied)
    }

    private final class Box<T>: @unchecked Sendable {
        var value: T
        init(_ value: T) { self.value = value }
    }

    // MARK: - State Transitions & Happy Path (LIFE-T-01)

    @Test("LIFE-T-01: Happy path state transitions idle -> acquiring -> requesting -> succeeded")
    @MainActor
    func testHappyPathTransitions() async {
        let h = makeHarness()
        #expect(h.controller.phase == .idle)
        #expect(!h.controller.isBusy)

        var observedPhases: [AssistantController.Phase] = []
        h.controller.onPhaseChange = { phase in
            observedPhases.append(phase)
        }

        var showRequestedCount = 0
        h.controller.onShowRequested = {
            showRequestedCount += 1
        }

        let task = h.controller.handleActivation(origin: .chord)
        #expect(task != nil)
        _ = await task?.result

        #expect(h.controller.phase == .succeeded(ResponseContent(text: "Here is the AI answer.", isTruncated: false, restoreSkipped: false)))
        #expect(!h.controller.isBusy)
        #expect(h.textAcquirer.acquireCount == 1)
        #expect(h.ai.respondCount == 1)
        #expect(showRequestedCount >= 1)
        #expect(h.controller.lastAcquiredText?.value == "Sample acquired text")

        // Verify phase sequence
        #expect(observedPhases.contains { if case .acquiring = $0 { return true } else { return false } })
        #expect(observedPhases.contains { if case .requesting = $0 { return true } else { return false } })
        #expect(observedPhases.contains { if case .succeeded = $0 { return true } else { return false } })
    }

    // MARK: - Prerequisite Order (LIFE-T-02 / LIFE-06)

    @Test("LIFE-T-02: Prerequisite check 1: Accessibility failure stops before privacy and credentials")
    @MainActor
    func testPrerequisiteAccessibilityCheck() async {
        let h = makeHarness()
        h.permissions.state = .notGranted

        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result

        if case .failed(let failure) = h.controller.phase {
            #expect(failure.presentation.id == "E-ACC-01")
            #expect(failure.presentation.actions.contains(.openSettings))
        } else {
            Issue.record("Expected failed phase with accessibility presentation, got \(h.controller.phase)")
        }

        #expect(h.credentials.hasKeyCallCount == 0, "Credentials must not be checked if accessibility fails")
        #expect(h.textAcquirer.acquireCount == 0)
        #expect(h.ai.respondCount == 0)
    }

    @Test("LIFE-T-02: Prerequisite check 2: Privacy notice failure stops before credentials")
    @MainActor
    func testPrerequisitePrivacyCheck() async {
        let h = makeHarness()
        h.preferences.privacyNoticeAcknowledgedVersion = 0 // Not acknowledged

        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result

        if case .failed(let failure) = h.controller.phase {
            #expect(failure.presentation.id == "E-PRIV-01")
            #expect(failure.presentation.actions.contains(.reviewPrivacy))
        } else {
            Issue.record("Expected failed phase with privacy presentation, got \(h.controller.phase)")
        }

        #expect(h.credentials.hasKeyCallCount == 0, "Credentials must not be checked if privacy notice unacknowledged")
        #expect(h.textAcquirer.acquireCount == 0)
        #expect(h.ai.respondCount == 0)
    }

    @Test("LIFE-T-02: Prerequisite check 3: Missing API key fails with apiKey presentation")
    @MainActor
    func testPrerequisiteAPIKeyCheck() async {
        let h = makeHarness()
        h.credentials.keyToReturn = nil

        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result

        if case .failed(let failure) = h.controller.phase {
            #expect(failure.presentation.id == "E-KEY-01")
            #expect(failure.presentation.actions.contains(.openSettings))
        } else {
            Issue.record("Expected failed phase with apiKey presentation, got \(h.controller.phase)")
        }

        #expect(h.credentials.hasKeyCallCount == 1)
        #expect(h.textAcquirer.acquireCount == 0)
        #expect(h.ai.respondCount == 0)
    }

    // MARK: - Single Flight Enforcement (SHORTCUT-T-09 / INV-2)

    @Test("SHORTCUT-T-09: Activation while busy is ignored and does not start second request")
    @MainActor
    func testSingleFlightEnforcement() async {
        let h = makeHarness()
        h.ai.delay = .milliseconds(100)

        var showRequestedCount = 0
        h.controller.onShowRequested = {
            showRequestedCount += 1
        }

        let task1 = h.controller.handleActivation(origin: .chord)
        #expect(task1 != nil)
        #expect(h.controller.isBusy)

        // Attempt second activation while busy
        let task2 = h.controller.handleActivation(origin: .chord)
        #expect(task2 == nil, "Second activation while busy must return nil")
        #expect(showRequestedCount == 2, "onShowRequested must be called to re-surface existing progress")

        _ = await task1?.result
        #expect(h.ai.respondCount == 1, "Only one AI request must execute")
    }

    // MARK: - Discard Content & Cancellation (LIFE-T-03 / GEMINI-T-07)

    @Test("LIFE-T-03: Cancel aborts active request and resets to idle")
    @MainActor
    func testCancelResetsToIdle() async {
        let h = makeHarness()
        h.ai.delay = .milliseconds(150)

        _ = h.controller.handleActivation(origin: .chord)
        #expect(h.controller.isBusy)

        h.controller.cancel()
        #expect(h.controller.phase == .idle)
        #expect(h.controller.lastAcquiredText == nil)
        #expect(!h.controller.isBusy)
    }

    @Test("GEMINI-T-07: Stale asynchronous response after cancel is discarded")
    @MainActor
    func testStaleResponseAfterCancelDiscarded() async {
        let h = makeHarness()
        h.ai.delay = .milliseconds(80)

        let task = h.controller.handleActivation(origin: .chord)
        h.controller.cancel()

        _ = await task?.result
        #expect(h.controller.phase == .idle, "Phase must remain idle; late response must be dropped")
    }

    @Test("LIFE-T-03: Close resets phase and retry failure count")
    @MainActor
    func testCloseResetsAll() {
        let h = makeHarness()
        h.controller.close()
        #expect(h.controller.phase == .idle)
        #expect(h.controller.retryFailureCount == 0)
        #expect(h.controller.lastAcquiredText == nil)
    }

    // MARK: - Retry Behavior (LIFE-T-04)

    @Test("LIFE-T-04: Retry resends cached selection without re-reading")
    @MainActor
    func testRetryResendsExistingSelection() async {
        let h = makeHarness()
        // First attempt fails with 503 (server error, retryable, 0s initial cooldown)
        h.ai.resultToReturn = .failure(.server(status: 503))

        let task1 = h.controller.handleActivation(origin: .chord)
        _ = await task1?.result

        #expect(h.textAcquirer.acquireCount == 1)
        #expect(h.ai.respondCount == 1)
        #expect(h.controller.lastAcquiredText != nil)

        guard case .failed(let failure) = h.controller.phase else {
            Issue.record("Expected failed phase, got \(h.controller.phase)")
            return
        }
        #expect(failure.presentation.isRetryable)
        #expect(failure.cooldownSeconds == nil || failure.cooldownSeconds == 0)

        // Second attempt succeeds
        h.ai.resultToReturn = .success(GenerationResult(text: "Recovered answer", isTruncated: false))
        let retryTask = h.controller.retry()
        #expect(retryTask != nil)
        _ = await retryTask?.result

        #expect(h.textAcquirer.acquireCount == 1, "Retry must not re-acquire selection from system")
        #expect(h.ai.respondCount == 2, "Retry must perform second AI request")
        #expect(h.controller.phase == .succeeded(ResponseContent(text: "Recovered answer", isTruncated: false, restoreSkipped: false)))
    }

    // MARK: - Cooldown Behavior & Sleep Injection

    @Test("Retry cooldown ticks down using injected sleep")
    @MainActor
    func testRetryCooldownCountdown() async {
        let sleptDurations = Box<[Duration]>([])
        let h = makeHarness(sleepHandler: { duration in
            sleptDurations.value.append(duration)
        })

        // Rate limit returns 3s cooldown
        h.ai.resultToReturn = .failure(.rateLimited(retryAfter: .seconds(3)))

        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result
        _ = await h.controller.currentCooldownTask?.result

        let oneSecondTicks = sleptDurations.value.filter { $0 == .seconds(1) }
        #expect(oneSecondTicks.count == 3, "Cooldown of 3 seconds must tick three 1-second intervals")
        #expect(sleptDurations.value.contains(.seconds(15)), "Taking longer task must schedule 15s sleep")
    }

    // MARK: - Clipboard Operation & Termination Deferral (LIFE-11)

    @Test("isClipboardOperationInProgress is true only when acquiring with copy fallback enabled")
    @MainActor
    func testClipboardOperationInProgress() {
        let h = makeHarness()
        h.preferences.copyFallbackEnabled = true
        #expect(!h.controller.isClipboardOperationInProgress)

        h.textAcquirer.delay = .milliseconds(100)
        _ = h.controller.handleActivation(origin: .chord)
        #expect(h.controller.isClipboardOperationInProgress)

        h.controller.cancel()
        #expect(!h.controller.isClipboardOperationInProgress)
    }

    // MARK: - Copy Response

    @Test("copyResponse copies text to pasteboard when succeeded")
    @MainActor
    func testCopyResponse() async {
        let h = makeHarness()
        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result

        #expect(h.copiedText.value == nil)
        h.controller.copyResponse()
        #expect(h.copiedText.value == "Here is the AI answer.")
    }

    // MARK: - Test Connection

    @Test("testConnection returns success when responder answers")
    @MainActor
    func testConnectionSuccess() async {
        let h = makeHarness()
        let (success, message) = await h.controller.testConnection()
        #expect(success)
        #expect(message.contains("successful"))
    }

    @Test("testConnection returns failure when API key missing")
    @MainActor
    func testConnectionMissingKey() async {
        let h = makeHarness()
        h.credentials.keyToReturn = nil
        let (success, message) = await h.controller.testConnection()
        #expect(!success)
        #expect(message.contains("No API key"))
    }

    // MARK: - Regression Coverage Audits (M08)

    @Test("Regression: Acquisition failure (emptySelection) transitions to failed with E-SEL-01")
    @MainActor
    func testAcquisitionEmptySelectionFails() async {
        let h = makeHarness()
        h.textAcquirer.resultToReturn = .failure(.emptySelection)

        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result

        guard case .failed(let failure) = h.controller.phase else {
            Issue.record("Expected failed phase, got \(h.controller.phase)")
            return
        }
        #expect(failure.presentation.id == "E-SEL-01")
        #expect(!failure.presentation.isRetryable)
        #expect(h.ai.respondCount == 0)
    }

    @Test("Regression: Acquisition failure (tooLong) transitions to failed with E-SEL-04")
    @MainActor
    func testAcquisitionTooLongFails() async {
        let h = makeHarness()
        h.textAcquirer.resultToReturn = .failure(.tooLong(count: 25_000, limit: 20_000))

        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result

        guard case .failed(let failure) = h.controller.phase else {
            Issue.record("Expected failed phase, got \(h.controller.phase)")
            return
        }
        #expect(failure.presentation.id == "E-SEL-04")
        #expect(!failure.presentation.isRetryable)
        #expect(h.ai.respondCount == 0)
    }

    @Test("Regression: Acquisition failure (secureField) transitions to failed with E-SEL-03")
    @MainActor
    func testAcquisitionSecureFieldFails() async {
        let h = makeHarness()
        h.textAcquirer.resultToReturn = .failure(.secureField)

        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result

        guard case .failed(let failure) = h.controller.phase else {
            Issue.record("Expected failed phase, got \(h.controller.phase)")
            return
        }
        #expect(failure.presentation.id == "E-SEL-03")
        #expect(!failure.presentation.isRetryable)
        #expect(h.ai.respondCount == 0)
    }

    @Test("Regression: Accessibility permission denial and recovery transitions to success")
    @MainActor
    func testPermissionDenialAndRecovery() async {
        let h = makeHarness()
        // 1. Initial denial
        h.permissions.state = .notGranted
        let task1 = h.controller.handleActivation(origin: .chord)
        _ = await task1?.result

        guard case .failed(let failure1) = h.controller.phase else {
            Issue.record("Expected failed phase on initial denial, got \(h.controller.phase)")
            return
        }
        #expect(failure1.presentation.id == "E-ACC-01")

        // 2. User grants permission in System Settings
        h.permissions.state = .granted

        // 3. New activation recovers cleanly
        let task2 = h.controller.handleActivation(origin: .chord)
        _ = await task2?.result

        #expect(h.controller.phase == .succeeded(ResponseContent(text: "Here is the AI answer.", isTruncated: false, restoreSkipped: false)))
        #expect(h.textAcquirer.acquireCount == 1)
        #expect(h.ai.respondCount == 1)
    }

    @Test("Regression: Duplicate retry while busy is rejected (single flight)")
    @MainActor
    func testRetryWhileBusyIsRejected() async {
        let h = makeHarness()
        h.ai.delay = .milliseconds(100)

        // Start normal activation
        let task = h.controller.handleActivation(origin: .chord)
        #expect(h.controller.isBusy)

        // Attempt retry while requesting
        let retryTask = h.controller.retry()
        #expect(retryTask == nil, "Calling retry() while request is in flight must return nil")

        _ = await task?.result
    }

    @Test("Regression: Gemini quota exhaustion transitions to failed with E-API-04 (non-retryable)")
    @MainActor
    func testGeminiQuotaExceededTransitionsToFailed() async {
        let h = makeHarness()
        h.ai.resultToReturn = .failure(.quotaExceeded)

        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result

        guard case .failed(let failure) = h.controller.phase else {
            Issue.record("Expected failed phase, got \(h.controller.phase)")
            return
        }
        #expect(failure.presentation.id == "E-API-04")
        #expect(!failure.presentation.isRetryable)
        #expect(failure.cooldownSeconds == nil)
    }

    @Test("Regression: Gemini rate limited transitions to failed with E-API-03 (retryable)")
    @MainActor
    func testGeminiRateLimitedTransitionsToFailed() async {
        let h = makeHarness()
        h.ai.resultToReturn = .failure(.rateLimited(retryAfter: nil))

        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result

        guard case .failed(let failure) = h.controller.phase else {
            Issue.record("Expected failed phase, got \(h.controller.phase)")
            return
        }
        #expect(failure.presentation.id == "E-API-03")
        #expect(failure.presentation.isRetryable)
    }

    @Test("Regression: Gemini timeout transitions to failed with E-NET-03 (retryable)")
    @MainActor
    func testGeminiTimedOutTransitionsToFailed() async {
        let h = makeHarness()
        h.ai.resultToReturn = .failure(.timedOut)

        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result

        guard case .failed(let failure) = h.controller.phase else {
            Issue.record("Expected failed phase, got \(h.controller.phase)")
            return
        }
        #expect(failure.presentation.id == "E-NET-03")
        #expect(failure.presentation.isRetryable)
    }

    @Test("Regression: Keychain read failure transitions to failed with E-KC-02")
    @MainActor
    func testKeychainReadFailureTransitionsToFailed() async {
        let h = makeHarness()
        h.credentials.readKeyError = .accessDenied

        let task = h.controller.handleActivation(origin: .chord)
        _ = await task?.result

        guard case .failed(let failure) = h.controller.phase else {
            Issue.record("Expected failed phase, got \(h.controller.phase)")
            return
        }
        #expect(failure.presentation.id == "E-KC-02")
        #expect(!failure.presentation.isRetryable)
    }

    @Test("HARDEN-02: ResponseContent reflects accurate restoreSkipped flag from SelectedText")
    @MainActor
    func testResponseContentRestoreSkippedAccurate() async {
        let h = makeHarness()
        h.textAcquirer.resultToReturn = .success(
            SelectedText(
                value: "Fallback text",
                characterCount: 13,
                source: SourceApplication(localizedName: "Terminal", bundleIdentifier: "com.apple.Terminal"),
                method: .clipboard,
                restoreSkipped: false
            )
        )

        let task1 = h.controller.handleActivation(origin: .chord)
        _ = await task1?.result

        guard case .succeeded(let content1) = h.controller.phase else {
            Issue.record("Expected succeeded phase, got \(h.controller.phase)")
            return
        }
        #expect(content1.restoreSkipped == false, "When restore was successful, restoreSkipped must be false")

        // Now test when restore was actually skipped
        h.controller.close()
        h.textAcquirer.resultToReturn = .success(
            SelectedText(
                value: "Fallback text 2",
                characterCount: 15,
                source: SourceApplication(localizedName: "Terminal", bundleIdentifier: "com.apple.Terminal"),
                method: .clipboard,
                restoreSkipped: true
            )
        )

        let task2 = h.controller.handleActivation(origin: .chord)
        _ = await task2?.result

        guard case .succeeded(let content2) = h.controller.phase else {
            Issue.record("Expected succeeded phase, got \(h.controller.phase)")
            return
        }
        #expect(content2.restoreSkipped == true, "When restore was skipped, restoreSkipped must be true")
    }
}

