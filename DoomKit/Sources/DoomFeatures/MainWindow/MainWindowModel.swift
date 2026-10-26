import Foundation
import SwiftUI
import DoomCore

@MainActor
@Observable
public final class MainWindowModel {
    public enum Status: Equatable, Sendable {
        case ready
        case setupNeeded
        case degraded
    }

    public struct Dependencies: Sendable {
        public let permissions: any PermissionChecking
        public let preferences: any PreferencesStoring
        public let hasAPIKeyProvider: @Sendable () async -> Bool
        public let saveAPIKeyAction: @Sendable (String) async -> Result<Void, CredentialStoreError>
        public let deleteAPIKeyAction: @Sendable () async -> Bool
        public let shortcutStatusProvider: @MainActor () -> ShortcutStatus
        public let restartAction: @MainActor () -> Void
        public let testConnectionAction: @Sendable () async -> (success: Bool, message: String)

        public init(
            permissions: any PermissionChecking,
            preferences: any PreferencesStoring,
            hasAPIKeyProvider: @escaping @Sendable () async -> Bool,
            saveAPIKeyAction: @escaping @Sendable (String) async -> Result<Void, CredentialStoreError>,
            deleteAPIKeyAction: @escaping @Sendable () async -> Bool,
            shortcutStatusProvider: @escaping @MainActor () -> ShortcutStatus = {
                ShortcutStatus(
                    activation: .active,
                    panelToggle: .available
                )
            },
            restartAction: @escaping @MainActor () -> Void = {},
            testConnectionAction: @escaping @Sendable () async -> (success: Bool, message: String) = {
                (false, "Not configured")
            }
        ) {
            self.permissions = permissions
            self.preferences = preferences
            self.hasAPIKeyProvider = hasAPIKeyProvider
            self.saveAPIKeyAction = saveAPIKeyAction
            self.deleteAPIKeyAction = deleteAPIKeyAction
            self.shortcutStatusProvider = shortcutStatusProvider
            self.restartAction = restartAction
            self.testConnectionAction = testConnectionAction
        }
    }

    public let title: String
    public let versionText: String
    public let phaseNote: String

    public private(set) var status: Status = .ready
    public private(set) var statusText: String = "Ready"

    public private(set) var isAccessibilityGranted: Bool = false
    public private(set) var hasAPIKey: Bool = false
    public private(set) var isPrivacyReviewed: Bool = false

    public var apiKeyInput: String = ""
    public private(set) var apiKeyStatusMessage: String?
    public private(set) var isSavingKey: Bool = false

    public private(set) var isTestingConnection: Bool = false
    public private(set) var testConnectionResult: String?
    public private(set) var isTestConnectionSuccess: Bool = false

    public var modelInput: String = ModelID.default.rawValue
    public private(set) var modelError: String?

    public var copyFallbackEnabled: Bool = false
    public var isPrivacySheetPresented: Bool = false
    public var isRemoveKeyAlertPresented: Bool = false

    public private(set) var shortcutStatus: ShortcutStatus

    private let context: AppContext
    private let dependencies: Dependencies

    public init(context: AppContext, dependencies: Dependencies) {
        self.context = context
        self.dependencies = dependencies
        self.title = context.configuration.displayName
        self.versionText = "Version \(context.configuration.version) (\(context.configuration.build))"
        self.phaseNote = "DOOM is an independent project and is not affiliated with or endorsed by Marvel, id Software, or Google."

        self.copyFallbackEnabled = dependencies.preferences.copyFallbackEnabled
        self.isPrivacyReviewed = dependencies.preferences.privacyNoticeAcknowledgedVersion >= PrivacyNoticeView.noticeVersion
        if let storedModel = dependencies.preferences.modelIDOverride {
            self.modelInput = storedModel
        } else {
            self.modelInput = ModelID.default.rawValue
        }

        self.shortcutStatus = dependencies.shortcutStatusProvider()

        if context.configurationIssue != nil {
            self.status = .degraded
            self.statusText = "DOOM is running with default settings because its app information is incomplete."
        } else {
            updateStatus()
        }
    }

    public func refresh() async {
        // Refresh permissions and credentials without timers (UI_SPECIFICATION §4.5)
        let perm = dependencies.permissions.accessibilityState()
        self.isAccessibilityGranted = (perm == .granted)

        self.hasAPIKey = await dependencies.hasAPIKeyProvider()
        self.isPrivacyReviewed = dependencies.preferences.privacyNoticeAcknowledgedVersion >= PrivacyNoticeView.noticeVersion
        self.copyFallbackEnabled = dependencies.preferences.copyFallbackEnabled
        self.shortcutStatus = dependencies.shortcutStatusProvider()

        updateStatus()
    }

    private func updateStatus() {
        if context.configurationIssue != nil {
            self.status = .degraded
            self.statusText = "DOOM is running with default settings because its app information is incomplete."
            return
        }

        if isAccessibilityGranted && hasAPIKey && isPrivacyReviewed {
            self.status = .ready
            self.statusText = "Ready"
        } else {
            self.status = .setupNeeded
            self.statusText = "Setup needed"
        }
    }

    public var isSetupComplete: Bool {
        isAccessibilityGranted && hasAPIKey && isPrivacyReviewed
    }

    public func requestAccessibility() {
        dependencies.permissions.requestAccessibility()
    }

    public func openAccessibilitySettings() {
        dependencies.permissions.openAccessibilitySettings()
    }

    public func saveAPIKey(_ keyText: String) async {
        let trimmed = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSavingKey = true
        let result = await dependencies.saveAPIKeyAction(trimmed)
        isSavingKey = false

        switch result {
        case .success:
            self.hasAPIKey = true
            self.apiKeyInput = ""
            self.apiKeyStatusMessage = "Saved in Keychain"
        case .failure(let error):
            self.apiKeyStatusMessage = MessageCatalog.presentation(for: error).message
        }
        updateStatus()
    }

    public func removeAPIKey() async {
        let success = await dependencies.deleteAPIKeyAction()
        if success {
            self.hasAPIKey = false
            self.apiKeyInput = ""
            self.apiKeyStatusMessage = nil
            self.testConnectionResult = nil
        }
        updateStatus()
    }

    public func testConnection() async {
        guard hasAPIKey else { return }
        guard !isTestingConnection else { return }
        isTestingConnection = true
        testConnectionResult = nil
        defer {
            isTestingConnection = false
        }
        let trimmed = modelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if let _ = ModelID(validating: trimmed) {
                self.modelError = nil
                self.modelInput = trimmed
                dependencies.preferences.modelIDOverride = (trimmed == ModelID.default.rawValue) ? nil : trimmed
            } else {
                self.modelError = MessageCatalog.presentation(forInvalidModel: ()).message
                isTestConnectionSuccess = false
                testConnectionResult = "Invalid model identifier: \"\(trimmed)\""
                return
            }
        }
        let (success, message) = await dependencies.testConnectionAction()
        isTestConnectionSuccess = success
        testConnectionResult = message
    }

    public func acknowledgePrivacyNotice() {
        dependencies.preferences.privacyNoticeAcknowledgedVersion = PrivacyNoticeView.noticeVersion
        self.isPrivacyReviewed = true
        self.isPrivacySheetPresented = false
        updateStatus()
    }

    public func setCopyFallback(_ enabled: Bool) {
        dependencies.preferences.copyFallbackEnabled = enabled
        self.copyFallbackEnabled = enabled
    }

    public func setModel(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = ModelID(rawValue: trimmed)
        if model.isValid {
            self.modelError = nil
            self.modelInput = trimmed
            dependencies.preferences.modelIDOverride = (trimmed == ModelID.default.rawValue) ? nil : trimmed
        } else {
            self.modelError = MessageCatalog.presentation(forInvalidModel: ()).message
        }
    }

    public func resetModel() {
        self.modelInput = ModelID.default.rawValue
        self.modelError = nil
        dependencies.preferences.modelIDOverride = nil
    }

    public func restart() {
        dependencies.restartAction()
    }
}
