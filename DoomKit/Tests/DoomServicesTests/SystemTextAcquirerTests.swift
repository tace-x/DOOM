import Testing
import Foundation
import DoomCore
@testable import DoomServices

private struct FakePermissionChecker: PermissionChecking, Sendable {
    let trusted: Bool

    func accessibilityState() -> PermissionState {
        trusted ? .granted : .notGranted
    }

    @MainActor func requestAccessibility() {}
    @MainActor func openAccessibilitySettings() {}
}

private final class ScriptedAccessibilityReader: AccessibilitySelectionReading, @unchecked Sendable {
    var resultToReturn: Result<String, TextAcquisitionError>

    init(result: Result<String, TextAcquisitionError>) {
        self.resultToReturn = result
    }

    func readSelectedText(from sourcePid: pid_t, bundleIdentifier: String?) async throws(TextAcquisitionError) -> String {
        switch resultToReturn {
        case .success(let str):
            return str
        case .failure(let err):
            throw err
        }
    }
}

@MainActor
private final class ScriptedClipboardFallback: ClipboardFallbackHandling {
    var resultToReturn: Result<(String, Bool), TextAcquisitionError>
    var wasCalled = false

    init(result: Result<(String, Bool), TextAcquisitionError>) {
        self.resultToReturn = result
    }

    func acquireViaClipboard(sourcePid: pid_t) async throws(TextAcquisitionError) -> (text: String, restoreSkipped: Bool) {
        wasCalled = true
        switch resultToReturn {
        case .success(let tuple):
            return tuple
        case .failure(let err):
            throw err
        }
    }
}

@Suite("SystemTextAcquirerTests")
struct SystemTextAcquirerTests {
    @Test("Accessibility not granted aborts acquisition immediately")
    @MainActor
    func testUntrustedPermissionAborts() async {
        let perms = FakePermissionChecker(trusted: false)
        let reader = ScriptedAccessibilityReader(result: .success("Valid text"))
        let fallback = ScriptedClipboardFallback(result: .success(("Fallback text", false)))
        let acquirer = SystemTextAcquirer(permissions: perms, accessibilityReader: reader, clipboardFallback: fallback)

        await #expect(throws: TextAcquisitionError.accessibilityNotGranted) {
            try await acquirer.acquireSelection(copyFallbackEnabled: true)
        }
        #expect(!fallback.wasCalled)
    }

    @Test("Accessibility success returns validated SelectedText")
    @MainActor
    func testAccessibilitySuccess() async throws {
        let perms = FakePermissionChecker(trusted: true)
        let reader = ScriptedAccessibilityReader(result: .success("A valid paragraph of text."))
        let fallback = ScriptedClipboardFallback(result: .success(("Fallback text", false)))
        let acquirer = SystemTextAcquirer(permissions: perms, accessibilityReader: reader, clipboardFallback: fallback)

        let selected = try await acquirer.acquireSelection(copyFallbackEnabled: false)
        #expect(selected.value == "A valid paragraph of text.")
        #expect(selected.method == .accessibility)
        #expect(selected.characterCount == 26)
        #expect(!fallback.wasCalled)
    }

    @Test("Fallback off rethrows unsupported error")
    @MainActor
    func testFallbackOffRethrows() async {
        let perms = FakePermissionChecker(trusted: true)
        let reader = ScriptedAccessibilityReader(result: .failure(.unsupported(reason: "noUsableSelection")))
        let fallback = ScriptedClipboardFallback(result: .success(("Fallback text", false)))
        let acquirer = SystemTextAcquirer(permissions: perms, accessibilityReader: reader, clipboardFallback: fallback)

        await #expect(throws: TextAcquisitionError.unsupported(reason: "noUsableSelection")) {
            try await acquirer.acquireSelection(copyFallbackEnabled: false)
        }
        #expect(!fallback.wasCalled)
    }

    @Test("Fallback on executes clipboard acquisition and returns SelectedText with clipboard method")
    @MainActor
    func testFallbackOnExecutesClipboard() async throws {
        let perms = FakePermissionChecker(trusted: true)
        let reader = ScriptedAccessibilityReader(result: .failure(.unsupported(reason: "noUsableSelection")))
        let fallback = ScriptedClipboardFallback(result: .success(("Acquired via clipboard", false)))
        let acquirer = SystemTextAcquirer(permissions: perms, accessibilityReader: reader, clipboardFallback: fallback)

        let selected = try await acquirer.acquireSelection(copyFallbackEnabled: true)
        #expect(selected.value == "Acquired via clipboard")
        #expect(selected.method == .clipboard)
        #expect(fallback.wasCalled)
    }

    @Test("TEXT-22: Own application selection throws ownApplication error")
    @MainActor
    func testOwnApplicationThrows() async {
        let perms = FakePermissionChecker(trusted: true)
        let reader = ScriptedAccessibilityReader(result: .success("Self text"))
        let fallback = ScriptedClipboardFallback(result: .success(("Fallback text", false)))
        let acquirer = SystemTextAcquirer(
            permissions: perms,
            ownBundleIdentifier: "com.tace.doom",
            accessibilityReader: reader,
            clipboardFallback: fallback,
            frontmostAppProvider: { (pid: 9999, bundleIdentifier: "com.tace.doom", localizedName: "DOOM") }
        )

        await #expect(throws: TextAcquisitionError.ownApplication) {
            try await acquirer.acquireSelection(copyFallbackEnabled: true)
        }
        #expect(!fallback.wasCalled)
    }

    @Test("Editor selection with fallback on executes clipboard fallback successfully")
    @MainActor
    func testEditorSelectionWithFallbackOnExecutesClipboard() async throws {
        let perms = FakePermissionChecker(trusted: true)
        let reader = ScriptedAccessibilityReader(result: .failure(.editorSelectionUnavailable))
        let fallback = ScriptedClipboardFallback(result: .success(("function kalvium() { return true; }", false)))
        let acquirer = SystemTextAcquirer(permissions: perms, accessibilityReader: reader, clipboardFallback: fallback)

        let selected = try await acquirer.acquireSelection(copyFallbackEnabled: true)
        #expect(selected.value == "function kalvium() { return true; }")
        #expect(selected.method == .clipboard)
        #expect(fallback.wasCalled)
    }

    @Test("Editor selection with fallback off throws clipboardFallbackDisabled without touching clipboard")
    @MainActor
    func testEditorSelectionWithFallbackOffThrowsClipboardFallbackDisabled() async {
        let perms = FakePermissionChecker(trusted: true)
        let reader = ScriptedAccessibilityReader(result: .failure(.editorSelectionUnavailable))
        let fallback = ScriptedClipboardFallback(result: .success(("should not be called", false)))
        let acquirer = SystemTextAcquirer(permissions: perms, accessibilityReader: reader, clipboardFallback: fallback)

        await #expect(throws: TextAcquisitionError.clipboardFallbackDisabled) {
            try await acquirer.acquireSelection(copyFallbackEnabled: false)
        }
        #expect(!fallback.wasCalled)
    }

    @Test("Empty selection never triggers clipboard fallback even if enabled")
    @MainActor
    func testEmptySelectionNeverTriggersClipboardFallback() async {
        let perms = FakePermissionChecker(trusted: true)
        let reader = ScriptedAccessibilityReader(result: .failure(.emptySelection))
        let fallback = ScriptedClipboardFallback(result: .success(("should not be called", false)))
        let acquirer = SystemTextAcquirer(permissions: perms, accessibilityReader: reader, clipboardFallback: fallback)

        await #expect(throws: TextAcquisitionError.emptySelection) {
            try await acquirer.acquireSelection(copyFallbackEnabled: true)
        }
        #expect(!fallback.wasCalled)
    }
}
