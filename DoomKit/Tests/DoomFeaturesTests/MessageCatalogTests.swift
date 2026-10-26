import Testing
import Foundation
import DoomCore
@testable import DoomFeatures

struct MessageCatalogTests {
    @Test("Prerequisites map to expected catalog messages")
    func prerequisitesMapping() {
        let acc = MessageCatalog.presentation(forPrerequisite: .accessibility)
        #expect(acc.id == "E-ACC-01")
        #expect(!acc.title.isEmpty)
        #expect(!acc.message.isEmpty)
        #expect(acc.isWarning)

        let priv = MessageCatalog.presentation(forPrerequisite: .privacyNotice)
        #expect(priv.id == "E-PRIV-01")
        #expect(!priv.title.isEmpty)
        #expect(!priv.message.isEmpty)
        #expect(priv.isWarning)

        let key = MessageCatalog.presentation(forPrerequisite: .apiKey)
        #expect(key.id == "E-KEY-01")
        #expect(!key.title.isEmpty)
        #expect(!key.message.isEmpty)
        #expect(key.isWarning)
    }

    @Test("Credential errors map to E-KC-01 and E-KC-02")
    func credentialErrorsMapping() {
        let unavail = MessageCatalog.presentation(for: CredentialStoreError.keychainUnavailable)
        #expect(unavail.id == "E-KC-01")
        #expect(unavail.title == "Keychain unavailable")

        let format = MessageCatalog.presentation(for: CredentialStoreError.invalidKeyFormat)
        #expect(format.id == "E-KC-02")
        #expect(format.title == "Couldn't save the key")

        let denied = MessageCatalog.presentation(for: CredentialStoreError.accessDenied)
        #expect(denied.id == "E-KC-02")
        #expect(denied.title == "Keychain access denied")

        let unexpected = MessageCatalog.presentation(for: CredentialStoreError.unexpectedStatus(-50))
        #expect(unexpected.id == "E-KC-02")
        #expect(unexpected.message.contains("-50"))
    }

    @Test("Text acquisition errors map to non-empty strings")
    func textAcquisitionErrorsMapping() {
        let errors: [TextAcquisitionError] = [
            .accessibilityNotGranted,
            .noSourceApplication,
            .ownApplication,
            .secureField,
            .emptySelection,
            .unsupported(reason: "test"),
            .tooLong(count: 25000, limit: 20000),
            .timedOut,
            .clipboardAccessDenied,
            .clipboardNotPreservable,
            .clipboardCopyFailed,
            .notText,
            .cancelled
        ]

        for err in errors {
            let p = MessageCatalog.presentation(for: err, appName: "TextEdit")
            #expect(!p.id.isEmpty)
            #expect(!p.title.isEmpty)
            #expect(!p.message.isEmpty)
            #expect(p.isWarning)
        }
    }

    @Test("Generation errors map to non-empty strings")
    func generationErrorsMapping() {
        let errors: [GenerationError] = [
            .missingAPIKey,
            .keychain(status: -34018),
            .offline,
            .timedOut,
            .transport(code: 500),
            .cancelled,
            .badRequest(code: "invalid_arg"),
            .unavailableForAccount,
            .invalidAPIKey,
            .paymentRequired,
            .permissionDenied,
            .modelNotFound,
            .rateLimited(retryAfter: nil),
            .quotaExceeded,
            .server(status: 503),
            .blocked(reason: .safety),
            .emptyResponse,
            .malformedResponse
        ]

        for err in errors {
            let p = MessageCatalog.presentation(for: err, modelID: "gemini-3.5-flash")
            #expect(!p.id.isEmpty)
            #expect(!p.title.isEmpty)
            #expect(!p.message.isEmpty)
        }
    }

    @Test("Non-error notices are non-empty")
    func noticesValidation() {
        #expect(!MessageCatalog.Notices.readingSelection.isEmpty)
        #expect(!MessageCatalog.Notices.askingGemini.isEmpty)
        #expect(!MessageCatalog.Notices.takingLonger.isEmpty)
        #expect(!MessageCatalog.Notices.incompleteResponse.isEmpty)
        #expect(!MessageCatalog.Notices.copied.isEmpty)
        #expect(!MessageCatalog.Notices.emptyStateInstruction.isEmpty)
        #expect(!MessageCatalog.Notices.restoreSkipped.isEmpty)
        #expect(!MessageCatalog.Notices.fromAppAndCount(app: "Chrome", count: 120).isEmpty)
    }

    @Test("Server error preserves provider message and status in presentation")
    func serverErrorPreservesProviderDetails() {
        let errWithMsg = GenerationError.server(status: 503, code: "service_unavailable", message: "gemini-3.8-flash is experiencing high demand")
        let pWithMsg = MessageCatalog.presentation(for: errWithMsg, modelID: "gemini-3.8-flash")
        #expect(pWithMsg.title == "Gemini is temporarily unavailable")
        #expect(pWithMsg.message == "gemini-3.8-flash is experiencing high demand (HTTP 503)")

        let errWithoutMsg = GenerationError.server(status: 503)
        let pWithoutMsg = MessageCatalog.presentation(for: errWithoutMsg, modelID: "gemini-3.8-flash")
        #expect(pWithoutMsg.message == "The service had a problem. Try again shortly.")
    }
}
