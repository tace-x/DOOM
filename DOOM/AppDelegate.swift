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
    let assistantController: AssistantController
    let panelController: PanelController
    let shortcutMonitor: SystemShortcutMonitor
    let permissionChecker: SystemPermissionChecker
    let textAcquirer: any TextAcquiring
    let preferences: any PreferencesStoring
    let credentialStore: any CredentialStoring
    let geminiClient: any AIResponding

    @ObservationIgnored var openWindowAction: (() -> Void)?
    @ObservationIgnored private var lastPanelToggleInstant: ContinuousClock.Instant = .now - .seconds(10)
    private let panelToggleDebounceDuration: Duration = .milliseconds(250)
    @ObservationIgnored private var lastActivationInstant: ContinuousClock.Instant = .now - .seconds(10)
    private let activationDebounceDuration: Duration = .milliseconds(250)

    @ObservationIgnored private let lifecycleLogger: Logger
    @ObservationIgnored private let configLogger: Logger

    var isPanelVisible: Bool {
        panelController.isVisible
    }

    var isAcquiring: Bool {
        assistantController.isAcquiring
    }

    var menuStatusText: String {
        MenuStatusFormatter.statusText(
            phase: assistantController.phase,
            isPanelVisible: panelController.isVisible,
            isPrivacyModeEnabled: panelController.isPrivacyModeEnabled,
            fallbackText: mainWindowModel.statusText
        )
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
        let acquirer = SystemTextAcquirer(
            permissions: perms,
            ownBundleIdentifier: loadedContext.configuration.bundleIdentifier
        )
        self.textAcquirer = acquirer

        let monitor = SystemShortcutMonitor(permissions: perms)
        self.shortcutMonitor = monitor

        let keyStore = KeychainCredentialStore(
            service: loadedContext.configuration.bundleIdentifier,
            account: "gemini-api-key"
        )
        self.credentialStore = keyStore
        let client = GeminiClient()
        self.geminiClient = client

        let assistantDeps = AssistantDependencies(
            permissions: perms,
            credentials: keyStore,
            textAcquirer: acquirer,
            ai: client,
            preferences: prefs,
            copyToPasteboard: { text in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            },
            sleep: { duration in
                try await Task.sleep(for: duration)
            }
        )
        let assistant = AssistantController(dependencies: assistantDeps)
        self.assistantController = assistant

        let controller = PanelController(assistant: assistant)
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
            testConnectionAction: { [weak assistant] in
                guard let assistant = assistant else {
                    return (false, "Service unavailable")
                }
                return await assistant.testConnection()
            },
            isPrivacyModeEnabledProvider: { [weak controller] in
                controller?.isPrivacyModeEnabled ?? false
            },
            setPrivacyModeAction: { [weak controller] enabled in
                controller?.setPrivacyMode(enabled)
            },
            setHideLocallyFallbackAction: { [weak controller] enabled in
                controller?.setHideLocallyFallback(enabled)
            },
            selfTestAction: { [weak controller] in
                guard let controller = controller else {
                    return .unavailable(reason: "Overlay controller not available")
                }
                guard CGPreflightScreenCaptureAccess() else {
                    return .unavailable(reason: "Screen Recording permission not granted (required for self-test)")
                }
                return await controller.runSelfTest(osVersion: ProcessInfo.processInfo.operatingSystemVersionString)
            }
        )

        self.mainWindowModel = MainWindowModel(context: loadedContext, dependencies: dependencies)

        super.init()

        controller.onOpenSettingsHandler = { [weak self] in
            self?.openMainWindow()
        }
        controller.onReviewPrivacyHandler = { [weak self] in
            self?.openPrivacyNotice()
        }
        controller.onPrivacyModeChange = { [weak self] enabled in
            guard let self = self else { return }
            if self.mainWindowModel.isPrivacyModeEnabled != enabled {
                self.mainWindowModel.isPrivacyModeEnabled = enabled
            }
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
            handleAskSelection(origin: origin)
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
        if assistantController.isAcquiring, let task = assistantController.currentTask {
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

    func handleAskSelection(origin: ActivationOrigin = .menu) {
        let now = ContinuousClock.now
        guard now - lastActivationInstant >= activationDebounceDuration else {
            lifecycleLogger.notice("Ignoring duplicate activation event within debounce window")
            return
        }
        lastActivationInstant = now
        assistantController.handleActivation(origin: origin)
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
