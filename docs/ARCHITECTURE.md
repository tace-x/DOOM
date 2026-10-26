# DOOM — Architecture

| | |
|---|---|
| **Status** | Approved. Phase 01 design, amended by Phase 02 (§C of `TECHNICAL_DECISIONS.md`) and Phase 03 (§D). Not yet implemented |
| **Date** | 2026-10-24 |
| **Scope** | The architectural foundation only. No feature is implemented. |
| **Companion documents** | `TECHNICAL_DECISIONS.md` (decision register), `PROJECT_STRUCTURE.md`, `ENGINEERING_STANDARDS.md`, `PHASE_01_SUMMARY.md` |

Labels used in this document. **[Verified]** means it was checked during Phase 01 against a cited source or tool output. **[Assumed]** means it is not yet verified and must be confirmed on the user's Mac. **[Decision]** refers to an entry in `TECHNICAL_DECISIONS.md`.

---

## 1. Overview

DOOM is a native macOS assistant. Eventually the user will select text in any app (initially Chrome), press a global shortcut, and get a Gemini-generated response in a floating panel that does not take focus away from the source app.

Phase 01 does **not** build any of that. It defines a small, well-bounded foundation that later phases can extend without restructuring:

```
┌──────────────────────────────────────────────────────────────┐
│ DOOM.app — Xcode app target ("the executable")               │
│   @main App · AppDelegate · composition root · Assets        │
│   Reads process globals (Bundle.main, ProcessInfo) — ONLY here│
└───────────────┬───────────────────────────┬──────────────────┘
                │ links                     │ links
                ▼                           ▼
┌───────────────────────────┐   ┌─────────────────────────────┐
│ DoomFeatures (package lib) │──►│ DoomCore (package lib)       │
│ SwiftUI views, view models │   │ Configuration + validation   │
│ presentation state         │   │ Domain errors                │
│ design system (DoomTheme)  │   │ Launch options               │
│ AppKit only when a feature │   │ AppContext (dependency value)│
│ genuinely needs it         │   │ Logging categories (OSLog)   │
└───────────────────────────┘   │ Foundation + OSLog ONLY      │
                                └─────────────────────────────┘
```
Both libraries live in one local Swift package, `DoomKit`, inside the repository. The app target is created and owned by an Xcode project (**[Decision] D-01**).

The initial product surface is one dark, metallic status window. It shows the DOOM wordmark, the version, the configuration status and a note that assistant features arrive in later phases. Its purpose is to prove that the shell, bundle identity, configuration pipeline, design tokens, logging, tests and launch/quit path all work.

---

## 2. Module responsibilities

### 2.1 App target — `DOOM` (Xcode project, folder `DOOM/`)
**Owns:** the application entry point (`@main struct DOOMApp: App`), the `NSApplicationDelegate`, lifecycle events, the **composition root**, native integration (activation, termination, the app menu that SwiftUI generates), the asset catalog (accent color) and all bundle identity, which comes from build settings.

**Rules:**
- This is the only place that reads process-global state: `Bundle.main.infoDictionary` and `ProcessInfo.processInfo.arguments`.
- It builds the `AppContext` once and passes it down. Nothing below the app target constructs its own dependencies.
- It holds no business logic. Anything worth testing moves to `DoomCore` or `DoomFeatures`.
- The app target has no unit-test target in Phase 01. Its behaviour (launch, window shown, clean termination) is verified by the smoke test (**D-15**, `ENGINEERING_STANDARDS.md` §7.1).

### 2.2 `DoomCore` (package library)
**Owns:** configuration (`AppConfiguration`) and its validation, domain errors (`ConfigurationError`), launch-option parsing (`LaunchOptions`), the dependency value passed into features (`AppContext`), and logging categories (`LogCategory` with a `Logger` convenience initializer).

**Rules:**
- It imports only `Foundation` and `OSLog`. It **never imports SwiftUI or AppKit (or Cocoa).** No exception to this rule is proposed.
- It is pure and deterministic. Every type is a `Sendable` value type, and every function either has no side effects or has its side effects injected.
- Later phases will add **shared contracts** here: protocols that features depend on, implemented by a future services module (§7.1). Phase 01 defines **no** protocols, because nothing yet has two implementations or needs a test double.

### 2.3 `DoomFeatures` (package library)
**Owns:** SwiftUI views, view models, presentation state, UI-specific behaviour, the design system (`DoomTheme`), and the mapping of domain errors to user-facing text.

**Rules:**
- It depends on `DoomCore` and `SwiftUI`. It may import `AppKit` only when a feature genuinely requires it (for example the future `NSPanel`), and must document why.
- It must not read `Bundle.main`, `ProcessInfo`, `UserDefaults.standard` or any other process global. Everything comes in through `AppContext` or initializer parameters.
- Each feature lives in its own folder (`Home/` in Phase 01). Phase 01 creates **no** folders for future features.

### 2.4 Dependency direction (compiler-enforced)
```
DOOM (app target) ──► DoomFeatures ──► DoomCore
DOOM (app target) ─────────────────────► DoomCore
DoomCoreTests ──► DoomCore
DoomFeaturesTests ──► DoomFeatures, DoomCore
```
Forbidden: `DoomCore → DoomFeatures`, `DoomCore → SwiftUI/AppKit`, and any package module importing the app target. `Package.swift` declares the allowed edges, so a violation fails to compile. Import rules are additionally checked by `grep` during review (`ENGINEERING_STANDARDS.md` §8).

### 2.5 Why only three modules
Each extra module adds build configuration, access-control friction and cognitive cost. The test for creating a module is: *does it have a distinct dependency profile that must be enforced?*
- `DoomCore` (no UI frameworks) and `DoomFeatures` (UI frameworks) differ, and the boundary protects testability and portability of logic.
- A `DoomServices` module, for concrete system integrations such as Keychain, Accessibility, event taps and HTTP, has a distinct profile (system frameworks, privileged APIs). It is **deferred** until the first phase that needs one (**D-03**). Creating it empty now would be a placeholder.
- Splitting features into per-feature modules is not justified at this size.

---

## 3. Application lifecycle (Phase 01)

```
process start
  └─ AppDelegate.init()                      [main actor]
       └─ AppContext.make(infoDictionary: Bundle.main.infoDictionary ?? [:],
                          arguments: ProcessInfo.processInfo.arguments)
          (pure, microseconds: dictionary reads + regex validation; no I/O, no network)
  └─ SwiftUI builds the single `Window` scene → HomeView(viewModel: HomeViewModel(context:))
  └─ applicationDidFinishLaunching
       ├─ log "launch finished" (lifecycle)
       ├─ if context.configurationIssue → log fallback warning (configuration; key name only)
       └─ if context.launchOptions.isSmokeTest → schedule smoke check (1 s): visible window?
            ├─ yes → write "DOOM_SMOKE_OK" to stdout → NSApp.terminate(nil)
            └─ no  → log error → exit(EXIT_FAILURE)
user closes window or presses ⌘Q
  └─ applicationShouldTerminateAfterLastWindowClosed → true (Phase 01 Dock-app behaviour)
  └─ applicationWillTerminate → log "will terminate"
```
**Startup guarantees:** no network requests, no permission checks or prompts, no Accessibility/TCC API calls, no hardware probing, no file I/O outside the app bundle, no timers (except the smoke-test one, which runs only with the flag) and no background tasks.

**Future note:** if DOOM becomes a menu-bar agent (`LSUIElement`, deferred decision **DD-01**, since resolved: P2-01 makes DOOM a menu-bar agent, implemented in M02), `applicationShouldTerminateAfterLastWindowClosed` will change. That is why lifecycle policy lives in `AppDelegate` rather than being spread across SwiftUI scenes.

---

## 4. Configuration and application identity

- **Source of truth:** build settings in `Config/DOOM.xcconfig` (**D-08**). Xcode generates `Info.plist` from them (**D-09**):
  - `PRODUCT_NAME` → `CFBundleName`
  - `PRODUCT_BUNDLE_IDENTIFIER` → `CFBundleIdentifier`
  - `MARKETING_VERSION` → `CFBundleShortVersionString`
  - `CURRENT_PROJECT_VERSION` → `CFBundleVersion`
  - `MACOSX_DEPLOYMENT_TARGET` → `LSMinimumSystemVersion`
  - `INFOPLIST_KEY_CFBundleDisplayName` → `CFBundleDisplayName`
- **Runtime model:** `AppConfiguration` is a validated value built from the info dictionary. Validation rules are in `ENGINEERING_STANDARDS.md` §3.
- **Safe fallback:** if validation fails, `AppContext.make` uses `AppConfiguration.fallback` and records the `ConfigurationError` as `configurationIssue`. The app never crashes over configuration. The UI shows a *degraded* status, and the log records only the offending key name. The fallback identifier (`local.doom.unbundled`) is deliberately different from the real bundle ID, so fallback logs can't be confused with normal ones.
- **What configuration is not:** it never holds secrets, user content, feature flags from a server, or anything fetched over the network.
- **Machine- and person-specific settings** (development team, signing identity) live in the git-ignored `Config/Local.xcconfig`, which is included optionally (**D-08**, **D-19**).

---

## 5. Error-handling approach

1. **Expected failures are typed values.** Each domain gets a closed `enum` that is `Error, Equatable, Sendable` (Phase 01: `ConfigurationError`). Core APIs with a single error domain use **typed throws** (`throws(ConfigurationError)`).
2. **Domain errors carry facts, not copy.** Associated values are limited to non-sensitive identifiers (for example a plist key name) and fixed reason codes. Never user content, values that could be secret, or file paths.
3. **Presentation is a feature concern.** View models translate domain errors into user-facing text and status. Raw `localizedDescription` from system errors is never shown, because it can contain paths or internal detail.
4. **Expected errors never crash.** No `fatalError`, `try!`, `preconditionFailure` or force unwrap on any path driven by external input (bundle data, arguments, future network or system responses). Programmer errors may use `assertionFailure` (debug only) when there is a safe release fallback.
5. **Recoverable errors degrade gracefully.** Configuration failure leads to a fallback configuration and a visible degraded status. Later phases follow the same pattern: a failed capability is reported and leaves the rest of the app usable.
6. **Errors are logged once**, at the boundary where they are handled, using the privacy rules in §8.

---

## 6. Concurrency approach

- **Swift 6 language mode with complete strict-concurrency checking** in every target, the app target and both package libraries, under identical rules (**D-05**).
- **Explicit isolation.** UI types (`App`, `AppDelegate`, views, view models) are `@MainActor`, either explicitly or through SDK inheritance. Phase 01 does not rely on Xcode's "default actor isolation" or "approachable concurrency" build settings. Those settings exist only in newer Xcode versions and don't apply to Swift package targets, so using them would give the app target different semantics from the packages.
- **`DoomCore` is nonisolated.** It contains only immutable `Sendable` value types and has no global mutable state. It needs no actors because no shared mutable state exists.
- **Prohibited without a documented justification in code review:** `@unchecked Sendable`, `nonisolated(unsafe)`, `Task.detached`, `DispatchQueue`/GCD in new code, and `MainActor.assumeIsolated`.
- **Future guidance (not implemented):**
  - Services that own mutable state, such as a request coordinator, should be `actor`s.
  - Synchronous cross-process calls (Accessibility IPC, pasteboard round trips) must not block the main actor for unbounded time, and must have timeouts.
  - Network work must be cancellable. Dismissing the panel cancels in-flight requests.
  - C callback APIs (event taps) must bridge onto the main actor or an actor explicitly.
  - The rules above are expected to apply; the details will be designed in their phase.

---

## 7. Future extensibility and constraints

### 7.1 How the foundation grows
| Future capability | Expected home | Notes |
|---|---|---|
| Activation shortcuts | Contract in `DoomCore`; implementation in `DoomServices`; settings UI in `DoomFeatures` | See constraints in §7.2 (C-1, C-2) |
| Selected-text acquisition | Contract in `DoomCore`; Accessibility implementation in `DoomServices` | Requires a non-sandboxed app (**D-17**) |
| Clipboard fallback | `DoomServices`, behind the same selection contract | Opt-in product decision (**DD-04**) |
| Gemini integration | HTTP client in `DoomServices`; request/response domain types in `DoomCore`; view model in `DoomFeatures` | Network only on explicit user action |
| Keychain storage | `DoomServices`; contract in `DoomCore` | Needs a team-signed build (**D-19**) |
| Floating response panel | `DoomFeatures` (AppKit `NSPanel` hosting SwiftUI) | Non-activating; see §7.2 (C-7) |
| Permission management | Status contract in `DoomCore`; system checks in `DoomServices`; onboarding UI in `DoomFeatures` | Never prompts at launch |
| Diagnostics | `DoomCore` (redaction rules) + `DoomFeatures` (user-initiated export) | No telemetry (**D-24**) |
| Packaging and distribution | Xcode Archive → Developer ID → notarization | Needs a paid Apple Developer Program membership (**DD-08**) |

The composition root (the app target) will build concrete services and inject them through `AppContext` (or a successor dependency struct). Features depend only on the contracts in `DoomCore`, so view models stay unit-testable with simple fakes.

### 7.2 Constraints introduced by future features (documented now; **none implemented**)

**C-1 Global activation shortcut `Fn + Control + Option` — feasibility unproven.**
- It is a *modifier-only* chord that includes **Fn**. Carbon `RegisterEventHotKey` needs a non-modifier key code and has no Fn modifier, so it cannot express this chord. A realistic implementation is a `CGEventTap` observing `flagsChanged` events, where Fn appears as key code 63 with `maskSecondaryFn`. A listen-only tap requires the **Input Monitoring** privilege; an active (event-modifying) tap requires **Accessibility**. *[Verified via developer reports and Apple DTS forum answers; see Sources.]*
- Known hazards:
  - **Globe-key system action.** macOS may treat a lone Fn/Globe press as a system action (emoji picker, input-source switch or dictation, per System Settings).
  - **Fn added by macOS.** The system adds the Fn flag to arrow and F-key events on its own.
  - **External keyboards.** Many third-party keyboards handle Fn in firmware and never send it to macOS.
  - **macOS 27 report.** One developer report says the macOS 27 beta stopped sending bare Fn `flagsChanged` events to event taps. *[Unverified.]*
  - **VoiceOver conflict.** **Control + Option is the VoiceOver modifier**, so the chord can collide with assistive-technology use.
  - **Secure input.** Secure event input (password fields) can hide keyboard events from taps.
- **Requirement:** the implementing phase must run a feasibility spike on the user's actual MacBook Air and macOS version, test the built-in and any external keyboard, and report the results. **The shortcut must not be silently replaced.** If it is infeasible or unreliable, the user decides on an alternative.

**C-2 Panel hide/show shortcut `Control + Shift + H`.**
- This is a conventional key-plus-modifiers combination. It is expected to be registrable with Carbon `RegisterEventHotKey`, which is not believed to need a TCC privilege. *[Assumed; verify in the implementing phase.]*
- A global registration takes the combination away from every app while DOOM runs, and registration can fail if another app already owns it. The failure must be surfaced, not ignored.

**C-3 Selected-text acquisition through Accessibility.**
- It requires the **Accessibility** privilege. Apple DTS states that using the Accessibility API to inspect other apps is **not compatible with App Sandbox**. So DOOM must be **non-sandboxed** and cannot ship through the Mac App Store (**D-17**). *[Verified; see Sources.]*
- Accessibility calls are synchronous cross-process IPC and can stall on unresponsive apps. They need messaging timeouts and must not block the main actor.
- Chromium-based browsers may expose web-content accessibility only when assistive technology is detected or explicitly enabled. Canvas-rendered editors may expose no selected text at all. *[Assumed; verify against Chrome on the user's Mac.]*
- Grants are tied to the app's code signature: an ad-hoc-signed rebuild loses them. A **stable signing identity** is therefore a prerequisite (**D-19**).

**C-4 Clipboard fallback and restoration.**
- Copying the selection means synthesising ⌘C (an event-posting privilege), waiting for `NSPasteboard.changeCount` to change (with a timeout), reading the result, then restoring the previous contents.
- Restoration must preserve **all items and all types**. Items marked concealed or transient (for example from password managers, `org.nspasteboard.ConcealedType` / `TransientType`) must be skipped and never read or persisted.
- Restoration cannot be atomic: clipboard managers and the user can race it.
- macOS 15.4 added `NSPasteboard.accessBehavior` and announced alerts when an app reads the pasteboard programmatically outside a user-initiated paste. Enforcement status varies by macOS version and is not yet settled. *[Verified that the API exists; enforcement unverified.]* The fallback may therefore trigger a system privacy prompt.
- **This is a product decision:** the clipboard fallback should be opt-in (**DD-04**).

**C-5 Gemini integration.**
- Network requests happen only on an explicit user action, never at launch.
- The API key is sent only in the `x-goog-api-key` header, never in a URL.
- Requests must support cancellation, timeouts, mapping of rate-limit and server errors, and possibly streaming.
- The model identifier must be configurable in one place.
- **Privacy constraint *[Verified]*:** under the Gemini API terms, content sent on *unpaid* tiers may be used to improve Google products and **may be read by human reviewers**, and Google advises not to submit sensitive or personal information. Paid-tier content is not used for product improvement. Selected text can be sensitive, so the tier policy and how it is disclosed to the user are product decisions (**DD-06**).

**C-6 Keychain storage.**
- Apple's TN3137 describes the file-based keychain as "on the road to deprecation". The recommended **data protection keychain** requires the `application-identifier` / keychain-access-group entitlement, which must be authorised by a provisioning profile. In practice that means a team-signed build with an Xcode-managed profile, which an ad-hoc-signed bundle cannot provide. This is a key reason for **D-01**. *[Verified; see Sources.]*
- Items will use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and must never sync. Decide in that phase.

**C-7 Floating response panel.**
- It must be a **non-activating** `NSPanel`, so the source app keeps focus and its selection. It will host SwiftUI through `NSHostingView` and therefore lives in `DoomFeatures` with an `AppKit` import.
- Window level, Spaces and full-screen behaviour, multi-display placement and keyboard handling (Escape) inside a non-activating panel all need design work.
- **Screen-capture exclusion cannot be promised.**
  - Apple's documentation describes `NSWindow.SharingType.none` as "a legacy constant that macOS no longer uses".
  - Apple DTS has stated that there are no public APIs for preventing screen capture.
  - Developer reports conflict, and the behaviour varies by macOS version and capture method (ScreenCaptureKit, `screencapture`, video-conferencing apps).
  - At most, a "hide from capture" option is **best-effort**. It must be verified per macOS version, labelled honestly in the UI, and never presented as a guarantee. *[Verified; see Sources.]*

**C-8 Permission management.**
- It checks status with non-prompting APIs (for example `AXIsProcessTrusted()` and `CGPreflightListenEventAccess()`) and prompts only in response to explicit user action in an onboarding or settings flow.
- It handles revocation while the app is running.
- It never requests a permission that a shipped feature doesn't use, and never adds `*UsageDescription` keys ahead of need.

**C-9 Advanced diagnostics.**
- Diagnostics are user-initiated, local and redacted. They contain no content (selected text, prompts, responses), no keys and no home-directory paths. Collection is off by default, with no automatic upload.

**C-10 Packaging and distribution.**
- Non-sandboxed distribution means a Developer ID-signed, hardened-runtime (**D-18**), notarized app, which needs a paid Apple Developer Program membership.
- An auto-update mechanism would probably mean a third-party framework and needs separate approval (**DD-09**).
- The product name "DOOM" has trademark exposure if distributed publicly (`PHASE_01_SUMMARY.md` §4).

### 7.3 Cross-cutting rules that follow from these constraints
1. DOOM is a **non-sandboxed** app (**D-17**). Every privileged capability is gated by explicit TCC consent requested in context.
2. A **stable, team-based signing identity** must exist before the first phase that uses TCC or the Keychain (**D-19**).
3. **User content** (selected text, prompts, responses, clipboard) flows only in memory. It is never logged or persisted unless a future, approved feature such as history says otherwise. It leaves the device only on explicit user action, to the configured AI provider.
4. **System integrations** sit behind `DoomCore` contracts. Features never call privileged system APIs directly.

---

## 8. Logging strategy

- **Facility:** Apple unified logging (`os.Logger`). The subsystem is the bundle identifier (the fallback identifier when the configuration is degraded). Phase 01 categories are `lifecycle` and `configuration`; categories are added only with the feature that needs them.
- **Levels:**
  - `debug` for development detail (not persisted by default)
  - `info` for routine lifecycle events
  - `notice` for significant state changes
  - `error` for handled failures
  - `fault` for programmer or system faults
- **Privacy:**
  - Never log API keys, tokens, selected text, prompts, model responses, clipboard contents, window titles, URLs, document names, or user-identifying file paths. This applies at every level, including `debug`, and even with `.private` redaction.
  - The only dynamic values allowed in logs are **allowlisted non-sensitive values** (enum case names, plist key names, counts, durations, HTTP status codes), marked `privacy: .public`.
  - Any other dynamic value must use `.private`, or `.private(mask: .hash)` for correlation.
- **No custom log files and no remote logging** in Phase 01. User-initiated diagnostics export is deferred (C-9).
- **stdout/`print` is prohibited.** The single exception is the `DOOM_SMOKE_OK` marker that the smoke test reads (**D-15**).

Phase 01 log events: launch finished, configuration fallback in use (key name), smoke test terminating, smoke test failed (no visible window), will terminate.

---

## 9. Security and privacy boundaries (Phase 01)

| Principle | How the foundation enforces it |
|---|---|
| No hardcoded credentials or keys in source control | No credential exists in Phase 01. `scripts/check-secrets.sh` scans committable files for Google API-key patterns, private keys and credential-type files. `.gitignore` covers `.env*`, `Local.xcconfig`, certificates and profiles. |
| No unnecessary network requests | Phase 01 contains no networking code; review greps for `URLSession`. |
| No unnecessary permissions at startup | No `*UsageDescription` keys, no TCC API calls. `scripts/verify-bundle.sh` fails if usage descriptions appear. |
| No sensitive data in logs | Logging policy (§8) and review checks. |
| No unjustified third-party dependency | Zero dependencies (**D-20**). |
| No fabricated permissions or capabilities | Capabilities with unproven feasibility (C-1, C-7 capture exclusion) are recorded as risks, not promises. |
| No analytics or telemetry | None without explicit product approval (**D-24**). |
| No claims without evidence | Every verification result must cite command output (`ENGINEERING_STANDARDS.md` §7). |
| Sandbox / runtime posture | Non-sandboxed (required by C-3), with hardened runtime from day one (**D-18**). |

**Technical feasibility vs product requirements.** Some items are technically possible but need product approval: clipboard fallback (opt-in?), Gemini tier policy, a hide-from-capture option, menu-bar agent mode, diagnostics export. Others are product requirements whose technical feasibility is not yet proven: the `Fn + Control + Option` chord, and reliable selected-text capture in every Chrome context. `PHASE_01_SUMMARY.md` tracks both lists.

---

## 10. Architecture trade-offs

| Choice | Benefit | Cost / risk accepted |
|---|---|---|
| Xcode project for the app plus a local Swift package for modules (**D-01**) | A real bundle on every run; native debugging, signing, provisioning, entitlements, assets, Archive and notarization; package modules stay plain text and testable from the command line | A `project.pbxproj` exists. It is mitigated by Xcode 16+ synchronized folders, a tiny app target and settings in xcconfig. The project must initially be created in the Xcode GUI (**D-02**). *Phase 03: amended by P3-01. Antigravity authors the project, and the GUI is the fallback.* |
| Three modules | Enforced UI/logic boundary with minimal ceremony | Contracts and services arrive later and require a new module when first needed |
| No protocols or DI framework in Phase 01 | No speculative abstraction | Later phases add contracts deliberately |
| Value-type view model in Phase 01 | Simple and deterministic | Must be promoted to an `@Observable` class when mutable state appears |
| Typed throws in Core | Exhaustive and precise error handling | Requires a Swift 6 toolchain (Xcode 16+) |
| Smoke-test launch flag in production code | Automated, evidence-based launch/quit verification | A few lines of test hook, inert without the flag |
| Non-sandboxed | Makes the core product (Accessibility selection) possible | No Mac App Store; a larger security responsibility on DOOM itself |
| Fallback configuration instead of crashing | Robust startup | Must be clearly visible (degraded status), so misconfiguration isn't silent |

---

## Sources (consulted 2026-10-24)
- Apple Developer, Xcode support matrix: https://developer.apple.com/support/xcode/
- Apple DTS, Accessibility API not available in sandboxed apps; Input Monitoring vs Accessibility for event taps: https://developer.apple.com/forums/thread/749494 , https://developer.apple.com/forums/thread/789896 , https://origin-devforums.apple.com/forums/thread/707680
- Fn delivered as `flagsChanged` key code 63 / `maskSecondaryFn`: https://developer.apple.com/documentation/coregraphics/cgeventflags/masksecondaryfn , https://github.com/aipixelsmashing/vox/pull/29 ; Globe-key system action after lone Fn: https://github.com/fancyHeat/agt/pull/58 ; macOS 27 beta report and third-party keyboard behaviour (unverified): https://github.com/humanitas-labs/parrot/issues/42
- Pasteboard privacy (`accessBehavior`, macOS 15.4): https://developer.apple.com/documentation/AppKit/NSPasteboard/accessBehavior-86972 , https://mjtsai.com/blog/2025/05/12/pasteboard-privacy-preview-in-macos-15-4/
- Screen capture: https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none , https://developer.apple.com/forums/thread/792152
- Keychain implementations (TN3137 summary by Apple DTS): https://developer.apple.com/forums/thread/696431 , https://developer.apple.com/forums/thread/759481
- Gemini API Additional Terms: https://ai.google.dev/gemini-api/terms
- Ad-hoc signatures pin TCC grants to the cdhash: https://github.com/pathorsAI/parley/issues/75
