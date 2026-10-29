import Foundation
import DoomCore
import OSLog

private let logger = Logger(subsystem: "doom", category: "assistant")

public struct SelectionSummary: Equatable, Sendable {
    public let appName: String
    public let characterCount: Int
    public let isTakingLonger: Bool

    public init(appName: String, characterCount: Int, isTakingLonger: Bool = false) {
        self.appName = appName
        self.characterCount = characterCount
        self.isTakingLonger = isTakingLonger
    }
}

public struct ResponseContent: Equatable, Sendable {
    public let text: String
    public let isTruncated: Bool
    public let restoreSkipped: Bool

    public init(text: String, isTruncated: Bool = false, restoreSkipped: Bool = false) {
        self.text = text
        self.isTruncated = isTruncated
        self.restoreSkipped = restoreSkipped
    }
}

public struct FailurePresentation: Equatable, Sendable {
    public let presentation: MessagePresentation
    public let cooldownSeconds: Int?

    public init(presentation: MessagePresentation, cooldownSeconds: Int? = nil) {
        self.presentation = presentation
        self.cooldownSeconds = cooldownSeconds
    }
}

public struct AssistantDependencies {
    public let permissions: any PermissionChecking
    public let credentials: any CredentialStoring
    public let textAcquirer: any TextAcquiring
    public let ai: any AIResponding
    public let preferences: any PreferencesStoring
    public let copyToPasteboard: @MainActor (String) -> Void
    public let sleep: @Sendable (Duration) async throws -> Void

    public init(
        permissions: any PermissionChecking,
        credentials: any CredentialStoring,
        textAcquirer: any TextAcquiring,
        ai: any AIResponding,
        preferences: any PreferencesStoring,
        copyToPasteboard: @escaping @MainActor (String) -> Void,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.permissions = permissions
        self.credentials = credentials
        self.textAcquirer = textAcquirer
        self.ai = ai
        self.preferences = preferences
        self.copyToPasteboard = copyToPasteboard
        self.sleep = sleep
    }
}

@MainActor
@Observable
public final class AssistantController {
    public enum Phase: Equatable, Sendable {
        case idle
        case acquiring
        case requesting(SelectionSummary)
        case succeeded(ResponseContent)
        case failed(FailurePresentation)
    }

    public private(set) var phase: Phase = .idle

    public let dependencies: AssistantDependencies

    public var onPhaseChange: ((Phase) -> Void)?
    public var onShowRequested: (() -> Void)?

    @ObservationIgnored private var activeFlowID: UUID?
    @ObservationIgnored private var activeFlowTask: Task<Void, Never>?
    @ObservationIgnored private var cooldownTask: Task<Void, Never>?
    @ObservationIgnored private var takingLongerTask: Task<Void, Never>?

    @ObservationIgnored public private(set) var lastAcquiredText: SelectedText?
    @ObservationIgnored public private(set) var retryFailureCount: Int = 0

    public var isBusy: Bool {
        switch phase {
        case .acquiring, .requesting:
            return true
        case .idle, .succeeded, .failed:
            return false
        }
    }

    public var isClipboardOperationInProgress: Bool {
        guard case .acquiring = phase else { return false }
        return dependencies.preferences.copyFallbackEnabled
    }

    public var isAcquiring: Bool {
        if case .acquiring = phase { return true }
        return false
    }

    public var currentTask: Task<Void, Never>? {
        activeFlowTask
    }

    public var currentCooldownTask: Task<Void, Never>? {
        cooldownTask
    }

    public init(dependencies: AssistantDependencies) {
        self.dependencies = dependencies
    }

    private func transitionTo(_ newPhase: Phase, flowID: UUID) {
        guard self.activeFlowID == flowID else { return }
        self.phase = newPhase
        self.onPhaseChange?(newPhase)
    }

    @discardableResult
    public func handleActivation(origin: ActivationOrigin) -> Task<Void, Never>? {
        logger.notice("handleActivation received from \(origin == .chord ? "chord" : "menu", privacy: .public)")

        if isBusy {
            logger.notice("activation.ignoredBusy: assistant is already busy in phase \(String(describing: self.phase), privacy: .public)")
            onShowRequested?()
            return nil
        }

        // Clean previous state (INV-4)
        discardContent()

        let flowID = UUID()
        self.activeFlowID = flowID

        // Prerequisite check 1: Accessibility (LIFE-06)
        guard dependencies.permissions.accessibilityState() == .granted else {
            let pres = MessageCatalog.presentation(forPrerequisite: .accessibility)
            transitionTo(.failed(FailurePresentation(presentation: pres)), flowID: flowID)
            onShowRequested?()
            let task = Task { @MainActor in }
            self.activeFlowTask = task
            return task
        }

        // Prerequisite check 2: Privacy notice (LIFE-06)
        guard dependencies.preferences.privacyNoticeAcknowledgedVersion >= PrivacyNoticeView.noticeVersion else {
            let pres = MessageCatalog.presentation(forPrerequisite: .privacyNotice)
            transitionTo(.failed(FailurePresentation(presentation: pres)), flowID: flowID)
            onShowRequested?()
            let task = Task { @MainActor in }
            self.activeFlowTask = task
            return task
        }

        // Synchronous prerequisites passed: enter acquiring and show panel immediately
        transitionTo(.acquiring, flowID: flowID)
        onShowRequested?()

        activeFlowTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Prerequisite check 3: API key in Keychain (LIFE-06)
            let hasKey: Bool
            do {
                hasKey = try await self.dependencies.credentials.hasAPIKey()
            } catch let credError as CredentialStoreError {
                let pres = MessageCatalog.presentation(for: credError)
                self.transitionTo(.failed(FailurePresentation(presentation: pres)), flowID: flowID)
                return
            } catch {
                hasKey = false
            }

            guard hasKey else {
                let pres = MessageCatalog.presentation(forPrerequisite: .apiKey)
                self.transitionTo(.failed(FailurePresentation(presentation: pres)), flowID: flowID)
                return
            }

            guard !Task.isCancelled, self.activeFlowID == flowID else { return }

            await self.runAcquisitionAndRequest(flowID: flowID)
        }
        self.activeFlowTask = task
        return task
    }

    private func runAcquisitionAndRequest(flowID: UUID) async {
        do {
            let selectedText = try await dependencies.textAcquirer.acquireSelection(
                copyFallbackEnabled: dependencies.preferences.copyFallbackEnabled
            )

            guard !Task.isCancelled, self.activeFlowID == flowID else { return }
            self.lastAcquiredText = selectedText
            logger.notice("Successfully acquired selection (\(selectedText.characterCount) chars)")

            await self.performGeminiRequest(for: selectedText, flowID: flowID)
        } catch let error {
            guard !Task.isCancelled, self.activeFlowID == flowID else { return }
            if error == .cancelled {
                self.transitionTo(.idle, flowID: flowID)
                return
            }
            let presentation = MessageCatalog.presentation(for: error, appName: nil)
            self.transitionTo(.failed(FailurePresentation(presentation: presentation)), flowID: flowID)
        }
    }

    private func performGeminiRequest(for text: SelectedText, flowID: UUID) async {
        let appName = text.source.localizedName ?? "this app"
        let summary = SelectionSummary(appName: appName, characterCount: text.characterCount, isTakingLonger: false)
        transitionTo(.requesting(summary), flowID: flowID)

        takingLongerTask?.cancel()
        takingLongerTask = Task { @MainActor [weak self, flowID] in
            do {
                try await self?.dependencies.sleep(.seconds(15))
            } catch {
                return
            }
            guard let self = self, !Task.isCancelled, self.activeFlowID == flowID else { return }
            if case .requesting(let current) = self.phase {
                let updated = SelectionSummary(
                    appName: current.appName,
                    characterCount: current.characterCount,
                    isTakingLonger: true
                )
                self.transitionTo(.requesting(updated), flowID: flowID)
            }
        }

        defer {
            takingLongerTask?.cancel()
        }

        let modelID: ModelID
        if let override = dependencies.preferences.modelIDOverride, let valid = ModelID(validating: override) {
            modelID = valid
        } else {
            modelID = ModelID.default
        }

        do {
            guard let apiKey = try await dependencies.credentials.readAPIKey() else {
                guard !Task.isCancelled, self.activeFlowID == flowID else { return }
                let pres = MessageCatalog.presentation(forPrerequisite: .apiKey)
                transitionTo(.failed(FailurePresentation(presentation: pres)), flowID: flowID)
                return
            }

            let request = GenerationRequest.make(text: text, model: modelID)
            let result = try await executeGeneration(request: request, apiKey: apiKey)

            guard !Task.isCancelled, self.activeFlowID == flowID else {
                logger.notice("Discarding stale or cancelled Gemini response (flowID: \(flowID))")
                return
            }

            self.retryFailureCount = 0
            let content = ResponseContent(
                text: result.text,
                isTruncated: result.isTruncated,
                restoreSkipped: text.restoreSkipped
            )
            transitionTo(.succeeded(content), flowID: flowID)
        } catch let error as GenerationError {
            guard !Task.isCancelled, self.activeFlowID == flowID else { return }
            if error == .cancelled {
                transitionTo(.idle, flowID: flowID)
                return
            }
            handleGenerationFailure(error, modelID: modelID.rawValue, flowID: flowID)
        } catch let error as CredentialStoreError {
            guard !Task.isCancelled, self.activeFlowID == flowID else { return }
            let pres = MessageCatalog.presentation(for: error)
            transitionTo(.failed(FailurePresentation(presentation: pres)), flowID: flowID)
        } catch {
            guard !Task.isCancelled, self.activeFlowID == flowID else { return }
            let pres = MessageCatalog.presentation(for: .server(status: 500))
            transitionTo(.failed(FailurePresentation(presentation: pres)), flowID: flowID)
        }
    }

    private func executeGeneration(request: GenerationRequest, apiKey: APIKey) async throws(GenerationError) -> GenerationResult {
        // R-ONE-CALLSITE: This is the ONLY call site of AIResponding.respond in the entire codebase
        try await dependencies.ai.respond(to: request, apiKey: apiKey)
    }

    private func handleGenerationFailure(_ error: GenerationError, modelID: String, flowID: UUID) {
        guard self.activeFlowID == flowID else { return }
        retryFailureCount += 1
        let cooldown = RetryCooldownPolicy.cooldown(for: error, failureCount: retryFailureCount)
        let presentation = MessageCatalog.presentation(for: error, modelID: modelID)

        if let cd = cooldown, cd > 0 {
            cooldownTask?.cancel()
            cooldownTask = Task { @MainActor [weak self, flowID] in
                var remaining = cd
                while remaining > 0 {
                    guard let self = self, !Task.isCancelled, self.activeFlowID == flowID else { return }
                    self.transitionTo(
                        .failed(FailurePresentation(presentation: presentation, cooldownSeconds: remaining)),
                        flowID: flowID
                    )
                    do {
                        try await self.dependencies.sleep(.seconds(1))
                    } catch {
                        return
                    }
                    remaining -= 1
                }
                guard let self = self, !Task.isCancelled, self.activeFlowID == flowID else { return }
                self.transitionTo(
                    .failed(FailurePresentation(presentation: presentation, cooldownSeconds: nil)),
                    flowID: flowID
                )
            }
        } else {
            transitionTo(
                .failed(FailurePresentation(presentation: presentation, cooldownSeconds: nil)),
                flowID: flowID
            )
        }
    }

    @discardableResult
    public func retry() -> Task<Void, Never>? {
        guard case .failed(let failure) = phase,
              failure.presentation.isRetryable,
              failure.cooldownSeconds == nil || failure.cooldownSeconds == 0 else {
            return nil
        }

        guard let text = lastAcquiredText else {
            return handleActivation(origin: .menu)
        }

        cooldownTask?.cancel()
        let flowID = UUID()
        self.activeFlowID = flowID

        activeFlowTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.performGeminiRequest(for: text, flowID: flowID)
        }
        self.activeFlowTask = task
        return task
    }

    public func cancel() {
        activeFlowTask?.cancel()
        cooldownTask?.cancel()
        takingLongerTask?.cancel()
        activeFlowID = nil
        lastAcquiredText = nil
        phase = .idle
        onPhaseChange?(.idle)
    }

    public func close() {
        cancel()
        retryFailureCount = 0
    }

    public func copyResponse() {
        guard case .succeeded(let content) = phase else { return }
        dependencies.copyToPasteboard(content.text)
    }

    private func discardContent() {
        lastAcquiredText = nil
        retryFailureCount = 0
        takingLongerTask?.cancel()
        cooldownTask?.cancel()
        activeFlowTask?.cancel()
        activeFlowID = nil
    }

    public func testConnection() async -> (Bool, String) {
        let selectedModel: ModelID
        if let override = dependencies.preferences.modelIDOverride, let valid = ModelID(validating: override) {
            selectedModel = valid
        } else {
            selectedModel = ModelID.default
        }

        do {
            guard let key = try await dependencies.credentials.readAPIKey() else {
                return (false, "No API key found in Keychain.")
            }
            let pingText = SelectedText(
                value: "ping",
                characterCount: 4,
                source: SourceApplication(localizedName: "DOOM", bundleIdentifier: nil),
                method: .accessibility
            )
            let request = GenerationRequest(
                text: pingText,
                model: selectedModel,
                systemInstruction: "Respond with the word pong only.",
                maxOutputTokens: GeminiConfiguration.maxOutputTokens,
                thinkingLevel: .low
            )
            let result = try await executeGeneration(request: request, apiKey: key)
            if !result.text.isEmpty {
                return (true, "Connection successful! Gemini answered in stateless mode.")
            } else {
                return (false, "Gemini returned an empty response.")
            }
        } catch let genError as GenerationError {
            let pres = MessageCatalog.presentation(for: genError, modelID: selectedModel.rawValue)
            return (false, "\(pres.title): \(pres.message)")
        } catch let credError as CredentialStoreError {
            let pres = MessageCatalog.presentation(for: credError)
            return (false, "\(pres.title): \(pres.message)")
        } catch {
            return (false, "Unexpected error: \(error.localizedDescription)")
        }
    }
}
