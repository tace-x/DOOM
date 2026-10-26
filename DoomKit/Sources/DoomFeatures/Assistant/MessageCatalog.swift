import Foundation
import DoomCore

public enum PanelAction: Equatable, Sendable {
    case close
    case retry
    case openSettings
    case reviewPrivacy
    case grantAccess

    public var title: String {
        switch self {
        case .close: return "Close"
        case .retry: return "Retry"
        case .openSettings: return "Open DOOM Settings"
        case .reviewPrivacy: return "Review…"
        case .grantAccess: return "Grant Access…"
        }
    }
}

public struct MessagePresentation: Equatable, Sendable {
    public let id: String
    public let title: String
    public let message: String
    public let actions: [PanelAction]
    public let isRetryable: Bool
    public let isWarning: Bool

    public init(
        id: String,
        title: String,
        message: String,
        actions: [PanelAction],
        isRetryable: Bool = false,
        isWarning: Bool = false
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.actions = actions
        self.isRetryable = isRetryable
        self.isWarning = isWarning
    }
}

public enum PrerequisiteMissing: Equatable, Sendable {
    case accessibility
    case privacyNotice
    case apiKey
}

public enum MessageCatalog {
    public static func presentation(forPrerequisite missing: PrerequisiteMissing) -> MessagePresentation {
        switch missing {
        case .accessibility:
            return MessagePresentation(
                id: "E-ACC-01",
                title: "Accessibility access needed",
                message: "DOOM needs Accessibility access to read the text you select.",
                actions: [.openSettings],
                isRetryable: false,
                isWarning: true
            )
        case .privacyNotice:
            return MessagePresentation(
                id: "E-PRIV-01",
                title: "Review the privacy notice",
                message: "Before the first request, review how DOOM sends your selected text to Google Gemini.",
                actions: [.reviewPrivacy],
                isRetryable: false,
                isWarning: true
            )
        case .apiKey:
            return MessagePresentation(
                id: "E-KEY-01",
                title: "Add your Gemini API key",
                message: "DOOM needs a Gemini API key to answer. Add one in DOOM Settings.",
                actions: [.openSettings],
                isRetryable: false,
                isWarning: true
            )
        }
    }

    public static func presentation(for error: CredentialStoreError) -> MessagePresentation {
        switch error {
        case .keychainUnavailable:
            return MessagePresentation(
                id: "E-KC-01",
                title: "Keychain unavailable",
                message: "DOOM couldn't access its Keychain item. This build may not be signed with a development team.",
                actions: [.openSettings],
                isRetryable: false,
                isWarning: true
            )
        case .accessDenied:
            return MessagePresentation(
                id: "E-KC-02",
                title: "Keychain access denied",
                message: "Keychain access was denied by the system.",
                actions: [],
                isRetryable: false,
                isWarning: true
            )
        case .invalidKeyFormat:
            return MessagePresentation(
                id: "E-KC-02",
                title: "Couldn't save the key",
                message: "The key format is invalid. Ensure it is between 20 and 256 characters with no whitespace.",
                actions: [],
                isRetryable: false,
                isWarning: true
            )
        case .unexpectedStatus(let status):
            return MessagePresentation(
                id: "E-KC-02",
                title: "Couldn't save the key",
                message: "Keychain error (\(status)). The key couldn't be saved.",
                actions: [],
                isRetryable: false,
                isWarning: true
            )
        }
    }

    public static func presentation(for error: TextAcquisitionError, appName: String? = nil) -> MessagePresentation {
        let app = appName ?? "this app"
        switch error {
        case .accessibilityNotGranted:
            return presentation(forPrerequisite: .accessibility)
        case .noSourceApplication, .unsupported:
            return MessagePresentation(
                id: "E-SEL-02",
                title: "Can't read this selection",
                message: "DOOM can't read the selection in \(app). Turning on Copy Fallback in Settings may help.",
                actions: [.openSettings, .close],
                isRetryable: false,
                isWarning: true
            )
        case .ownApplication:
            return MessagePresentation(
                id: "E-SEL-09",
                title: "Select text in another app",
                message: "DOOM reads text you select in other apps, not in its own windows.",
                actions: [.close],
                isRetryable: false,
                isWarning: true
            )
        case .secureField:
            return MessagePresentation(
                id: "E-SEL-03",
                title: "Password field",
                message: "DOOM doesn't read text from password fields.",
                actions: [.close],
                isRetryable: false,
                isWarning: true
            )
        case .emptySelection:
            return MessagePresentation(
                id: "E-SEL-01",
                title: "No text selected",
                message: "Select some text, then press Fn ⌃ ⌥.",
                actions: [.close],
                isRetryable: false,
                isWarning: true
            )
        case .tooLong(let count, _):
            return MessagePresentation(
                id: "E-SEL-04",
                title: "Selection too long",
                message: "The selection has \(count) characters. The limit is 20,000. Select less text and try again.",
                actions: [.close],
                isRetryable: false,
                isWarning: true
            )
        case .timedOut:
            return MessagePresentation(
                id: "E-SEL-05",
                title: "App didn't respond",
                message: "\(app) didn't respond in time. Try again in a moment.",
                actions: [.close],
                isRetryable: false,
                isWarning: true
            )
        case .clipboardAccessDenied:
            return MessagePresentation(
                id: "E-SEL-08",
                title: "Clipboard access blocked",
                message: "macOS blocked DOOM from reading the clipboard. You can change this in System Settings › Privacy & Security.",
                actions: [.close],
                isRetryable: false,
                isWarning: true
            )
        case .clipboardNotPreservable:
            return MessagePresentation(
                id: "E-SEL-06",
                title: "Clipboard can't be preserved",
                message: "Copy Fallback was skipped because your clipboard holds protected or unusually large content that DOOM couldn't safely restore.",
                actions: [.close],
                isRetryable: false,
                isWarning: true
            )
        case .clipboardCopyFailed:
            return MessagePresentation(
                id: "E-SEL-07",
                title: "Copy didn't work",
                message: "\(app) didn't copy the selection, so there's nothing to send.",
                actions: [.close],
                isRetryable: false,
                isWarning: true
            )
        case .notText:
            return MessagePresentation(
                id: "E-SEL-10",
                title: "Not text",
                message: "The selection doesn't contain plain text.",
                actions: [.close],
                isRetryable: false,
                isWarning: true
            )
        case .cancelled:
            return MessagePresentation(
                id: "E-SEL-01",
                title: "No text selected",
                message: "Select some text, then press Fn ⌃ ⌥.",
                actions: [.close],
                isRetryable: false,
                isWarning: true
            )
        }
    }

    public static func presentation(for error: GenerationError, modelID: String? = nil) -> MessagePresentation {
        let model = modelID ?? ModelID.default.rawValue
        switch error {
        case .missingAPIKey:
            return presentation(forPrerequisite: .apiKey)
        case .keychain:
            return presentation(for: .keychainUnavailable)
        case .offline:
            return MessagePresentation(
                id: "E-NET-01",
                title: "You're offline",
                message: "Connect to the internet and try again.",
                actions: [.retry],
                isRetryable: true,
                isWarning: false
            )
        case .transport:
            return MessagePresentation(
                id: "E-NET-02",
                title: "Couldn't reach Gemini",
                message: "Check your connection and try again.",
                actions: [.retry],
                isRetryable: true,
                isWarning: false
            )
        case .timedOut:
            return MessagePresentation(
                id: "E-NET-03",
                title: "Gemini took too long",
                message: "No response within 60 seconds.",
                actions: [.retry],
                isRetryable: true,
                isWarning: false
            )
        case .invalidAPIKey:
            return MessagePresentation(
                id: "E-API-01",
                title: "API key rejected",
                message: "Gemini didn't accept the API key. Replace it in DOOM Settings.",
                actions: [.openSettings],
                isRetryable: false,
                isWarning: false
            )
        case .permissionDenied:
            return MessagePresentation(
                id: "E-API-02",
                title: "Access denied",
                message: "This API key isn't allowed to use the Gemini API. Check the key's project restrictions.",
                actions: [.openSettings],
                isRetryable: false,
                isWarning: false
            )
        case .rateLimited:
            return MessagePresentation(
                id: "E-API-03",
                title: "Rate limit reached",
                message: "Too many requests in a short time.",
                actions: [.retry],
                isRetryable: true,
                isWarning: false
            )
        case .quotaExceeded:
            return MessagePresentation(
                id: "E-API-04",
                title: "Daily quota reached",
                message: "Your Gemini API quota for today is used up.",
                actions: [.close],
                isRetryable: false,
                isWarning: false
            )
        case .paymentRequired:
            return MessagePresentation(
                id: "E-API-05",
                title: "Credits depleted",
                message: "Your Gemini API prepaid credits are used up.",
                actions: [.close],
                isRetryable: false,
                isWarning: false
            )
        case .modelNotFound:
            return MessagePresentation(
                id: "E-API-06",
                title: "Model unavailable",
                message: "The model \"\(model)\" isn't available for this key. Check the model in DOOM Settings.",
                actions: [.openSettings],
                isRetryable: false,
                isWarning: false
            )
        case .unavailableForAccount:
            return MessagePresentation(
                id: "E-API-07",
                title: "Gemini unavailable for this account",
                message: "Gemini can't serve this key in its current setup (for example, region or billing).",
                actions: [.close],
                isRetryable: false,
                isWarning: false
            )
        case .server(let status, let code, let safeMessage):
            let msg: String
            if let safeMessage = safeMessage, !safeMessage.isEmpty {
                msg = "\(safeMessage) (HTTP \(status))"
            } else if let code = code, !code.isEmpty {
                msg = "The service reported \"\(code)\" (HTTP \(status)). Try again shortly."
            } else {
                msg = "The service had a problem. Try again shortly."
            }
            return MessagePresentation(
                id: "E-API-08",
                title: "Gemini is temporarily unavailable",
                message: msg,
                actions: [.retry],
                isRetryable: true,
                isWarning: false
            )
        case .badRequest:
            return MessagePresentation(
                id: "E-API-09",
                title: "Request not accepted",
                message: "Gemini rejected DOOM's request. DOOM may need an update.",
                actions: [.close],
                isRetryable: false,
                isWarning: false
            )
        case .blocked(let reason):
            let reasonText: String
            switch reason {
            case .safety: reasonText = "safety filters"
            case .recitation: reasonText = "possible copyrighted material"
            case .prohibitedContent: reasonText = "prohibited content"
            case .spii: reasonText = "sensitive personal information"
            case .blocklist: reasonText = "blocked terms"
            case .language: reasonText = "unsupported language"
            case .other: reasonText = "policy restrictions"
            }
            return MessagePresentation(
                id: "E-GEN-01",
                title: "Gemini declined to answer",
                message: "Gemini blocked a response for this text (\(reasonText)).",
                actions: [.close],
                isRetryable: false,
                isWarning: false
            )
        case .emptyResponse:
            return MessagePresentation(
                id: "E-GEN-02",
                title: "Empty response",
                message: "Gemini returned no text.",
                actions: [.retry],
                isRetryable: true,
                isWarning: false
            )
        case .malformedResponse:
            return MessagePresentation(
                id: "E-GEN-03",
                title: "Unreadable response",
                message: "DOOM couldn't read Gemini's response.",
                actions: [.retry],
                isRetryable: true,
                isWarning: false
            )
        case .cancelled:
            return MessagePresentation(
                id: "E-SEL-01",
                title: "No text selected",
                message: "Select some text, then press Fn ⌃ ⌥.",
                actions: [.close],
                isRetryable: false,
                isWarning: false
            )
        }
    }

    public static func presentation(forShortcutUnavailable: Void) -> MessagePresentation {
        MessagePresentation(
            id: "E-SC-01",
            title: "Shortcut unavailable",
            message: "Control-Shift-H is already used by another app. Show and hide the panel from the menu bar instead.",
            actions: [],
            isRetryable: false,
            isWarning: true
        )
    }

    public static func presentation(forShortcutInactive: Void) -> MessagePresentation {
        MessagePresentation(
            id: "E-SC-02",
            title: "Activation shortcut inactive",
            message: "Fn ⌃ ⌥ needs Accessibility access.",
            actions: [.grantAccess],
            isRetryable: false,
            isWarning: true
        )
    }

    public static func presentation(forInvalidModel: Void) -> MessagePresentation {
        MessagePresentation(
            id: "E-CFG-01",
            title: "Invalid model ID",
            message: "Use lowercase letters, digits, dots and hyphens (for example gemini-3.5-flash).",
            actions: [],
            isRetryable: false,
            isWarning: true
        )
    }

    // Non-error notices
    public enum Notices {
        public static let readingSelection = "Reading selection…" // N-01
        public static let askingGemini = "Asking Gemini…" // N-02
        public static func fromAppAndCount(app: String, count: Int) -> String {
            "From \(app) · \(count) characters" // N-03
        }
        public static let takingLonger = "This is taking longer than usual." // N-04
        public static let incompleteResponse = "The response may be incomplete." // N-05
        public static let copied = "Copied" // N-06
        public static let emptyStateInstruction = "Select text in any app, then press Fn ⌃ ⌥." // N-07
        public static let restoreSkipped = "Restoring the clipboard was skipped because it changed while DOOM was copying." // N-08
    }
}
