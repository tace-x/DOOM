# DOOM — Engineering Standards

| | |
|---|---|
| **Status** | Approved. Phase 01 design, amended by Phase 02 (§C of `TECHNICAL_DECISIONS.md`) and Phase 03 (§D). Not yet implemented |
| **Date** | 2026-10-24 |
| **Applies to** | All code, configuration and scripts in the DOOM repository, written by humans or agents |

**MUST** means the rule is mandatory: a violation blocks acceptance. **SHOULD** means it is strongly recommended: a deviation needs a stated reason.

---

## 1. Swift conventions

### 1.1 Toolchain and language
- **MUST** build with full **Xcode 16.0 or later** (Swift 6 toolchain), selected through `xcode-select`. Command Line Tools alone are unsupported (D-14).
- **MUST** use Swift 6 language mode everywhere. The package uses `swift-tools-version: 6.0`; the app target uses `SWIFT_VERSION = 6.0` (D-05).
- **MUST NOT** add `unsafeFlags`, experimental features or upcoming-feature flags without a recorded decision.

### 1.2 Naming
- Follow the Swift API Design Guidelines. Types are `UpperCamelCase`; functions, properties and cases are `lowerCamelCase`.
- **MUST** name files after their primary type (`AppConfiguration.swift`), with one primary type per file. Small, tightly coupled nested types may share the file.
- **MUST** name Boolean properties as assertions (`isSmokeTest`, `hasIssue`).
- **MUST NOT** use vague suffixes: `Manager`, `Helper`, `Util(s)`, `Handler` (unless it literally handles a callback) or `Base`. Name things for what they are.
- The `Doom` prefix is used only for module names and `DoomTheme`, not for every type.
- Spell out identifiers (`bundleIdentifier`, not `bid`). Acronyms follow Swift convention (`URL`, `ID`).

### 1.3 Access control
- Default is `internal`. **MUST** mark as `public` only the API that another module needs.
- **MUST** mark helpers `private` (or `fileprivate` when an extension in the same file needs them).
- **MUST** declare classes `final` unless designed for subclassing. **MUST NOT** use `open`.
- Tests **SHOULD** use public API. `@testable import` is allowed only with a comment explaining why.

### 1.4 Code organisation
- Value types (`struct`, `enum`) by default. Use classes only for identity or required reference semantics (for example `NSApplicationDelegate` and future `@Observable` view models).
- **MUST NOT** have singletons, global mutable state or `static var` stored mutable properties.
- **MUST NOT** force unwrap (`!`), use implicitly unwrapped optionals or `try!` on any path that touches external data. Use `guard` and early exits.
- Use protocol conformances in extensions. Use `// MARK: -` sparingly.
- Keep views free of logic: formatting, mapping and decisions live in view models.
- Keep functions small and single-purpose. Prefer clarity over cleverness.
- Indent with 4 spaces, with a soft line limit of 120 columns. No formatter or linter is enforced in Phase 01 (D-20). Adopting the toolchain's `swift format` later needs a decision.

### 1.5 Compiler warnings
- **MUST** have zero warnings at every handoff. This is enforced by the verification commands (`-Xswiftc -warnings-as-errors`; `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` on the `xcodebuild` command line). It is not a committed build setting (D-26).
- **MUST NOT** silence warnings with blanket suppressions, `@preconcurrency` imports or `@unchecked Sendable` without written justification.

---

## 2. Concurrency requirements
- **MUST** use complete strict-concurrency checking in all targets. **MUST NOT** use the Xcode default-actor-isolation or approachable-concurrency settings (D-05).
- **MUST** isolate UI types to `@MainActor`, explicitly or through SDK inheritance: `App`, `AppDelegate`, views and view models.
- **MUST** make `DoomCore` types `Sendable` value types without isolation. `DoomCore` has no global mutable state.
- **MUST NOT**, without a justification comment and reviewer acceptance, use:
  - `@unchecked Sendable`
  - `nonisolated(unsafe)`
  - `Task.detached`
  - `MainActor.assumeIsolated`
  - `DispatchQueue`/GCD in new code
  - `Thread.sleep`
  - semaphores for async bridging
- **SHOULD** use structured concurrency (`async let`, task groups) over unstructured `Task {}`. Every unstructured `Task` needs a clear owner and a cancellation story.
- Delays use `Task.sleep(for:)`, never busy waits. In Phase 01 the only delay is the smoke check.
- **Future-phase rules** (recorded now so they shape design):
  - Mutable shared state goes in an `actor`.
  - Blocking cross-process calls (Accessibility, pasteboard) are never run unbounded on the main actor, and always have timeouts.
  - Network calls are cancellable.
  - C callbacks are bridged explicitly.

---

## 3. Configuration standards

### 3.1 Bundle metadata
- **MUST** keep all bundle metadata in `Config/DOOM.xcconfig` and generate `Info.plist` from it (D-08, D-09). The required keys are in `PROJECT_STRUCTURE.md` §3.
- **MUST NOT** put target-level overrides in `project.pbxproj`. `xcodebuild -showBuildSettings -scheme DOOM` must show the xcconfig values.
- **MUST NOT** commit `DEVELOPMENT_TEAM`, signing identities, machine paths or user names. Those belong in the git-ignored `Config/Local.xcconfig`.
- **MUST NOT** add `*UsageDescription` keys, `LSUIElement` or entitlements unless a recorded decision requires them. `LSUIElement` arrives in M02 (P2-01); an entitlements file only under the P3-13 contingency. No `*UsageDescription` key is required by the approved design.

### 3.2 Minimum macOS and versions
- `MACOSX_DEPLOYMENT_TARGET` and `Package.swift` `platforms` **MUST** match. The value is the verified macOS major version from M00, expected 27.0 (**P3-02**).
- `MARKETING_VERSION` follows SemVer `MAJOR.MINOR.PATCH`. `0.x` signals pre-release.
- `CURRENT_PROJECT_VERSION` is a positive integer that **MUST** increase for every build handed to the user.
- **MUST NOT** check OS versions with string parsing. Use `if #available` / `@available`.

### 3.3 Validation rules (`AppConfiguration.load`)
Rules are applied in this order; the first failure is thrown:
1. **Display name.** Use the trimmed `CFBundleDisplayName` if it is non-empty, otherwise the trimmed `CFBundleName`. If neither exists, throw `.missingValue(key: "CFBundleDisplayName")`.
2. **`CFBundleIdentifier`.** It is required. It must fully match `^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$`, otherwise throw `.invalidValue(key:, reason: .notReverseDNS)`.
3. **`CFBundleShortVersionString`.** It is required. It must fully match `^[0-9]+(\.[0-9]+){0,2}$`, otherwise throw `.notVersionFormat`.
4. **`CFBundleVersion`.** It is required, with the same pattern, otherwise throw `.notBuildFormat`.

Further rules:
- Values are trimmed before validation.
- A non-`String` value, or a value that is empty after trimming, counts as **missing**.
- Swift `Regex` literals **MUST** be declared inside function bodies, not as `static let`, because `Regex` is not `Sendable`.

### 3.4 Safe fallback
- Configuration failure **MUST NOT** crash or block launch. `AppContext.make` substitutes `AppConfiguration.fallback` (bundle ID `local.doom.unbundled`) and records the error.
- The degraded state **MUST** be visible in the UI and logged once, with the key name only.

---

## 4. Error-handling standards
- **MUST** model expected failures as typed `enum`s that conform to `Error, Equatable, Sendable`. Use typed throws (`throws(DomainError)`) for single-domain Core APIs.
- **MUST NOT** put user-facing text, user content, secrets, file paths or offending raw values in error cases. Use identifiers and fixed reason codes only.
- **MUST** map domain errors to user text in view models. **MUST NOT** show raw `localizedDescription` or `String(describing: error)` to users.
- **MUST NOT** use `fatalError`, `preconditionFailure`, `try!` or force unwraps on paths driven by external input. `assertionFailure` is allowed for programmer errors that have a safe release fallback.
- The single allowed `exit(EXIT_FAILURE)` is the smoke-test failure path (D-15).
- **MUST** log errors once, where they are handled, following §5.
- **SHOULD** degrade gracefully: one failed capability must not take down unrelated functionality.

---

## 5. Logging and privacy requirements
- **MUST** use `os.Logger` created through `Logger(category:configuration:)`. The subsystem is the bundle identifier. Categories are defined in `LogCategory` and added only with the feature that needs them.
- **MUST NOT** use `print`, `NSLog`, `debugPrint` or `dump`. The **only** exception is the `DOOM_SMOKE_OK` marker, written with `FileHandle.standardOutput.write(…)`, which is unbuffered.
- **MUST NOT ever log**, at any level including `debug` and even as `.private`:
  - API keys, tokens or authorization headers
  - selected text, prompts, model responses
  - clipboard or pasteboard contents
  - window titles, URLs, document names
  - user-identifying file paths (anything under the home directory)
  - keystroke data
- **MUST** mark allowlisted non-sensitive dynamic values explicitly `privacy: .public`. The allowlist is: enum case names, plist key names, counts, durations, HTTP status codes and error reason codes.
- **MUST** mark every other dynamic value `.private`, or `.private(mask: .hash)` when correlation is needed.
- **MUST NOT** write custom log files or send logs remotely. Diagnostics export is a deferred feature with its own redaction rules (C-9).
- Choose levels deliberately: `debug` for developer detail, `info` for routine lifecycle, `notice` for significant changes, `error` for handled failures, `fault` for bugs or system faults.

---

## 6. Git and repository hygiene

### 6.1 `.gitignore` (required entries)
```
.DS_Store
/build
.build
.swiftpm
xcuserdata/
*.xcuserstate
DerivedData/
Config/Local.xcconfig
.env
.env.*
*.p12
*.pem
*.key
*.mobileprovision
*.provisionprofile
*.log
```
Directory patterns that must match before the directory exists (`build`, `.build`, `.swiftpm`) are written **without a trailing slash**. A trailing-slash pattern does not match a path that doesn't exist yet. This was found and fixed while testing an earlier draft.

### 6.2 What is committed
- **Committed:** source, tests, `Package.swift`, `project.pbxproj`, the shared scheme, workspace `contents.xcworkspacedata`, `Config/DOOM.xcconfig`, `Config/Local.xcconfig.example`, scripts (executable bit set) and docs.
- **Never committed:** anything matched above, `xcuserdata`, built products, logs, credentials, personal team IDs, absolute machine paths.

### 6.3 Secret scanning
- `scripts/check-secrets.sh` **MUST** pass before every handoff. It scans tracked plus untracked-but-not-ignored files for Google API-key patterns and private-key blocks, and checks for credential-type files that would be committed.
- If a secret is ever committed, treat it as compromised: **revoke and rotate it first**, then remove it from history. This needs user approval.

### 6.4 Safe operations
- Agents **MUST NOT** commit, push, amend, rebase, force-push, `git reset --hard`, `git clean -fdx`, or delete files outside `build/` and `DoomKit/.build`, without explicit user approval (D-25).
- **MUST NOT** re-initialise an existing repository.
- Changes are handed over uncommitted, with `git status --short` output.
- Commit messages, when approved, are imperative and scoped, for example `Phase 01: establish foundation`.

---

## 7. Testing expectations

### 7.1 Strategy
- **Unit tests** cover all logic in `DoomCore` and all view-model logic in `DoomFeatures`, using Swift Testing in the package test targets (D-14).
- **Artifact checks** (`verify-bundle.sh`) cover what only exists in the built app: plist, architecture, signature, runtime flags, entitlements.
- **Smoke tests** (`smoke-test.sh`) cover launch → window → clean termination.
- **Manual checks** cover visuals, ⌘Q, closing the window, and the absence of permission prompts.
- **No** snapshot or UI-layout tests in Phase 01. No XCUITest until a decision introduces it.

### 7.2 Rules
- **Deterministic.** No dependence on `Bundle.main`, `ProcessInfo`, the file system, network, clock, locale, time zone or randomness. Inject all inputs, as `AppContext.make(infoDictionary:arguments:)` does.
- **Isolated.** Tests share no mutable state and run correctly in parallel and in any order.
- **Meaningful.** Each test verifies a behaviour that could plausibly break. No tests for constants, generated code or trivial getters. Test counts are not a goal.
- **Parameterised** (`@Test(arguments:)`) for input tables such as invalid identifiers and version formats.
- **Fakes over mocks**, once contracts exist. No mocking frameworks (D-20).
- **MUST NOT** weaken, skip or delete assertions to make a failing test pass. Fix the code, or record a decision.
- **SHOULD** keep the full unit suite under 10 seconds.
- Required Phase 01 coverage: configuration validation, launch options, environment (`AppContext`) construction, view-model mapping and bundle-metadata validation. `PROJECT_STRUCTURE.md` §2.6 lists the cases.

### 7.3 Evidence standard
- A result is reported as **PASS** only with the command and its actual output (or a log excerpt). A step that was not executed is reported as **NOT TESTED**, with the reason. The full status vocabulary is PASS / FAIL / BLOCKED / NOT TESTED / NOT APPLICABLE (P3-11; `TESTING_STRATEGY.md` §2).
- A claim of native macOS verification needs output from a Mac. Output from a Linux environment cannot verify macOS behaviour.
- Implementation summaries are never accepted as evidence.

---

## 8. Review checks (run by the architect at each review)

> **Phase 03 note.** The greps below are the **foundation-stage (M01)** set. From M02 onward the authoritative, milestone-aware set is `TESTING_STRATEGY.md` §6, automated as `scripts/review-checks.sh`. There, each API is allowed only in its owning file (for example `SecItem` only in `KeychainAPIKeyStore.swift`). The "Future-phase leakage" line below applies only to M01.
```bash
# Layering
grep -rnE '^import (SwiftUI|AppKit|Cocoa)' DoomKit/Sources/DoomCore            # expect nothing
grep -rnE '^import (AppKit|Cocoa)' DoomKit/Sources/DoomFeatures                # expect nothing in Phase 01
grep -rnE 'Bundle\.main|ProcessInfo|UserDefaults' DoomKit/Sources              # expect nothing
# Future-phase leakage
grep -rnE 'AXUIElement|AXIsProcessTrusted|CGEvent|RegisterEventHotKey|addGlobalMonitorForEvents|NSPanel|SecItem|URLSession|NSPasteboard|NSAppleScript|generativelanguage|sharingType|LSUIElement|UsageDescription' DOOM DoomKit Config   # expect nothing
# Unsafe patterns
grep -rnE 'fatalError|try!|preconditionFailure|@unchecked Sendable|nonisolated\(unsafe\)|Task\.detached|DispatchQueue|print\(|NSLog' DOOM DoomKit   # expect nothing
# Project-file hygiene
grep -nE 'DEVELOPMENT_TEAM|SWIFT_DEFAULT_ACTOR_ISOLATION|SWIFT_APPROACHABLE_CONCURRENCY|CODE_SIGN_ENTITLEMENTS|PRODUCT_BUNDLE_IDENTIFIER' DOOM.xcodeproj/project.pbxproj   # expect nothing
git status --short ; git check-ignore -v build .build .swiftpm Config/Local.xcconfig .env
scripts/check-secrets.sh
```
On top of the greps, the reviewer reads every source and test file against these standards, and reads `build/verification.log` in full.

---

## 9. UI and accessibility standards (foundation level)
- Colours, gradients and spacing come **only** from `DoomTheme`. Use the system font (SF) only, with no bundled fonts.
- The app is dark-only in Phase 01 (D-21). Text contrast **MUST** stay at or above WCAG AA against the background (the silver and secondary-text tokens on `#0B0D10`–`#1B2026` are chosen for this; verify visually).
- Status **MUST NOT** be conveyed by colour alone. It always has text, and VoiceOver gets a combined label.
- No animation in Phase 01. Future animation **MUST** respect Reduce Motion.
- No Marvel or other proprietary names in the UI beyond the product name, and no proprietary logos, artwork, masks, character silhouettes or fonts.

## 10. Security standards (foundation level)
- No credentials anywhere in the repository or the app bundle. Future secrets go in the Keychain only (D-23).
- No network code, TCC API calls or permission prompts in Phase 01. Future permissions are requested only in context, after explicit user action.
- Non-sandboxed with hardened runtime (D-17, D-18). No runtime-exception entitlements without a decision.
- No third-party code (D-20). No analytics or telemetry (D-24).
- Security claims (for example "no secrets committed") **MUST** be backed by the output of the check that proves them.
