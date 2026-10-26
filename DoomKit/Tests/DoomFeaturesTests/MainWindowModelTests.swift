import Testing
import Foundation
import DoomCore
@testable import DoomFeatures

final class FakePermissionChecker: PermissionChecking, @unchecked Sendable {
    var state: PermissionState = .notGranted
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

final class FakePreferences: PreferencesStoring, @unchecked Sendable {
    var privacyNoticeAcknowledgedVersion: Int = 0
    var copyFallbackEnabled: Bool = false
    var modelIDOverride: String? = nil
}

actor FakeKeyStore {
    var key: String? = nil

    func hasKey() -> Bool {
        key != nil
    }

    func saveKey(_ newKey: String) -> Result<Void, CredentialStoreError> {
        key = newKey
        return .success(())
    }

    func deleteKey() -> Bool {
        key = nil
        return true
    }
}

@MainActor
struct MainWindowModelTests {
    private func makeContext(isDegraded: Bool = false) -> AppContext {
        if isDegraded {
            return AppContext.make(infoDictionary: [:], arguments: ["DOOM"])
        } else {
            return AppContext.make(
                infoDictionary: [
                    "CFBundleDisplayName": "DOOM",
                    "CFBundleIdentifier": "com.tace.doom",
                    "CFBundleShortVersionString": "0.1.0",
                    "CFBundleVersion": "1"
                ],
                arguments: ["DOOM"]
            )
        }
    }

    @Test("Valid context with missing prerequisites shows setup needed")
    func validContextSetupNeeded() async {
        let context = makeContext()
        let permissions = FakePermissionChecker()
        let preferences = FakePreferences()

        let keyStore = FakeKeyStore()

        let dependencies = MainWindowModel.Dependencies(
            permissions: permissions,
            preferences: preferences,
            hasAPIKeyProvider: { await keyStore.hasKey() },
            saveAPIKeyAction: { key in
                await keyStore.saveKey(key)
            },
            deleteAPIKeyAction: {
                await keyStore.deleteKey()
            }
        )

        let model = MainWindowModel(context: context, dependencies: dependencies)
        #expect(model.title == "DOOM")
        #expect(model.versionText == "Version 0.1.0 (1)")
        #expect(model.status == .setupNeeded)
        #expect(model.statusText == "Setup needed")
        #expect(!model.isSetupComplete)

        // Now grant permissions, acknowledge privacy, and save key
        permissions.state = .granted
        model.acknowledgePrivacyNotice()
        #expect(model.isPrivacyReviewed)

        await model.saveAPIKey("test-api-key")
        #expect(model.hasAPIKey)
        #expect(model.apiKeyInput == "") // Key text is cleared after save
        #expect(model.apiKeyStatusMessage == "Saved in Keychain")

        await model.refresh()
        #expect(model.isAccessibilityGranted)
        #expect(model.isSetupComplete)
        #expect(model.status == .ready)
        #expect(model.statusText == "Ready")
    }

    @Test("Failed saveAPIKey surfaces actionable error presentation")
    func saveAPIKeyErrorSurfacing() async {
        let context = makeContext()
        let permissions = FakePermissionChecker()
        let preferences = FakePreferences()

        // 1. Keychain unavailable error (-34018)
        let unavailDeps = MainWindowModel.Dependencies(
            permissions: permissions,
            preferences: preferences,
            hasAPIKeyProvider: { false },
            saveAPIKeyAction: { _ in .failure(.keychainUnavailable) },
            deleteAPIKeyAction: { true }
        )
        let model1 = MainWindowModel(context: context, dependencies: unavailDeps)
        await model1.saveAPIKey("valid-length-key-1234567890abcdef")
        #expect(!model1.hasAPIKey)
        #expect(model1.apiKeyStatusMessage?.contains("development team") == true)

        // 2. Unexpected status error (-50)
        let unexpectedDeps = MainWindowModel.Dependencies(
            permissions: permissions,
            preferences: preferences,
            hasAPIKeyProvider: { false },
            saveAPIKeyAction: { _ in .failure(.unexpectedStatus(-50)) },
            deleteAPIKeyAction: { true }
        )
        let model2 = MainWindowModel(context: context, dependencies: unexpectedDeps)
        await model2.saveAPIKey("valid-length-key-1234567890abcdef")
        #expect(!model2.hasAPIKey)
        #expect(model2.apiKeyStatusMessage?.contains("-50") == true)
    }

    @Test("Degraded context produces degraded status")
    func degradedContext() {
        let context = makeContext(isDegraded: true)
        let permissions = FakePermissionChecker()
        let preferences = FakePreferences()

        let dependencies = MainWindowModel.Dependencies(
            permissions: permissions,
            preferences: preferences,
            hasAPIKeyProvider: { false },
            saveAPIKeyAction: { _ in .success(()) },
            deleteAPIKeyAction: { true }
        )

        let model = MainWindowModel(context: context, dependencies: dependencies)
        #expect(model.status == .degraded)
        #expect(model.statusText.contains("default settings"))
        #expect(!model.statusText.contains("CFBundle"))
    }

    @Test("Model ID validation rejects invalid and allows reset")
    func modelValidation() {
        let context = makeContext()
        let permissions = FakePermissionChecker()
        let preferences = FakePreferences()

        let dependencies = MainWindowModel.Dependencies(
            permissions: permissions,
            preferences: preferences,
            hasAPIKeyProvider: { true },
            saveAPIKeyAction: { _ in .success(()) },
            deleteAPIKeyAction: { true }
        )

        let model = MainWindowModel(context: context, dependencies: dependencies)
        #expect(model.modelInput == "gemini-3.5-flash")

        // Valid model
        model.setModel("gemini-2.0-flash")
        #expect(model.modelInput == "gemini-2.0-flash")
        #expect(model.modelError == nil)

        // Invalid model with uppercase or invalid chars
        model.setModel("Gemini Invalid Model!!")
        #expect(model.modelError != nil)

        // Reset restores default
        model.resetModel()
        #expect(model.modelInput == "gemini-3.5-flash")
        #expect(model.modelError == nil)
    }

    @Test("Copy fallback toggle persists to preferences")
    func copyFallbackToggle() {
        let context = makeContext()
        let permissions = FakePermissionChecker()
        let preferences = FakePreferences()

        let dependencies = MainWindowModel.Dependencies(
            permissions: permissions,
            preferences: preferences,
            hasAPIKeyProvider: { true },
            saveAPIKeyAction: { _ in .success(()) },
            deleteAPIKeyAction: { true }
        )

        let model = MainWindowModel(context: context, dependencies: dependencies)
        #expect(!model.copyFallbackEnabled)

        model.setCopyFallback(true)
        #expect(model.copyFallbackEnabled)
        #expect(preferences.copyFallbackEnabled)
    }

    @Test("testConnection recovers UI state and sets success result")
    func testConnectionSuccess() async {
        let context = makeContext()
        let permissions = FakePermissionChecker()
        let preferences = FakePreferences()

        let dependencies = MainWindowModel.Dependencies(
            permissions: permissions,
            preferences: preferences,
            hasAPIKeyProvider: { true },
            saveAPIKeyAction: { _ in .success(()) },
            deleteAPIKeyAction: { true },
            testConnectionAction: {
                (true, "Connection successful! Gemini answered in stateless mode.")
            }
        )

        let model = MainWindowModel(context: context, dependencies: dependencies)
        await model.refresh()
        #expect(model.hasAPIKey)
        #expect(!model.isTestingConnection)
        #expect(model.testConnectionResult == nil)

        await model.testConnection()

        #expect(!model.isTestingConnection) // Recovered!
        #expect(model.isTestConnectionSuccess)
        #expect(model.testConnectionResult == "Connection successful! Gemini answered in stateless mode.")
    }

    @Test("testConnection recovers UI state after failure and surfaces error message")
    func testConnectionFailure() async {
        let context = makeContext()
        let permissions = FakePermissionChecker()
        let preferences = FakePreferences()

        let dependencies = MainWindowModel.Dependencies(
            permissions: permissions,
            preferences: preferences,
            hasAPIKeyProvider: { true },
            saveAPIKeyAction: { _ in .success(()) },
            deleteAPIKeyAction: { true },
            testConnectionAction: {
                (false, "Gemini took too long: No response within 60 seconds.")
            }
        )

        let model = MainWindowModel(context: context, dependencies: dependencies)
        await model.refresh()
        #expect(model.hasAPIKey)
        #expect(!model.isTestingConnection)
        #expect(model.testConnectionResult == nil)

        await model.testConnection()

        #expect(!model.isTestingConnection) // Recovered!
        #expect(!model.isTestConnectionSuccess)
        #expect(model.testConnectionResult == "Gemini took too long: No response within 60 seconds.")
    }

    @Test("testConnection prevents duplicate requests while in-flight")
    func testConnectionDeduplication() async {
        let context = makeContext()
        let permissions = FakePermissionChecker()
        let preferences = FakePreferences()

        actor CallCounter {
            var count = 0
            func increment() { count += 1 }
            func getCount() -> Int { count }
        }
        let counter = CallCounter()

        let dependencies = MainWindowModel.Dependencies(
            permissions: permissions,
            preferences: preferences,
            hasAPIKeyProvider: { true },
            saveAPIKeyAction: { _ in .success(()) },
            deleteAPIKeyAction: { true },
            testConnectionAction: {
                await counter.increment()
                try? await Task.sleep(for: .milliseconds(50))
                return (true, "OK")
            }
        )

        let model = MainWindowModel(context: context, dependencies: dependencies)
        await model.refresh()
        #expect(model.hasAPIKey)

        // Launch two concurrent tests
        async let first: () = model.testConnection()
        async let second: () = model.testConnection()
        _ = await (first, second)

        let calls = await counter.getCount()
        #expect(calls == 1) // Only one network request dispatched!
        #expect(!model.isTestingConnection)
    }
}
