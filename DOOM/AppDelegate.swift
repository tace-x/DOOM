import AppKit
import SwiftUI
import DoomCore
import DoomServices
import DoomFeatures
import OSLog

private struct AppPreferences: PreferencesStoring {
    private let privacyKey = "privacyNoticeAcknowledgedVersion"
    private let copyFallbackKey = "copyFallbackEnabled"
    private let modelOverrideKey = "modelIDOverride"

    var privacyNoticeAcknowledgedVersion: Int {
        get { UserDefaults.standard.integer(forKey: privacyKey) }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: privacyKey) }
    }

    var copyFallbackEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: copyFallbackKey) }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: copyFallbackKey) }
    }

    var modelIDOverride: String? {
        get { UserDefaults.standard.string(forKey: modelOverrideKey) }
        nonmutating set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: modelOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: modelOverrideKey)
            }
        }
    }
}

@MainActor
@Observable
final class AppDelegate: NSObject, NSApplicationDelegate {
    let context: AppContext
    let mainWindowModel: MainWindowModel
    let panelController: PanelController
    let shortcutMonitor: SystemShortcutMonitor
    let permissionChecker: SystemPermissionChecker
    let textAcquirer: any TextAcquiring
    let preferences: any PreferencesStoring
    let credentialStore: any CredentialStoring
    let geminiClient: any AIResponding

    @ObservationIgnored var openWindowAction: (() -> Void)?
    @ObservationIgnored private var currentAcquisitionTask: Task<Void, Never>?
    @ObservationIgnored private var cooldownTask: Task<Void, Never>?
    @ObservationIgnored private var lastAcquiredText: SelectedText?
    @ObservationIgnored private var retryFailureCount: Int = 0
    @ObservationIgnored private(set) var isAcquiring: Bool = false
    @ObservationIgnored private var activeRequestID: UUID?
    @ObservationIgnored private var lastPanelToggleInstant: ContinuousClock.Instant = .now - .seconds(10)
    private let panelToggleDebounceDuration: Duration = .milliseconds(250)

    @ObservationIgnored private let lifecycleLogger: Logger
    @ObservationIgnored private let configLogger: Logger

    var isPanelVisible: Bool {
        panelController.isVisible
    }

    var menuStatusText: String {
        switch panelController.state {
        case .acquiring, .requesting:
            return "Working…"
        case .succeeded:
            if !panelController.isVisible {
                return "Response ready"
            }
            return mainWindowModel.statusText
        default:
            return mainWindowModel.statusText
        }
    }

    override init() {
        let loadedContext = AppContext.make(
            infoDictionary: Bundle.main.infoDictionary ?? [:],
            arguments: ProcessInfo.processInfo.arguments
        )
        self.context = loadedContext

        // LIFE-14: Single-instance guard (skipped for diagnose and smoke-test CLI invocations)
        if !loadedContext.launchOptions.isDiagnose && !loadedContext.launchOptions.isSmokeTest {
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let isDuplicate = SingleInstancePolicy.checkAndHandleDuplicate(
                bundleIdentifier: loadedContext.configuration.bundleIdentifier,
                currentPID: currentPID
            )
            if isDuplicate {
                exit(0)
            }
        }

        self.lifecycleLogger = Logger(category: .lifecycle, configuration: loadedContext.configuration)
        self.configLogger = Logger(category: .configuration, configuration: loadedContext.configuration)

        let prefs = AppPreferences()
        self.preferences = prefs
        let perms = SystemPermissionChecker()
        self.permissionChecker = perms
        self.textAcquirer = SystemTextAcquirer(permissions: perms)

        let monitor = SystemShortcutMonitor(permissions: perms)
        self.shortcutMonitor = monitor

        let keyStore = KeychainCredentialStore(
            service: loadedContext.configuration.bundleIdentifier,
            account: "gemini-api-key"
        )
        self.credentialStore = keyStore
        let client = GeminiClient()
        self.geminiClient = client

        let controller = PanelController()
        self.panelController = controller

        let dependencies = MainWindowModel.Dependencies(
            permissions: perms,
            preferences: prefs,
            hasAPIKeyProvider: {
                (try? await keyStore.hasAPIKey()) ?? false
            },
            saveAPIKeyAction: { key in
                guard let validated = APIKey(validating: key) else {
                    return .failure(.invalidKeyFormat)
                }
                do {
                    try await keyStore.saveAPIKey(validated)
                    return .success(())
                } catch let error as CredentialStoreError {
                    return .failure(error)
                } catch {
                    return .failure(.unexpectedStatus(-1))
                }
            },
            deleteAPIKeyAction: {
                do {
                    try await keyStore.deleteAPIKey()
                    return true
                } catch {
                    return false
                }
            },
            shortcutStatusProvider: { [weak monitor] in
                monitor?.status ?? ShortcutStatus(
                    activation: .needsAccessibility,
                    panelToggle: .available
                )
            },
            restartAction: {
                NSApp.relaunch()
            },
            testConnectionAction: { [weak keyStore, weak client] in
                guard let keyStore = keyStore, let client = client else {
                    return (false, "Service unavailable")
                }
                let selectedModel: ModelID
                if let override = prefs.modelIDOverride, let valid = ModelID(validating: override) {
                    selectedModel = valid
                } else {
                    selectedModel = ModelID.default
                }
                do {
                    guard let key = try await keyStore.readAPIKey() else {
                        return (false, "No API key found in Keychain.")
                    }
                    let pingText = SelectedText(
                        value: "ping",
                        characterCount: 4,
                        source: SourceApplication(localizedName: "DOOM", bundleIdentifier: "com.tace.doom"),
                        method: .accessibility
                    )
                    let request = GenerationRequest(
                        text: pingText,
                        model: selectedModel,
                        systemInstruction: "Respond with the word pong only.",
                        maxOutputTokens: GeminiConfiguration.maxOutputTokens,
                        thinkingLevel: .low
                    )
                    let result = try await client.respond(to: request, apiKey: key)
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
        )

        self.mainWindowModel = MainWindowModel(context: loadedContext, dependencies: dependencies)

        super.init()

        controller.onCancelHandler = { [weak self] in
            self?.activeRequestID = nil
            self?.currentAcquisitionTask?.cancel()
            self?.cooldownTask?.cancel()
            self?.isAcquiring = false
        }
        controller.onCloseHandler = { [weak self] in
            self?.activeRequestID = nil
            self?.currentAcquisitionTask?.cancel()
            self?.cooldownTask?.cancel()
            self?.lastAcquiredText = nil
            self?.isAcquiring = false
            self?.panelController.updateState(.empty)
        }
        controller.onCopyHandler = {
            // Handled directly in PanelView per R-PASTEBOARD
        }
        controller.onRetryHandler = { [weak self] in
            self?.handleRetry()
        }
        controller.onOpenSettingsHandler = { [weak self] in
            self?.openMainWindow()
        }
        controller.onReviewPrivacyHandler = { [weak self] in
            self?.openPrivacyNotice()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        lifecycleLogger.info("Application did finish launching")

        shortcutMonitor.start()
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            for await event in self.shortcutMonitor.events {
                self.handleShortcutEvent(event)
            }
        }

        if let issue = context.configurationIssue {
            configLogger.warning("Running with degraded configuration due to issue with key: \(issue.key, privacy: .public)")
        }

        if context.launchOptions.isDiagnose {
            Task { @MainActor in
                await self.runDiagnoseRoutine()
                NSApp.terminate(nil)
            }
            return
        }

        if context.launchOptions.isSmokeTest {
            openMainWindow()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                let hasVisibleWindow = NSApp.windows.contains { $0.isVisible }
                if hasVisibleWindow {
                    FileHandle.standardOutput.write(Data("DOOM_SMOKE_OK\n".utf8))
                    NSApp.terminate(nil)
                } else {
                    FileHandle.standardError.write(Data("DOOM_SMOKE_FAIL: No visible window\n".utf8))
                    exit(EXIT_FAILURE)
                }
            }
        } else if !mainWindowModel.isSetupComplete {
            // LIFE-01: First launch or setup needed opens the main window
            openMainWindow()
        }
    }

    private func runDiagnoseRoutine() async {
        let stdout = FileHandle.standardOutput
        let writeLine = { (str: String) in
            stdout.write(Data((str + "\n").utf8))
        }
        writeLine("=== DOOM GEMINI DIAGNOSTICS ===")
        writeLine("Timestamp: \(Date().ISO8601Format())")

        do {
            if let _ = try await credentialStore.readAPIKey() {
                writeLine("DIAG_KEY: Key present in Keychain")
            } else {
                writeLine("DIAG_KEY: No API key found in Keychain")
                writeLine("=== END DIAGNOSTICS ===")
                return
            }
        } catch {
            writeLine("DIAG_KEY_ERROR: Failed to read key: \(error.localizedDescription)")
            writeLine("=== END DIAGNOSTICS ===")
            return
        }

        let configuredModel = preferences.modelIDOverride ?? ModelID.default.rawValue
        writeLine("DIAG_CONFIGURED_MODEL: \(configuredModel)")

        writeLine("DIAG_STEP: Executing testConnection()...")
        let t0 = Date()
        await mainWindowModel.testConnection()
        let elapsed = Date().timeIntervalSince(t0)
        let success = mainWindowModel.isTestConnectionSuccess
        let msg = mainWindowModel.testConnectionResult ?? "nil"

        if let diag = (geminiClient as? GeminiClient)?.lastDiagnostics {
            writeLine("DIAG_REQUEST_START: \(diag.startTimestamp)")
            writeLine("DIAG_REQUEST_COMPLETION: \(diag.completionTimestamp)")
            writeLine("DIAG_ENDPOINT: \(diag.endpoint)")
            writeLine("DIAG_OPERATION: \(diag.operation)")
            writeLine("DIAG_MODEL: \(diag.model)")
            writeLine("DIAG_HTTP_STATUS: \(diag.httpStatusCode.map(String.init) ?? "none")")
            writeLine("DIAG_PARSED_GOOGLE_ERROR: \(diag.parsedGoogleErrorFormat)")
            writeLine("DIAG_PROVIDER_CODE: \(diag.sanitizedProviderErrorCode ?? "none")")
            writeLine("DIAG_PROVIDER_MESSAGE: \(diag.sanitizedProviderErrorMessage ?? "none")")
            writeLine("DIAG_INTERNAL_ERROR: \(diag.internalErrorCase)")
        }

        writeLine("DIAG_RESULT: success=\(success), duration=\(String(format: "%.3f", elapsed))s, message=\(msg)")
        writeLine("=== END DIAGNOSTICS ===")
    }

    func handleShortcutEvent(_ event: ShortcutEvent) {
        switch event {
        case .activate(let origin):
            lifecycleLogger.notice("Shortcut event received: activate (origin=\(origin == .chord ? "chord" : "menu", privacy: .public))")
            handleAskSelection()
        case .togglePanel:
            lifecycleLogger.notice("Shortcut event received: togglePanel")
            togglePanel()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // UI-21: Closing main window keeps DOOM running
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // LIFE-11: Quit during acquisition/fallback defers until restore completes
        if isAcquiring, let task = currentAcquisitionTask {
            lifecycleLogger.notice("Termination requested while acquisition in flight; deferring termination until finished")
            Task {
                _ = await task.result
                NSApp.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // LIFE-04: Reopen opens the main window
        openMainWindow()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        shortcutMonitor.refreshAfterPermissionChange()
        Task {
            await mainWindowModel.refresh()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutMonitor.stop()
        lifecycleLogger.info("Application will terminate")
    }

    @ObservationIgnored private var nativeMainWindow: NSWindow?

    func openMainWindow() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { ($0.title == "DOOM" || $0.identifier?.rawValue == "main") && !($0 is DoomPanel) }) {
            window.makeKeyAndOrderFront(nil)
            return
        }

        if let window = nativeMainWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DOOM"
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.minSize = NSSize(width: 560, height: 480)
        window.maxSize = NSSize(width: 560, height: CGFloat.greatestFiniteMagnitude)
        window.center()
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        let hosting = NSHostingView(rootView: MainWindowView(model: mainWindowModel))
        window.contentView = hosting
        self.nativeMainWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    func openPrivacyNotice() {
        openMainWindow()
        mainWindowModel.isPrivacySheetPresented = true
    }

    func togglePanel() {
        let now = ContinuousClock.now
        guard now - lastPanelToggleInstant >= panelToggleDebounceDuration else {
            lifecycleLogger.notice("Ignoring duplicate panel toggle within debounce window")
            return
        }
        lastPanelToggleInstant = now
        panelController.toggle()
    }

    func handleAskSelection() {
        // LIFE-06: Prerequisite order: Accessibility -> privacy -> key
        guard permissionChecker.accessibilityState() == .granted else {
            panelController.updateState(.failed(
                presentation: MessageCatalog.presentation(forPrerequisite: .accessibility),
                cooldownSeconds: nil
            ))
            panelController.show()
            return
        }

        guard preferences.privacyNoticeAcknowledgedVersion >= PrivacyNoticeView.noticeVersion else {
            panelController.updateState(.failed(
                presentation: MessageCatalog.presentation(forPrerequisite: .privacyNotice),
                cooldownSeconds: nil
            ))
            panelController.show()
            return
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let hasKey = (try? await self.credentialStore.hasAPIKey()) ?? false
            guard hasKey else {
                self.panelController.updateState(.failed(
                    presentation: MessageCatalog.presentation(forPrerequisite: .apiKey),
                    cooldownSeconds: nil
                ))
                self.panelController.show()
                return
            }

            self.startAcquisitionAndRequest()
        }
    }

    private func startAcquisitionAndRequest() {
        if isAcquiring {
            if !panelController.isVisible {
                panelController.show()
            }
            return
        }

        let requestID = UUID()
        self.activeRequestID = requestID
        isAcquiring = true
        retryFailureCount = 0
        cooldownTask?.cancel()
        panelController.updateState(.acquiring)
        panelController.show()

        currentAcquisitionTask?.cancel()
        currentAcquisitionTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            do {
                let selectedText = try await self.textAcquirer.acquireSelection(
                    copyFallbackEnabled: self.preferences.copyFallbackEnabled
                )
                guard !Task.isCancelled, self.activeRequestID == requestID else { return }
                self.lastAcquiredText = selectedText
                self.lifecycleLogger.notice("Successfully acquired selection (\(selectedText.characterCount) chars)")

                await self.performGeminiRequest(for: selectedText, requestID: requestID)
            } catch let error as TextAcquisitionError {
                guard !Task.isCancelled, self.activeRequestID == requestID else { return }
                self.isAcquiring = false
                if error != .cancelled {
                    let frontApp = NSWorkspace.shared.frontmostApplication
                    let presentation = MessageCatalog.presentation(for: error, appName: frontApp?.localizedName)
                    self.panelController.updateState(.failed(presentation: presentation, cooldownSeconds: nil))
                }
            } catch {
                guard !Task.isCancelled, self.activeRequestID == requestID else { return }
                self.isAcquiring = false
                let presentation = MessageCatalog.presentation(for: .unsupported(reason: "unexpected"))
                self.panelController.updateState(.failed(presentation: presentation, cooldownSeconds: nil))
            }
        }
    }

    private func handleRetry() {
        guard let text = lastAcquiredText else {
            handleAskSelection()
            return
        }
        let requestID = UUID()
        self.activeRequestID = requestID
        cooldownTask?.cancel()

        currentAcquisitionTask?.cancel()
        currentAcquisitionTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.performGeminiRequest(for: text, requestID: requestID)
        }
    }

    private func performGeminiRequest(for text: SelectedText, requestID: UUID) async {
        isAcquiring = true
        let appName = text.source.localizedName ?? "this app"
        panelController.updateState(.requesting(
            appName: appName,
            characterCount: text.characterCount,
            isTakingLonger: false
        ))

        let takingLongerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled, let self = self, self.activeRequestID == requestID, case .requesting(let app, let count, _) = self.panelController.state {
                self.panelController.updateState(.requesting(appName: app, characterCount: count, isTakingLonger: true))
            }
        }

        defer {
            takingLongerTask.cancel()
            if self.activeRequestID == requestID {
                self.isAcquiring = false
            }
        }

        let modelID: ModelID
        if let override = self.preferences.modelIDOverride, let valid = ModelID(validating: override) {
            modelID = valid
        } else {
            modelID = ModelID.default
        }

        do {
            guard let apiKey = try await self.credentialStore.readAPIKey() else {
                guard !Task.isCancelled, self.activeRequestID == requestID else { return }
                self.panelController.updateState(.failed(
                    presentation: MessageCatalog.presentation(forPrerequisite: .apiKey),
                    cooldownSeconds: nil
                ))
                return
            }

            let request = GenerationRequest.make(text: text, model: modelID)
            let result = try await self.geminiClient.respond(to: request, apiKey: apiKey)

            guard !Task.isCancelled, self.activeRequestID == requestID else {
                self.lifecycleLogger.notice("Discarding stale or cancelled Gemini response (requestID: \(requestID))")
                return
            }

            self.retryFailureCount = 0
            self.panelController.updateState(.succeeded(
                text: result.text,
                isTruncated: result.isTruncated,
                restoreSkipped: text.method == .clipboard
            ))
        } catch let error as GenerationError {
            guard !Task.isCancelled, self.activeRequestID == requestID else { return }
            self.handleGenerationFailure(error, modelID: modelID.rawValue, requestID: requestID)
        } catch let error as CredentialStoreError {
            guard !Task.isCancelled, self.activeRequestID == requestID else { return }
            let presentation = MessageCatalog.presentation(for: error)
            self.panelController.updateState(.failed(presentation: presentation, cooldownSeconds: nil))
        } catch {
            guard !Task.isCancelled, self.activeRequestID == requestID else { return }
            let presentation = MessageCatalog.presentation(for: .server(status: 500))
            self.panelController.updateState(.failed(presentation: presentation, cooldownSeconds: nil))
        }
    }

    private func handleGenerationFailure(_ error: GenerationError, modelID: String, requestID: UUID) {
        guard self.activeRequestID == requestID else { return }
        retryFailureCount += 1
        let cooldown = RetryCooldownPolicy.cooldown(for: error, failureCount: retryFailureCount)
        let presentation = MessageCatalog.presentation(for: error, modelID: modelID)

        if let cd = cooldown, cd > 0 {
            cooldownTask?.cancel()
            cooldownTask = Task { @MainActor [weak self] in
                var remaining = cd
                while remaining > 0 {
                    guard let self = self, !Task.isCancelled, self.activeRequestID == requestID else { return }
                    self.panelController.updateState(.failed(presentation: presentation, cooldownSeconds: remaining))
                    try? await Task.sleep(for: .seconds(1))
                    remaining -= 1
                }
                guard let self = self, !Task.isCancelled, self.activeRequestID == requestID else { return }
                self.panelController.updateState(.failed(presentation: presentation, cooldownSeconds: 0))
            }
        } else {
            panelController.updateState(.failed(presentation: presentation, cooldownSeconds: cooldown))
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

private extension NSApplication {
    func relaunch() {
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: NSWorkspace.OpenConfiguration())
        terminate(nil)
    }
}
