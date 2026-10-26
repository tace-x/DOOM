# DOOM — Module and Service Contracts (Phase 02)

**Status:** Specification only. The signatures below are **illustrative declarations that define contracts**. They are not production code and are not compiled. No files listed here exist yet.
**Phase 01 basis:**
- D-03 (`DoomServices` is created at its first real use);
- D-04 (framework limits);
- D-05 (Swift 6, complete concurrency, explicit isolation);
- D-12 (typed domain errors; copy in Features);
- D-13 (logging);
- ARCHITECTURE §2, §6, §7.1 and §7.3 rule 4 (features never call privileged system APIs directly).

**Rule:** a protocol exists only where there is a real implementation **and** a test double. Every protocol below has both. No managers, factories, registries or DI containers.

---

## 1. Module graph (adds one module, `DoomServices`, per D-03)

```
DOOM (app target) ──► DoomFeatures ──► DoomCore
        │                                 ▲
        ├──────────► DoomServices ────────┘
        └───────────────────────────────► DoomCore
DoomCoreTests     ──► DoomCore
DoomServicesTests ──► DoomServices, DoomCore
DoomFeaturesTests ──► DoomFeatures, DoomCore
```

| Module | May import | Must not import |
|---|---|---|
| `DoomCore` | Foundation, OSLog | SwiftUI, AppKit, Cocoa, Carbon, ApplicationServices, Security, any other module |
| `DoomServices` | DoomCore, Foundation, OSLog, AppKit (NSWorkspace, NSEvent, NSPasteboard), ApplicationServices (Accessibility, CGEvent), Carbon (HotKey, TIS), Security | SwiftUI, DoomFeatures |
| `DoomFeatures` | DoomCore, SwiftUI, AppKit (**documented need:** `NSPanel`/`NSHostingView` for the non-activating panel, `NSAccessibility` announcements, and the write-only `NSPasteboard` call for [Copy] in `AssistantController.copyResponse()`, P3-15) | DoomServices, Carbon, ApplicationServices, Security |
| App target | all of the above | — |

- **Forbidden edge:** `DoomFeatures → DoomServices`.
- Features see only Core protocols, and the app target injects the concrete services.
- `Package.swift` enforces the edges at compile time.
- Review greps from `ENGINEERING_STANDARDS.md` §8 gain these checks (adopted in the implementation phase):
  - `import (Carbon|ApplicationServices|Security)` appears only in `DoomServices`;
  - `DoomFeatures` contains no `import DoomServices`.
- Phase 01 review greps that forbid future capabilities (for example "no `URLSession`" in ARCHITECTURE §9, and the future-phase leakage greps in `ENGINEERING_STANDARDS.md` §8) are relaxed **only** in the phase that implements that capability, and only for the files that own it (for example `URLSession` only in `Gemini/`).

---

## 2. Shared conventions

- **Errors:** closed enums, `Error, Equatable, Sendable`. Associated values never carry content, secrets or paths (ARCHITECTURE §5).
- **Isolation:**
  - UI and stateful coordinators are `@MainActor`.
  - Stateless services are `Sendable` structs.
  - Blocking system calls run off the main actor (`TEXT_ACQUISITION_SPECIFICATION.md` §6.1).
- **Typed throws:** used for single-domain async APIs (`async throws(XError)`).
- **Cancellation:** each async API documents what it does when its `Task` is cancelled.
- **Logging:** each service logs once at its own boundary, in its own category (`SECURITY_AND_PRIVACY.md` §2.7).

---

## 3. `DoomCore` contracts

### 3.1 Domain values (all `Sendable`, `Equatable`)

| Type | Shape | Invariants |
|---|---|---|
| `SourceApplication` | `localizedName: String?`, `bundleIdentifier: String?` | **UI only**; never logged |
| `AcquisitionMethod` | `enum { accessibility, clipboard }` | |
| `SelectedText` | `value: String`, `characterCount: Int`, `source: SourceApplication`, `method: AcquisitionMethod` | Created only by `SelectionValidator`; 1…20,000 characters; trimmed |
| `ModelID` | `rawValue: String` | Regex `^[a-z0-9][a-z0-9.\-]{0,63}$`; failable init |
| `APIKey` | `rawValue: String` (internal); `description` / `debugDescription` return `"<redacted>"` | Validated shape (`GEMINI_INTEGRATION_SPECIFICATION.md` §9); never `Codable`, never logged |
| `GenerationRequest` | `text: SelectedText`, `model: ModelID`, `systemInstruction: String`, `maxOutputTokens: Int`, `thinkingLevel: ThinkingLevel` | Built only by `GenerationRequest.make(text:model:)` using `GeminiConfiguration` |
| `ThinkingLevel` | `enum { low, medium, high }` (raw string values) | `minimal` deliberately absent (⟳) |
| `GenerationResult` | `text: String`, `isTruncated: Bool`, `usage: TokenUsage?` | `text` is non-empty after trim |
| `TokenUsage` | input, output, thought and total counts | Counts only |
| `PermissionState` | `enum { granted, notGranted }` | Accessibility has no tri-state |
| `ShortcutEvent` | `enum { activate(origin: ActivationOrigin), togglePanel }`; `ActivationOrigin { chord, menu }` | |
| `ShortcutStatus` | `activation: ActivationShortcutState { active, needsAccessibility, unverified }`, `panelToggle: PanelShortcutState { active, unavailable(status: Int32) }` | |
| `GeminiConfiguration` | constants: `endpoint`, `defaultModelID`, `systemInstructionV1`, `maxOutputTokens = 4096`, `thinkingLevel = .low` | The single place for model configuration (C-5) |
| `SelectionLimits` | `maxCharacters = 20_000` | |
| `PrivacyNotice` | `currentVersion = 1` | |

### 3.2 `SelectionValidator` (pure)

```swift
enum SelectionValidator {
    static func validate(_ raw: String, source: SourceApplication, method: AcquisitionMethod)
        throws(TextAcquisitionError) -> SelectedText   // .emptySelection | .tooLong(count:limit:)
}
```

- Tests: TEXT-T-01…06.

### 3.3 Errors

| Enum | Cases | Owner of mapping to copy |
|---|---|---|
| `TextAcquisitionError` | `TEXT_ACQUISITION_SPECIFICATION.md` §7 | Features (`MessageCatalog`) |
| `GenerationError` | `missingAPIKey, keychain(status: Int32), offline, timedOut, transport(code: Int), cancelled, badRequest(code: String?), unavailableForAccount, invalidAPIKey, paymentRequired, permissionDenied, modelNotFound, rateLimited(retryAfter: Duration?), quotaExceeded, server(status: Int), blocked(reason: BlockReason), emptyResponse, malformedResponse` | Features |
| `BlockReason` | `safety, recitation, prohibitedContent, spii, blocklist, language, other` | Features |
| `CredentialStoreError` | `keychainUnavailable` (−34018), `invalidKeyFormat`, `accessDenied`, `unexpectedStatus(Int32)` | Features |

- The provider `code` strings stored in `badRequest(code:)` are short machine identifiers, for example `invalid_request`. They are not provider messages.

### 3.4 Protocols

Each protocol has one system conformer in `DoomServices` and one fake in a test target.

```swift
@MainActor protocol ShortcutMonitoring: AnyObject {
    var events: AsyncStream<ShortcutEvent> { get }      // single consumer: the app target wiring
    var status: ShortcutStatus { get }
    func start()                                        // idempotent; installs monitors + registers ⌃⇧H
    func refreshAfterPermissionChange()                 // reinstall global monitor if trust changed (SHORTCUT §3.4)
    func stop()                                         // idempotent; removes everything
}

protocol PermissionChecking: Sendable {
    func accessibilityState() -> PermissionState        // non-prompting AXIsProcessTrusted(); cheap, any thread
    @MainActor func requestAccessibility()              // prompting call; only from an explicit button
    @MainActor func openAccessibilitySettings()         // opens System Settings pane
}

@MainActor protocol TextAcquiring: AnyObject {
    func acquireSelection(copyFallbackEnabled: Bool) async throws(TextAcquisitionError) -> SelectedText
}

protocol CredentialStoring: Sendable {
    func hasAPIKey() async throws(CredentialStoreError) -> Bool        // attributes only
    func readAPIKey() async throws(CredentialStoreError) -> APIKey?    // secret read; only at request time
    func saveAPIKey(_ key: APIKey) async throws(CredentialStoreError)
    func deleteAPIKey() async throws(CredentialStoreError)              // succeeds if absent
}

protocol AIResponding: Sendable {
    func respond(to request: GenerationRequest, apiKey: APIKey) async throws(GenerationError) -> GenerationResult
}

protocol PreferencesStoring: Sendable {
    var privacyNoticeAcknowledgedVersion: Int { get nonmutating set }
    var copyFallbackEnabled: Bool { get nonmutating set }
    var modelIDOverride: ModelID? { get nonmutating set }
}
```

**Why each protocol exists:**

| Protocol | Real conformer | Test double |
|---|---|---|
| `ShortcutMonitoring` | `SystemShortcutMonitor` | `FakeShortcutMonitor` (scripted events) |
| `PermissionChecking` | `SystemPermissionChecker` | `FakePermissionChecker` |
| `TextAcquiring` | `SystemTextAcquirer` | `FakeTextAcquirer` |
| `CredentialStoring` | `KeychainCredentialStore` | `InMemoryCredentialStore` |
| `AIResponding` | `GeminiClient` | `FakeAIResponder` |
| `PreferencesStoring` | `UserDefaultsPreferences` | `InMemoryPreferences` |

- **Excluded from Core:**
  - Gemini wire formats (JSON shapes): those belong to `DoomServices`.
  - UI copy.
  - Colours.
  - Any AppKit type.

---

## 4. `DoomServices` contracts

### 4.1 `SystemShortcutMonitor` — `ShortcutMonitoring`
- **Responsibility:**
  - Recognise the activation chord: `NSEvent` local + global monitors → `ChordRecognizer`.
  - Register Control+Shift+H (Carbon), with layout-resolved key codes.
  - Publish `ShortcutEvent`s.
  - Spec: `SHORTCUT_SPECIFICATION.md`.
- **Inputs:** system events, and an injected `PermissionChecking`.
- **Outputs:** `events` (AsyncStream, buffering policy `.bufferingNewest(8)`), and `status`.
- **Errors:** registration failure is reflected in `status.panelToggle = .unavailable(status:)` and logged. It is never thrown.
- **Concurrency:**
  - `@MainActor`.
  - The Carbon handler runs on the main thread. Bridging uses `MainActor.assumeIsolated`, a **documented exception** to ARCHITECTURE §6: Carbon's main event dispatcher invokes handlers on the main thread.
  - The opaque `self` pointer passes through `Unmanaged` with a balanced release in `stop()`.
- **Internal pure types (unit-tested, not public):**
  - `ChordRecognizer`: a value-type state machine; input `(ModifierSnapshot, kind, timestamp)` → `Bool` (activate).
  - `KeyCodeResolver`: character → key code over an injected layout table.
- **Cancellation:** n/a (long-lived). `stop()` at quit.
- **Testing:** SHORTCUT-T-01…08 (pure types). Event delivery is real-Mac only (SHORTCUT-RM-01…11).
- **Excluded:**
  - reading characters or key codes of keyDown events;
  - user-configurable shortcuts;
  - `CGEventTap` (only if `SHORTCUT_SPECIFICATION.md` §10 Option A is approved).

### 4.2 `SystemPermissionChecker` — `PermissionChecking`
- **Responsibility:**
  - `AXIsProcessTrusted()`;
  - the prompt through `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`;
  - opening System Settings.
- **Concurrency:** a `Sendable` struct. The prompt and open calls are `@MainActor`.
- **Errors:** none. The state is returned.
- **Testing:** fake in Features tests. Real behaviour: PERM-01…06 (real Mac).
- **Excluded:** polling; the Input Monitoring APIs (unless Option A is approved).

### 4.3 `SystemTextAcquirer` — `TextAcquiring`
- **Responsibility:** orchestrate `TEXT_ACQUISITION_SPECIFICATION.md` §3–§5:
  - frontmost app (main actor);
  - `AccessibilitySelectionReader` (Accessibility queue);
  - `ClipboardFallback` (main actor, when enabled);
  - `SelectionValidator`.
- **Inputs:** `copyFallbackEnabled`. Injected: the reader, the fallback, and DOOM's own bundle ID.
- **Output:** `SelectedText`.
- **Errors:** `TextAcquisitionError`.
- **Concurrency:** `@MainActor` final class; the Accessibility work is awaited off-actor.
- **Cancellation:** checkpoints between steps. After the fallback has posted ⌘C, it restores and then throws `.cancelled`.
- **Testing:** TEXT-T-07 (strategy logic via a fake `AttributeSource`), TEXT-T-08 (fallback via a fake `PasteboardAccess`).
- **Excluded:** OCR, full-document reads, persistence.

#### 4.3.1 `AccessibilitySelectionReader` (internal)
- A `Sendable` struct holding one private serial `DispatchQueue`. This is the documented exception, P2-04.
- `func read(pid: pid_t, bundleID: String?) async throws(TextAcquisitionError) -> AccessibilityReadOutcome`
  - The outcome is `.text(String)`, `.definitiveEmpty`, or `.unsupported(reason)`.
- Owns the Chromium and Electron enablement and the per-element timeouts.
- Accessibility element references never escape the queue closure.
- An internal `AttributeSource` protocol (system and fake) exists **only** to unit-test strategy selection. It is justified by TEXT-T-07.

#### 4.3.2 `ClipboardFallback` (internal)
- A `@MainActor` final class.
- `func copySelection(from pid: pid_t) async throws(TextAcquisitionError) -> (String, restoreSkipped: Bool)`
- It depends on an internal `PasteboardAccess` protocol (a system wrapper around `NSPasteboard.general`, plus a fake) and a `KeyEventPosting` closure.
- `isInProgress: Bool` is exposed so the app delegate can defer termination (S-19).

### 4.4 `KeychainCredentialStore` — `CredentialStoring`
- **Responsibility:** `GEMINI_INTEGRATION_SPECIFICATION.md` §9.
- **Inputs:** `service` (the bundle ID, injected from `AppContext`) and `account` (constant).
- **Concurrency:** a `Sendable` struct. Calls run on the cooperative pool; they are short and may briefly block.
- **Errors:** `CredentialStoreError`.
- **Cancellation:** not cancellable mid-call (atomic Keychain operations); cancellation is checked before each call.
- **Testing:** `InMemoryCredentialStore` for Features. The real store is tested with a manual real-Mac check (SEC-RM-04), because it needs a team-signed host app with the entitlement. Unit tests can't reliably access the data protection keychain from a test bundle *[Assumed]*.
- **Excluded:** file-based keychain fallback; key display; iCloud sync.

### 4.5 `GeminiClient` — `AIResponding`
- **Responsibility:** `GEMINI_INTEGRATION_SPECIFICATION.md` §3–§8 (except the retry cooldown, which belongs to Features).
- **Inputs:** `GenerationRequest` and `APIKey`. Injected: a `URLSessionConfiguration` (default `.ephemeral` plus the §4 settings; tests inject `StubURLProtocol`).
- **Internal pure types:**
  - `InteractionsRequestBuilder`: `GenerationRequest` + `APIKey` → `URLRequest`.
  - `InteractionsResponseParser`: `Data` → `GenerationResult`, or a `GenerationError` thrown with typed throws.
  - `GeminiErrorMapper`: status, code and headers → `GenerationError`.
- **Concurrency:** a `Sendable` struct; one `URLSession` created in `init`.
- **Cancellation:** cooperative through `URLSession.data(for:)` → `.cancelled`.
- **Testing:** GEMINI-T-01…06; GEMINI-INT-01…04 (opt-in).
- **Excluded:** retries, streaming, conversation state, model listing, telemetry.

### 4.6 `UserDefaultsPreferences` — `PreferencesStoring`
- **Responsibility:** the three keys in `SECURITY_AND_PRIVACY.md` §2.8.
- **Inputs:** a `UserDefaults` instance injected by the app target. Tests use `UserDefaults(suiteName:)` with a unique name that is removed afterwards.
- **Concurrency:** a `Sendable` struct (UserDefaults is thread-safe).
- **Errors:** none. Invalid stored values fall back to the defaults.
- **Excluded:** secrets of any kind.

---

## 5. `DoomFeatures` contracts

### 5.1 `AssistantController`
- **Responsibility:** the assistant flow state machine (`PRODUCT_BEHAVIOR.md` §1):
  - prerequisite checks;
  - single-flight;
  - flow token;
  - retry cooldown;
  - discarding content.
- **Interface:**

```swift
@MainActor @Observable final class AssistantController {
    enum Phase: Equatable { case idle, acquiring, requesting(SelectionSummary), succeeded(ResponseContent), failed(FailurePresentation) }
    private(set) var phase: Phase
    init(dependencies: AssistantDependencies)
    func handleActivation(origin: ActivationOrigin)     // ignored when busy
    func cancel()                                        // acquiring/requesting → idle
    func close()                                         // any → idle, discards
    func retry()                                         // failed(retryable, cooldown elapsed) → requesting
    func copyResponse()                                  // succeeded only
    var isClipboardOperationInProgress: Bool { get }     // for termination deferral
}

struct AssistantDependencies {
    let permissions: any PermissionChecking
    let credentials: any CredentialStoring
    let textAcquirer: any TextAcquiring
    let ai: any AIResponding
    let preferences: any PreferencesStoring
    let copyToPasteboard: @MainActor (String) -> Void    // injected by the app target (no globals in Features)
    let sleep: @Sendable (Duration) async throws -> Void  // cooldown ticks; tests inject an immediate/controlled sleep
}
```

- **Supporting types:**
  - `SelectionSummary`: app name and count.
  - `ResponseContent`: text, truncation, and the restore-skipped flag.
  - `FailurePresentation`: a message ID, retryability and cooldown; built by `MessageCatalog`.
- **Concurrency:**
  - `@MainActor`.
  - It owns one `Task<Void, Never>?` for the current flow.
  - Results are applied only if the flow token matches.
- **Cancellation:** `cancel()`/`close()` cancel the task. Cleanup (clipboard restore) is guaranteed by the acquirer.
- **Testing:** with all fakes. Covers: one request per activation, busy ignore, the prerequisite order, every error → presentation, the cooldown sequence, discard on close, and late results dropped (GEMINI-T-06/07, SHORTCUT-T-09, LIFE-T-01…04).
- **Excluded:** AppKit, panel geometry, and any knowledge of Gemini wire formats.

### 5.2 `PanelController`
- **Responsibility:**
  - create and reuse `DoomPanel`;
  - show (without making key), hide, toggle;
  - positioning and resizing (`UI_SPECIFICATION.md` §3);
  - VoiceOver announcements on phase changes.
- **Interface:** `@MainActor final class PanelController { init(assistant: AssistantController); func show(); func hide(); func toggle(); var isVisible: Bool { get } }`
- **AppKit use (documented):** `NSPanel`, `NSHostingView`, `NSScreen`, `NSEvent.mouseLocation`, `NSAccessibility.post`.
- **Testing:**
  - geometry is a pure function, `PanelGeometry.frame(contentHeight:visibleFrame:userOrigin:)`, unit-tested in UI-T-01…03;
  - window behaviour is checked on a real Mac (UI-33, UI-34, UI-35, UI-39).
- **Excluded:** capture-exclusion settings; multiple panels.

### 5.3 `PanelView` and `MessageCatalog`
- **`PanelView`:** SwiftUI rendering of `AssistantController.Phase` (`UI_SPECIFICATION.md` §3.5–3.7).
- **`MessageCatalog`:** a pure mapping from `TextAcquisitionError`, `GenerationError` and `CredentialStoreError` (plus the prerequisite kinds) to `(id, title, message, actions, retryable)`, using the exact strings in `PRODUCT_BEHAVIOR.md` §3.
  - Tested exhaustively in UI-T-04: every case maps, and no string is empty.

### 5.4 `MainWindowModel` (evolves Phase 01 `HomeViewModel`) and views
- **Responsibility:**
  - status header (configuration plus readiness);
  - setup checklist;
  - key save, replace and remove;
  - model override;
  - Copy Fallback toggle;
  - privacy acknowledgement;
  - shortcut status display.
- **Interface:** `@MainActor @Observable final class MainWindowModel { init(context: AppContext, dependencies: MainWindowDependencies); func refresh() async; func saveAPIKey(_ text: String) async; func removeAPIKey() async; func acknowledgePrivacyNotice(); func setCopyFallback(_ on: Bool); func setModel(_ text: String); func resetModel(); func requestAccessibility(); func openAccessibilitySettings() }`
  - `MainWindowDependencies` contains: permissions, credentials, preferences, a shortcut-status provider closure `@MainActor () -> ShortcutStatus`, and a restart action closure.
- **Concurrency:** `@MainActor`. Keychain calls are awaited.
- **Testing:** with fakes (UI-T-05…08). The key text is never retained after save; the SecureField binding is cleared.
- **Excluded:** displaying any part of the key; network calls.

### 5.5 `StatusMenuContent`
- SwiftUI menu items for the `MenuBarExtra` (`PRODUCT_BEHAVIOR.md` §0.1).
- It receives closures for its actions. No logic beyond labels.

### 5.6 `DoomTheme`
- Extended tokens per `UI_SPECIFICATION.md` §2.1. Colour types stay in Features (D-04).

---

## 6. App target contracts

- **`DOOMApp`:** scenes `Window("DOOM", id: "main")` and `MenuBarExtra`. No logic.
- **`AppDelegate`** (composition root and lifecycle):
  1. Build `AppContext` (Phase 01).
  2. Build the concrete services, passing the bundle ID, `UserDefaults.standard` and the ephemeral configuration.
  3. Build `AssistantController`, `PanelController` and `MainWindowModel`.
  4. Consume `shortcutMonitor.events`: `.activate` → `assistant.handleActivation` + `panel.show()`; `.togglePanel` → `panel.toggle()`.
  5. Handle `applicationDidBecomeActive` → `refreshAfterPermissionChange()` + `mainWindowModel.refresh()`.
  6. Handle reopen → open the main window.
  7. `applicationShouldTerminateAfterLastWindowClosed` → `false`.
  8. `applicationShouldTerminate` → `.terminateLater` while `isClipboardOperationInProgress`, otherwise `.terminateNow`.
  9. `applicationWillTerminate` → `stop()` + log.
- **`Info.plist`:** add `LSUIElement = YES` via `INFOPLIST_KEY_LSUIElement = YES` in `Config/DOOM.xcconfig` *(P2-01, approved; milestone M02)*. No usage-description keys.
- **Testing:** the smoke test (D-15) is extended in the implementation phase. Its expectation that a window is visible must change for agent mode: the smoke flag opens the main window explicitly. Real Mac: LIFE-01, LIFE-03, LIFE-04, LIFE-12.

---

## 7. Planned files (for the implementation phase; **not created now**)

Paths are relative to the repository root. `DoomKit/` is the package at the root (`PROJECT_STRUCTURE.md` §1); there is no `Packages/` folder. Milestone ownership of each file is given in `IMPLEMENTATION_ROADMAP.md`.

```
DoomKit/Sources/DoomCore/                 Domain/{SourceApplication,SelectedText,ModelID,APIKey,Generation,Shortcut,Permission}.swift
                                          Validation/SelectionValidator.swift · Errors/{TextAcquisitionError,GenerationError,CredentialStoreError}.swift
                                          Contracts/{ShortcutMonitoring,PermissionChecking,TextAcquiring,CredentialStoring,AIResponding,PreferencesStoring}.swift
                                          Configuration/{GeminiConfiguration,SelectionLimits,PrivacyNotice}.swift
DoomKit/Sources/DoomServices/             Shortcuts/{SystemShortcutMonitor,ChordRecognizer,KeyCodeResolver}.swift
                                          Selection/{SystemTextAcquirer,AccessibilitySelectionReader,ClipboardFallback}.swift
                                          Gemini/{GeminiClient,InteractionsRequestBuilder,InteractionsResponseParser,GeminiErrorMapper}.swift
                                          {KeychainCredentialStore,SystemPermissionChecker,UserDefaultsPreferences}.swift
DoomKit/Sources/DoomFeatures/             Assistant/{AssistantController,MessageCatalog}.swift · Panel/{DoomPanel,PanelController,PanelGeometry,PanelView}.swift
                                          MainWindow/{MainWindowModel,MainWindowView,PrivacyNoticeView}.swift · Menu/StatusMenuContent.swift · DesignSystem/DoomTheme.swift (existing Phase 01 file, extended)
DoomKit/Tests/{DoomCoreTests,DoomServicesTests,DoomFeaturesTests}/…
```

- Which phase creates which file is decided in later planning, which is outside Phase 02.
- Files are created only when implemented; there are no placeholders.
- `PROJECT_STRUCTURE.md` will be updated in that phase.
