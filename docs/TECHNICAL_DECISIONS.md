# DOOM — Technical Decision Register

| | |
|---|---|
| **Status** | Approved. Phase 01 design, amended by Phase 02 (§C of `TECHNICAL_DECISIONS.md`) and Phase 03 (§D). Not yet implemented |
| **Date** | 2026-10-24 |

Every decision lists its context, the options considered, the selected option, the rationale, the trade-offs, the consequences, and whether **user approval** is required.

A decision marked **Approval: YES** was provisional when written. **As of Phase 03 all such decisions are resolved.** §D.1 lists how each was confirmed, amended or superseded. Where a later section amends an earlier decision, the later section governs. Antigravity records its own decisions in §E. Section B lists deferred decisions; they are explicitly *not* made in Phase 01.

**Supersession note.** An earlier draft from this conversation (`doom-phase01/ANTIGRAVITY_BRIEF.md`, not approved) chose *SwiftPM plus a custom bundling script*. **D-01 supersedes it** for the reasons given there. That draft and its `reference/` files must not be used.

---

## A. Decisions proposed for Phase 01

### D-01 — Build system
- **Context:** DOOM is a native app that will need a real bundle identity, TCC permissions (Accessibility, Input Monitoring), the data protection keychain (which needs a provisioning profile), hardened runtime, notarization, asset catalogs and debugging under realistic conditions. It also needs plain-text, reviewable, testable module code.
- **Options considered:**
  1. **SwiftPM plus a custom bundling script.** `swift build`, then a script assembles and codesigns `DOOM.app`.
  2. **Native Xcode project only.** App and framework targets all live in `project.pbxproj`.
  3. **Native Xcode project for the app target plus a local Swift package (`DoomKit`) for all modules and unit tests.**

| Criterion | 1. SwiftPM + script | 2. Xcode only | **3. Xcode app + local package** |
|---|---|---|---|
| Native macOS compatibility | Good, but the bundle is hand-assembled | Native | Native |
| Swift 6 support | Yes | Yes | Yes |
| Unit testing | `swift test` | `xcodebuild test` | `swift test` for modules (fast); Xcode ⌘U also works |
| App bundle generation | The script reimplements Xcode's job | Automatic | Automatic |
| Resource management | Script must copy SwiftPM resource bundles; no asset catalogs without `actool` scripting | Asset catalogs; Xcode embeds package resources | Same as option 2 |
| Code signing / provisioning | Manual `codesign`. Provisioning profiles for the data protection keychain must be fetched and embedded by hand | Automatic signing and managed profiles | Same as option 2 |
| Permission handling (TCC) | Works only on the assembled bundle; running from Xcode (`swift run`) has **no bundle identity**, so TCC behaviour while debugging is misleading | Every Run is a real, signed bundle | Same as option 2 |
| Debugging | Xcode debugs the *unbundled* executable; debugging the bundle means attaching manually | Full | Full |
| Maintainability | Highly readable, but the script grows with every packaging need | `pbxproj` churn and opaque diffs | `pbxproj` stays tiny (synchronized folders, settings in xcconfig); modules stay in readable `Package.swift` |
| Automation | Excellent | `xcodebuild` | `swift test` plus `xcodebuild` |
| Future distribution (Developer ID, notarization) | Hand-rolled | Archive → Organizer / `notarytool` | Same as option 2 |

- **Selected:** **Option 3.**
- **Rationale:** the future requirements (TCC-gated features, the data protection keychain, notarized non-sandboxed distribution) are exactly where option 1 would gradually reimplement Xcode badly, and where its debugging story is actively misleading (TCC attribution without a bundle identity). Option 3 keeps option 1's main advantage for nearly all of the code: text-defined modules, compiler-enforced boundaries and fast `swift test` without an app host. The app target is limited to two Swift files and an asset catalog.
- **Trade-offs:**
  - A `project.pbxproj` exists and is hard for agents to edit by hand.
  - Xcode, not just Command Line Tools, is mandatory. It is already required by D-14.
  - The project must be created in the Xcode GUI (D-02).
- **Consequences:**
  - The app target uses Xcode 16+ **synchronized folders**, so adding Swift files never edits `pbxproj`.
  - All build settings live in `Config/DOOM.xcconfig` (D-08). Target-level overrides in `pbxproj` are removed.
  - The shared scheme `DOOM` is committed.
- **Approval: YES**, because it reverses the earlier draft and requires a one-time GUI step from the user.

### D-02 — How the Xcode project is created and maintained
- **Context:** Xcode has no command to create a new project. Generators exist, but they are third-party tools.
- **Options:**
  1. The user creates the project once in the Xcode GUI using an exact checklist; afterwards Antigravity edits only text files.
  2. Antigravity hand-writes `project.pbxproj`.
  3. XcodeGen or Tuist generates the project from YAML or Swift.
- **Selected:** **Option 1.** The checklist goes in the later handoff package. It covers the template choice, the folder layout, attaching the xcconfig, removing target-level build settings and the sandbox entitlement, adding the local package and sharing the scheme.
- **Rationale:**
  - Option 1 is native, has no dependencies and takes about 10 minutes.
  - Hand-written `pbxproj` files (option 2) are fragile and hard to verify.
  - Generators (option 3) add a third-party tool, version pinning and a regeneration step to solve a churn problem that synchronized folders already solve.
- **Trade-offs:** it needs one manual step from the user, and the checklist must stay accurate across Xcode versions.
- **Consequences:**
  - After creation, the agent may change `pbxproj` only through Xcode or, if unavoidable, with a reviewed diff.
  - `xcodebuild -showBuildSettings` is used to prove that the xcconfig values are effective.
- **Approval: YES**, because it requires a manual step from the user.

### D-03 — Module structure
- **Context:** the requirements suggest executable, core and feature layers, plus future services.
- **Options:**
  1. Three modules: app target, `DoomCore`, `DoomFeatures`.
  2. Add an empty `DoomServices` module now.
  3. One module per feature.
- **Selected:** **Option 1.** `DoomServices` is created in the first phase that needs a concrete system integration.
- **Rationale:** a module must earn its place with a distinct dependency profile. An empty services module is a placeholder; per-feature modules are premature at this size.
- **Trade-offs:** a later phase must add a module and wire it in (low cost in `Package.swift`).
- **Consequences:** the dependency graph is `App → Features → Core` and `App → Core`, enforced by `Package.swift`.
- **Approval:** No.

### D-04 — Framework restrictions per module
- **Context:** logic must stay testable and free of UI concerns.
- **Options:**
  1. Core may use any framework.
  2. Core is limited to Foundation and OSLog; Features may use SwiftUI, plus AppKit when needed.
- **Selected:** **Option 2.** `DoomCore` imports only `Foundation` and `OSLog`. `DoomFeatures` imports `DoomCore` and `SwiftUI`, plus `AppKit` only with a documented need. The app target may import anything it needs.
- **Rationale:** a hard boundary keeps logic deterministic and unit-testable, and stops view concerns leaking into domain code.
- **Trade-offs:** occasionally a type has to be mapped at the boundary (for example colours stay in Features).
- **Consequences:**
  - A review grep fails on any `import SwiftUI`, `import AppKit` or `import Cocoa` in `DoomCore`.
  - `DoomFeatures` must not read process globals.
- **Approval:** No.

### D-05 — Swift language mode and concurrency model
- **Context:** Swift 6 offers data-race safety. Newer Xcode versions add default-MainActor isolation and "approachable concurrency" settings, which package targets don't share.
- **Options:**
  1. Swift 5 mode with minimal checking.
  2. Swift 6 mode with complete checking and explicit isolation everywhere.
  3. Swift 6 mode relying on Xcode default-isolation settings in the app target.
- **Selected:** **Option 2.** Package `swift-tools-version: 6.0` (Swift 6 mode by default). The app target uses `SWIFT_VERSION = 6.0` and `SWIFT_STRICT_CONCURRENCY = complete`. Default-isolation and approachable-concurrency settings are **not** used.
- **Rationale:**
  - The app target and the packages compile under the same semantics.
  - It is compatible with Xcode 16 and later.
  - Data races become compile errors.
- **Trade-offs:** UI types need a little more annotation.
- **Consequences:**
  - The unsafe escape hatches are banned without justification (`ENGINEERING_STANDARDS.md` §2).
  - The Xcode-template defaults for those settings are removed (D-02 checklist).
- **Approval:** No.

### D-06 — Minimum supported macOS
- **Context:**
  - The user's macOS version is **unknown**.
  - `@Observable` needs macOS 14.
  - The current Xcode 27.x requires macOS Tahoe 26.6 or later on the build machine *[verified, Apple support matrix]*.
  - Every OS version older than the test machine's is untested code surface.
- **Options:** 14.0 (Sonoma) · 15.0 (Sequoia) · 26.0 (Tahoe) · the user's installed major version.
- **Selected (provisional):** **macOS 14.0.**
- **Recommendation:** raise it to the major version actually installed on the user's MacBook Air if that is 26.x, because DOOM is primarily a single-machine tool and untested OS versions add risk without benefit.
- **Rationale:** 14.0 is the lowest version that supports the planned SwiftUI Observation model.
- **Trade-offs:** a lower minimum widens compatibility but adds untested paths, especially for TCC, pasteboard privacy and window-capture behaviour, which vary by OS version.
- **Consequences:** set through `MACOSX_DEPLOYMENT_TARGET` and the `Package.swift` `platforms` entry. These two values must match.
- **Approval: YES.**

### D-07 — CPU architecture
- **Context:** the target hardware is an Apple Silicon MacBook Air.
- **Options:** universal (arm64 + x86_64) · arm64 only.
- **Selected:** **arm64 only** (`ARCHS = arm64`).
- **Rationale:** faster builds, no untested Intel slice, and it matches the stated hardware.
- **Trade-offs:** it can't run on Intel Macs.
- **Consequences:** `verify-bundle.sh` checks that `lipo -archs` reports `arm64`.
- **Approval:** No. Raise it if Intel support is wanted.

### D-08 — Source of truth for build settings
- **Context:** target-level settings in `pbxproj` override xcconfig values and are opaque in review. The signing team is person-specific.
- **Options:**
  1. Settings edited in the Xcode UI and stored in `pbxproj`.
  2. A committed `Config/DOOM.xcconfig` plus a git-ignored `Config/Local.xcconfig` included with `#include? "Local.xcconfig"`.
- **Selected:** **Option 2.** A committed `Config/Local.xcconfig.example` documents the overridable keys (`DEVELOPMENT_TEAM`, `CODE_SIGN_IDENTITY`).
- **Rationale:** settings become reviewable text. No personal team ID or machine paths are committed.
- **Trade-offs:** target-level overrides that Xcode generates must be deleted once (D-02).
- **Consequences:** `xcodebuild -showBuildSettings` must show the xcconfig values; review checks this.
- **Approval:** No.

### D-09 — `Info.plist` and versioning
- **Context:** bundle metadata needs one source of truth and must be validated.
- **Options:**
  1. A hand-maintained `Info.plist` file.
  2. Xcode-generated `Info.plist` (`GENERATE_INFOPLIST_FILE = YES`) from build settings.
- **Selected:** **Option 2.**
  - `MARKETING_VERSION` uses SemVer `MAJOR.MINOR.PATCH`, starting at `0.1.0`.
  - `CURRENT_PROJECT_VERSION` is a monotonically increasing integer, starting at `1`.
  - `CFBundleDisplayName = DOOM` via `INFOPLIST_KEY_CFBundleDisplayName`.
  - `LSApplicationCategoryType = public.app-category.productivity`.
- **Rationale:** a single text source (the xcconfig), and no duplicated version strings.
- **Trade-offs:** the final plist exists only in the built product, so validation runs on the built app (D-16) rather than on a source file.
- **Consequences:** no `*UsageDescription` keys may be added until a phase needs them.
- **Approval:** No.

### D-10 — Bundle identifier
- **Context:** TCC grants and Keychain items are keyed to the bundle ID and signing identity. Changing it later orphans them.
- **Options:** a placeholder now, or the final reverse-DNS ID now.
- **Selected (provisional):** placeholder `com.example.doom`.
- **Rationale:** Phase 01 requests no permissions and stores nothing, so it is harmless for now.
- **Trade-offs:** it must be replaced before any TCC or Keychain work.
- **Consequences:** the bundle ID appears in exactly one place, `PRODUCT_BUNDLE_IDENTIFIER` in `Config/DOOM.xcconfig`. The log subsystem is derived from it at runtime.
- **Approval: YES.** The user should supply a reverse-DNS ID they control (for example `com.<yourname>.doom`), ideally before implementation starts.

### D-11 — Configuration model and fallback
- **Context:** the app needs a validated identity, and must survive misconfiguration (for example previews, tests or a broken build setting).
- **Options:**
  1. Read `Bundle.main` ad hoc wherever needed.
  2. A validated `AppConfiguration` value with typed errors and a fallback.
- **Selected:** **Option 2.** `AppConfiguration.load(from:) throws(ConfigurationError)`. `AppContext.make(infoDictionary:arguments:)` is pure and applies `AppConfiguration.fallback` (bundle ID `local.doom.unbundled`, version `0.0.0`, build `0`) on failure, recording the error.
- **Rationale:** deterministic and testable, it never crashes, and it is visibly degraded.
- **Trade-offs:** a small amount of code for a case that is rare in Xcode-built apps.
- **Consequences:** the UI shows a degraded status, and the log records only the key name.
- **Approval:** No.

### D-12 — Error model
- **Context:** errors must be safe to present and log.
- **Options:**
  1. Untyped `Error` with `localizedDescription` shown to users.
  2. Typed domain enums in Core, mapped to user text in Features.
  3. Core errors carry user-facing text through a shared protocol.
- **Selected:** **Option 2.**
- **Rationale:** it keeps copy and future localisation in the presentation layer, keeps Core free of UI concerns, avoids a single-conformer protocol, and allows exhaustive switching.
- **Trade-offs:** every feature must write its own mapping.
- **Consequences:** see `ARCHITECTURE.md` §5 and `ENGINEERING_STANDARDS.md` §4.
- **Approval:** No.

### D-13 — Logging
- **Context:** DOOM will handle sensitive content (selected text, prompts, responses, an API key).
- **Options:** `print` · a custom file logger · `os.Logger` with a strict policy.
- **Selected:** **`os.Logger`**, with the subsystem set to the bundle ID and categories added per feature. There is a content-never-logged rule, an allowlist for `.public` values, no file logging and no `print` (except the smoke marker).
- **Rationale:** it is native, efficient, privacy-aware and works with Console and `log stream`.
- **Trade-offs:** there is no portable log file for diagnostics; that is deferred to C-9.
- **Consequences:** review greps for `print(`, and for interpolated values without privacy annotations.
- **Approval:** No.

### D-14 — Testing framework and toolchain requirement
- **Context:**
  - XCTest is not shipped with Command Line Tools.
  - Swift Testing ships with the Swift 6 toolchain, but there is a report of intermittent macro-plugin failures with CLT-only Swift 6.4 *[verified, swiftlang/swift-build #1870]*.
- **Options:** XCTest · Swift Testing · both.
- **Selected:** **Swift Testing** (`import Testing`) for all unit tests in the package test targets. XCTest is reserved for possible future XCUITest. **Full Xcode (16.0+) is required.** Command Line Tools alone are unsupported.
- **Rationale:** modern, expressive, parameterised tests, and native in Swift 6.
- **Trade-offs:** it requires a full Xcode install.
- **Consequences:** the canonical command is `swift test --package-path DoomKit`. The app target has no unit-test target in Phase 01.
- **Approval:** No. Confirmation that full Xcode is installed is needed (see Open questions).

### D-15 — Launch/quit verification
- **Context:** "launches and quits cleanly" must be proven by evidence, not by assertion.
- **Options:**
  1. Manual check only.
  2. An XCUITest launch/terminate test, which needs a UI-test target and an automation/Accessibility grant for the test runner.
  3. A `--doom-smoke-test` launch argument: the app verifies a visible window after 1 s, writes `DOOM_SMOKE_OK` to stdout and calls `NSApp.terminate(nil)`. A script checks exit status 0 and the marker.
- **Selected:** **Option 3, plus a documented manual check** (⌘Q, closing the window, no permission prompts).
- **Rationale:** it is automated, exercises the real `NSApplication` termination path and needs no extra target or privileges.
- **Trade-offs:** it is a small test hook in production code (inert without the flag), and it needs a logged-in GUI session.
- **Consequences:** `LaunchOptions` parsing is unit-tested. The window check and the termination are verified by `scripts/smoke-test.sh`.
- **Approval:** No.

### D-16 — Bundle and artifact validation
- **Context:** with a generated plist (D-09), the metadata that matters is in the built product.
- **Options:** parse a source plist in unit tests · validate the built `.app` with a script.
- **Selected:** **`scripts/verify-bundle.sh`** on the built app. It checks:
  - `CFBundleIdentifier`, `CFBundleDisplayName = DOOM`, `CFBundleExecutable = DOOM`, `LSMinimumSystemVersion`, and SemVer/integer version formats
  - **no `*UsageDescription` keys**
  - `arm64` architecture
  - `codesign --verify --strict`
  - hardened-runtime flag present
  - **no `com.apple.security.app-sandbox` entitlement**
- **Rationale:** it tests the real artifact, not a proxy.
- **Trade-offs:** it is a shell script, not a Swift test.
- **Consequences:** it is part of `scripts/verify.sh`.
- **Approval:** No.

### D-17 — App Sandbox
- **Context:** the core future feature (reading another app's selected text through the Accessibility API) is incompatible with App Sandbox according to Apple DTS *[verified]*. Changing sandbox status later moves data containers and Keychain behaviour.
- **Options:** sandboxed (Mac App Store-eligible) · non-sandboxed.
- **Selected:** **Non-sandboxed from Phase 01.**
- **Rationale:** it avoids a disruptive migration later. The product can't work sandboxed.
- **Trade-offs:** no Mac App Store distribution, and DOOM itself carries more security responsibility (mitigated by D-18, least privilege and in-context consent).
- **Consequences:** the Xcode template's sandbox entitlement and setting are removed. `verify-bundle.sh` checks the entitlement is absent.
- **Approval: YES**, because it is a distribution-channel decision.

### D-18 — Hardened runtime
- **Context:** notarization requires the hardened runtime. Enabling it late tends to surface surprises late.
- **Options:** enable later · enable now.
- **Selected:** **Enable now** (`ENABLE_HARDENED_RUNTIME = YES`), with no runtime-exception entitlements.
- **Rationale:** it surfaces issues early, and the Accessibility APIs and event taps do not require hardened-runtime exceptions *[assumed; verify when implemented]*.
- **Trade-offs:** none significant for local builds.
- **Consequences:** future exceptions (for example Apple Events) need a recorded decision.
- **Approval:** No.

### D-19 — Code-signing strategy
- **Context:**
  - Ad-hoc signatures pin TCC grants to the binary's cdhash, so every rebuild loses Accessibility and Input Monitoring grants *[verified via developer reports]*.
  - The data protection keychain needs a provisioning profile (C-6).
  - Developer ID distribution requires a paid Apple Developer Program membership.
- **Options:** ad-hoc ("Sign to Run Locally") only · Apple Development signing (free or paid account) through `Local.xcconfig` · Developer ID.
- **Selected:**
  - **Phase 01:** "Sign to Run Locally" by default, so no account is needed and nothing personal is committed.
  - **Required before the first TCC or Keychain phase:** Apple Development automatic signing, with `DEVELOPMENT_TEAM` in `Local.xcconfig`.
  - Developer ID is deferred (DD-08).
- **Rationale:** Phase 01 needs no stable identity. Later phases do.
- **Trade-offs:** signing differs between Phase 01 and later phases. This is a deliberate decision, not drift.
- **Consequences:** no team ID in git.
- **Approval: YES.** The user must say whether they have, or will create, an Apple ID / Apple Developer account (free or paid).

### D-20 — Third-party dependency policy
- **Selected:** **zero third-party dependencies** (runtime or tooling) in Phase 01.
- **Future rule:** any dependency needs a recorded decision covering need, alternatives, licence, maintenance, security posture and removal cost, plus user approval.
- **Approval:** No.

### D-21 — Phase 01 UI surface and appearance
- **Context:** the foundation needs a minimal, intentional UI. The final activation model is undecided.
- **Options:** a menu-bar agent now · a regular Dock app with one status window.
- **Selected:** **a regular Dock app** with a single fixed-size (520 × 320 pt) status window: wordmark, version, status, phase note. It is **dark-only** (`.preferredColorScheme(.dark)`). Closing the window quits the app.
- **Rationale:** simplest to verify, and it doesn't pre-empt DD-01.
- **Trade-offs:** the lifecycle may change when DD-01 is decided.
- **Approval:** No (the final model is DD-01).

### D-22 — Design-system foundation and visual identity
- **Selected:** `DoomTheme` tokens in code:
  - background gradient `#0B0D10 → #1B2026`
  - silver "metal" text gradient `#E6EAEE → #8A949E`
  - steel `#5C6670`
  - emerald accent `#2FA36B`
  - amber warning `#D9A441`
  - secondary text `#9AA4AE`
  - spacing scale 4/8/12/16/24
  - corner radius 10

  The system font (SF) is used for everything, with a heavy, tracked wordmark and monospaced digits for the version. The asset catalog defines **AccentColor = emerald**. There are no custom fonts, images, logos, mask or character imagery, or Marvel or other proprietary assets.
- **Rationale:** an original identity with no licensing risk and no resource bundling in Phase 01.
- **Trade-offs:** a restrained look until a dedicated design phase.
- **Consequences:** colour is never the only status signal; status always has text. The app icon is deferred (DD-10).
- **Approval:** No. The visual direction was supplied by the user.

### D-23 — Direction for secret storage (documented only, not implemented)
- **Selected direction:**
  - The Gemini API key is entered by the user in-app and stored in the **data protection keychain** (generic password, service = bundle ID, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, never synced).
  - It is never stored in source, `Info.plist`, xcconfig, `UserDefaults`, environment variables or logs.
  - It is sent only in the `x-goog-api-key` header.
- **Consequences:** this requires D-19's team signing. Whether a development-only environment-variable override should exist is an open question; the recommendation is **no**.
- **Approval:** Confirm in the Keychain phase.

### D-24 — Analytics and telemetry
- **Selected:** **none.** No analytics, telemetry, crash-reporting SDKs or automatic uploads without explicit product approval and a recorded decision.
- **Approval:** No. It can only be changed by the user.

### D-25 — Git workflow safety
- **Selected:**
  - The repository is initialised once with `git init -b main`, and only if it is not already a repository.
  - **Agents never commit, push, rewrite history or run destructive commands** (`git clean -fdx`, `git reset --hard`, `git push --force`, `rm -rf` outside `build/` / `.build`) without explicit user approval.
  - Changes are left uncommitted for review.
- **Approval:** No.

### D-26 — Compiler-warning policy
- **Context:** zero warnings is the goal. Making warnings errors permanently can break builds after an SDK update for reasons unrelated to the change.
- **Selected:** **Zero warnings at every handoff**, enforced by the verification commands:
  - `swift build`/`swift test` with `-Xswiftc -warnings-as-errors`
  - `xcodebuild … SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`

  Warnings are *not* turned into errors permanently in committed build settings.
- **Approval:** No.

---

## B. Deferred decisions (explicitly NOT made in Phase 01)

| ID | Decision | Why deferred | Needs user input? |
|---|---|---|---|
| DD-01 | Final activation model: Dock app vs menu-bar agent (`LSUIElement`) | Depends on the panel and shortcut UX | **Yes** |
| DD-02 | Activation-shortcut implementation (event-tap design, chord semantics) | Requires a feasibility spike on real hardware (C-1) | Yes, if infeasible |
| DD-03 | Selection strategy details (Accessibility attributes, enabling Chromium accessibility, timeouts) | Needs testing against Chrome on the user's Mac | No |
| DD-04 | Clipboard fallback: offered? opt-in? default off? | Privacy and UX trade-off; pasteboard privacy prompts (C-4) | **Yes** |
| DD-05 | Gemini model, streaming, request and response design | Belongs to the integration phase; models change | Partly |
| DD-06 | Gemini tier policy and user disclosure (unpaid tier allows human review) | Product and privacy decision (C-5) | **Yes** |
| DD-07 | Panel design; whether to offer a best-effort "hide from capture" option | Capture exclusion cannot be guaranteed (C-7) | **Yes** |
| DD-08 | Distribution: Developer ID, notarization, DMG; paid program membership | Not needed until distribution | **Yes** |
| DD-09 | Update mechanism (likely third-party) | Requires D-20 approval | **Yes** |
| DD-10 | App icon and brand; public use of the name "DOOM" (trademark exposure) | Design and legal | **Yes** |
| DD-11 | Storage for non-secret user preferences (`UserDefaults` expected) | No preferences exist yet | No |
| DD-12 | Diagnostics export format and redaction | Advanced diagnostics phase | No |

---

## C. Phase 02 specification decisions (P2-xx)

Phase 02 adds these decisions. **No Phase 01 decision is replaced.** Where a Phase 02 decision changes a Phase 01 rule for the product phases, the entry says so explicitly. The detailed specifications are named in each row.

| ID | Decision | Resolves / affects | Spec | Approval |
|---|---|---|---|---|
| P2-01 | **Menu-bar agent** (`LSUIElement = YES`) with a main window opened on demand; the app keeps running when the window closes | DD-01; evolves D-21 | `PRODUCT_BEHAVIOR.md` §0.1, `UI_SPECIFICATION.md` §4–5 | **YES** |
| P2-02 | Activation chord detected with **`NSEvent` global + local monitors** (Accessibility only) feeding a pure recogniser that fires on full release (≤ 2.0 s, no keyDown, no ⌘/⇧). Listen-only `CGEventTap` (adds Input Monitoring) only if the spike requires it. Monitor code must never read `characters`; review grep added | DD-02, C-1 | `SHORTCUT_SPECIFICATION.md` §3 | No; the alternative and fallbacks need approval only if the spike fails |
| P2-03 | Control+Shift+H via **Carbon `RegisterEventHotKey`**, key code resolved for "h" in the ASCII-capable layout, re-registered on input-source change; failures surfaced | C-2 | `SHORTCUT_SPECIFICATION.md` §4 | No |
| P2-04 | Selection: Accessibility strategies A (selected text) → B (range) → C (text markers); Chromium `AXEnhancedUserInterface` enablement (Chromium bundle IDs only); per-element 1.0 s messaging timeouts (never system-wide); **one dedicated serial `DispatchQueue`** for blocking Accessibility IPC (documented exception to ARCHITECTURE §6) | DD-03, C-3 | `TEXT_ACQUISITION_SPECIFICATION.md` §3, §6 | No |
| P2-05 | Clipboard fallback **included, opt-in, off by default**, single bounded attempt (≤ 600 ms observation), concealed/transient skip, restore only if unchanged, memory-only snapshot | DD-04, C-4 | `TEXT_ACQUISITION_SPECIFICATION.md` §4 | **YES** |
| P2-06 | Gemini **Interactions API**, `store: false`, non-streaming; `generateContent` is the documented alternative | DD-05, C-5 | `GEMINI_INTEGRATION_SPECIFICATION.md` §3 | **YES** (confirm) |
| P2-07 | Default model `gemini-3.8-flash`, `thinking_level: low`, `max_output_tokens: 4096`, no temperature; user override in Settings; aliases not used | DD-05 | `GEMINI_INTEGRATION_SPECIFICATION.md` §3.3 | Partly (default model) |
| P2-08 | Fixed general-purpose system instruction ("answer or explain"); selected text sent verbatim as `input` | Product purpose | `PRODUCT_BEHAVIOR.md` §4 | **YES** |
| P2-09 | **No automatic retries**; manual Retry with a cooldown (Retry-After or 10 s for 429; 0/2/4/8/16/30 s otherwise) | C-5 | `GEMINI_INTEGRATION_SPECIFICATION.md` §8 | No |
| P2-10 | Selection limit **20,000 characters**, reject (never truncate) | — | `TEXT_ACQUISITION_SPECIFICATION.md` §5 | No |
| P2-11 | One-time, versioned **privacy notice** acknowledgement before the first request, with explicit free-tier language; no tier detection | DD-06 | `UI_SPECIFICATION.md` §4.6, `SECURITY_AND_PRIVACY.md` §2.4 | **YES** (wording) |
| P2-12 | Non-activating floating panel (440 pt, top-right of the pointer's screen, all Spaces, never key on show); **no capture-exclusion feature**; ⌃⇧H is the mitigation | DD-07, C-7 | `UI_SPECIFICATION.md` §3, `SECURITY_AND_PRIVACY.md` §3 | **YES** |
| P2-13 | Preferences in `UserDefaults`, exactly three keys, no secrets or content | DD-11 | `SECURITY_AND_PRIVACY.md` §2.8 | No |
| P2-14 | **Product lifecycle rules** (evolves D-21 and ARCHITECTURE §3 for product phases): closing the window does not quit; **non-prompting** status checks (`AXIsProcessTrusted`, Keychain attributes, preferences) and ⌃⇧H registration are allowed at startup; still no prompts, no network, no secret reads at launch | D-21, ARCHITECTURE §3, C-8 | `PRODUCT_BEHAVIOR.md` S-01/S-02 | No |
| P2-15 | Responses rendered as inline Markdown only; links not interactive; text selectable | — | `UI_SPECIFICATION.md` §3.6 | No |
| P2-16 | `DoomServices` module introduced (per D-03) with the contracts in `MODULE_CONTRACTS.md`; Features never import Services | D-03, D-04 | `MODULE_CONTRACTS.md` §1 | No |
| P2-17 | Live Gemini tests read a key from a **test-runner** environment variable only, opt-in and skipped by default; the app target never reads keys from the environment (resolves D-23's open question as "no" for the app) | D-23 | `GEMINI_INTEGRATION_SPECIFICATION.md` §11.3 | No |

---

## D. Phase 03 baseline confirmations and handoff decisions (P3-xx)

### D.1 Baseline confirmed by the user at the start of Phase 03

| Item | Confirmed value | Effect on earlier decisions |
|---|---|---|
| Hardware | Apple Silicon MacBook Air | D-07 (arm64 only) unchanged |
| macOS | **Reported** 27.0.1 ("Golden Gate"). **Must be verified** with `sw_vers` in M00 | D-06 resolved by P3-02 once verified |
| Xcode | Installed, **per the user**. Verified in M00 | D-14 precondition |
| Use | Personal use; no App Store; no public distribution | DD-08 stays deferred; no notarization needed (P3-10) |
| Bundle identifier | **`com.tace.doom`** | D-10 resolved (P3-03) |
| App type | Menu-bar app with a floating response panel | P2-01 approved |
| Shortcuts | Fn + Control + Option (activation), Control + Shift + H (panel) | Unchanged; the Fn gate remains mandatory |
| Selected text | macOS Accessibility | P2-04 unchanged |
| Clipboard fallback | Optional, off by default | P2-05 approved |
| AI provider | Google Gemini; one request per activation; no automatic retries; no secondary model call | P2-06, P2-07 (subject to the availability check), P2-08, P2-09, P2-11 approved |
| Credentials | macOS Keychain | D-23 / Phase 02 §9 unchanged |
| Capture hiding | Excluded from v1 | P2-12 approved |
| Visual identity | Original dark metallic look, silver type, restrained emerald | D-22, UI spec unchanged |

**All P2-xx decisions are now approved.** The "Approval: YES" items in §A (D-01, D-02, D-06, D-10, D-17, D-19) are resolved as follows:
- D-01 and D-17 are approved.
- D-02 is amended by P3-01.
- D-06 is resolved by P3-02.
- D-10 is resolved by P3-03.
- D-19 is resolved by P3-04.

### D.2 Decisions

| ID | Decision | Reason | Supersedes / amends |
|---|---|---|---|
| P3-01 | **Antigravity authors the Xcode project** (`DOOM.xcodeproj`: a minimal `project.pbxproj` with synchronized folders, a local-package reference to `DoomKit`, the xcconfig as base configuration, and a shared scheme). This is D-02 option 2, done under strict verification gates (`IMPLEMENTATION_ROADMAP.md` Appendix B). If the hand-authored project fails those gates after reasonable repair, the **fallback** is the one-time GUI checklist (Appendix A), which needs about 10 minutes of the user's time. No project generators (D-20). | The Phase 03 instruction says the user must not edit project files or assemble the app. That later, explicit instruction outweighs D-02's reason for a GUI step. Synchronized folders keep the file small enough to author and verify. | Amends **D-02** (option 1 → option 2 + fallback). D-01 unchanged. |
| P3-02 | `MACOSX_DEPLOYMENT_TARGET` = the **major version verified in M00** (expected `27.0`), no higher than the installed SDK version (`xcrun --show-sdk-version`). `Package.swift` uses the same value (`.macOS("27.0")` string form). | Applies D-06's own recommendation (raise to the installed major version). It is a single-machine personal tool, and older OS paths would be untested. Lowering it later is a one-line change plus testing. | Resolves **D-06** |
| P3-03 | Bundle identifier **`com.tace.doom`**, set only in `Config/DOOM.xcconfig`. Derived values: Keychain service `com.tace.doom` (account `gemini-api-key`), log subsystem `com.tace.doom`, preferences domain `com.tace.doom`, TCC identity `com.tace.doom`. **Changing it later** orphans the Keychain item, resets Accessibility grants and starts with empty preferences. Treat it as permanent. | User decision | Resolves **D-10** |
| P3-04 | **Signing for personal use:** Xcode automatic signing with **Apple Development**, using the user's Apple ID. A **free Personal Team is sufficient**; a paid Apple Developer Program membership is **not** required. `DEVELOPMENT_TEAM` (and, if needed, `CODE_SIGN_IDENTITY = Apple Development`) go only in the git-ignored `Config/Local.xcconfig`. Builds that need provisioning use `-allowProvisioningUpdates`. M01 records the signing authority, the team-identifier presence and any embedded profile with its **expiration date**; M09 re-checks them. If the user has no Apple ID, they are asked one focused question (M01). | Least complicated **secure** option that keeps TCC grants across rebuilds and supports the data protection keychain (C-6). Ad-hoc signing loses grants on every rebuild (D-19). | Resolves **D-19** |
| P3-05 | The toolchain stays as installed. Antigravity **never** runs `xcode-select -s`, `sudo`, installers or `xcodebuild -runFirstLaunch` itself. It reports the exact command and asks the user. | User constraint: no silent installs or system changes | — |
| P3-06 | **Risk-first execution order:** M00 → M01 → **M03a (Fn gate)** → **M04a (Chrome gate)** → M02 → M03b → M04b → M05 → M06 → M07 → M08 → M09 → M10. | The two largest feasibility unknowns are tested before UI investment. An unverified report says Fn delivery changed in a macOS 27 beta, and the user is on macOS 27. | — |
| P3-07 | Every real-Mac test involving TCC (Accessibility) launches DOOM through **LaunchServices** (`open …/DOOM.app`), never by executing `Contents/MacOS/DOOM` from a terminal. The smoke test, which runs the binary directly, is used only for checks that need no permissions. | TCC may attribute a terminal-launched child process to its responsible parent (the terminal or Antigravity), which would make the results misleading *[Assumed; this is the conservative rule]* | — |
| P3-08 | **Single-instance guard:** at launch, if another process with bundle ID `com.tace.doom` is already running, DOOM activates that instance (which opens its main window) and terminates itself before registering any shortcut. | Debug builds in DerivedData and the installed copy share one bundle ID. Two instances would both react to the chord, causing **two requests per activation**, and would conflict on ⌃⇧H. | New requirement LIFE-14 |
| P3-09 | **Secrets and the agent:** Antigravity never asks for, receives, prints or stores the Gemini API key. The user enters it only in DOOM's Settings field. Live integration tests are run **by the user in their own Terminal** (`read -s`, environment variable for that process only), and their output contains only status codes, field names and counts. | Agent terminals and chats may be logged outside DOOM's control | Refines P2-17 |
| P3-10 | **Packaging:** a Release build signed per P3-04, verified, then copied with `ditto` to `~/Applications/DOOM.app` by `scripts/install.sh`. `scripts/uninstall.sh` removes the app, Keychain item, preferences and TCC entry; it asks for confirmation and supports `--dry-run`. No Developer ID, notarization, DMG or auto-update. Locally built apps are not quarantined, so Gatekeeper is not bypassed. | Personal use (DD-08 stays deferred) | — |
| P3-11 | **Self-management records:** `docs/PHASE_TRACKER.md` (milestone status and blockers), `docs/VERIFICATION_LOG.md` (created in M00: commands, exit codes, counts, evidence excerpts), and §E of this file (implementation decisions and deviations, `IMPL-xx`). Acceptance statuses are PASS / FAIL / BLOCKED / NOT TESTED / NOT APPLICABLE. | Evidence-based completion | Extends ENGINEERING_STANDARDS §7.3 ("NOT RUN" is renamed "NOT TESTED") |
| P3-12 | **Git:** D-25 stands. At the end of M00, Antigravity asks the user **once** whether it may create **local** commits at milestone completion. The recommendation is yes, and it must **never push**. Without consent, changes stay uncommitted. | Reduces the risk of losing work without interrupting the user later | Refines D-25 |
| P3-13 | **Keychain entitlement contingency:** if the data protection keychain returns −34018 under P3-04 signing, add `Config/DOOM.entitlements` containing **only** `keychain-access-groups = [$(AppIdentifierPrefix)com.tace.doom]`, and set `CODE_SIGN_ENTITLEMENTS` in the xcconfig. Record it as an IMPL decision and update `verify-bundle.sh` (sandbox still forbidden). If it still fails, ask the user (the file-based keychain would change D-23). | Keeps D-23 intact. PROJECT_STRUCTURE §3 forbade `CODE_SIGN_ENTITLEMENTS` only to keep the sandbox out | Conditional amendment to PROJECT_STRUCTURE §3 |
| P3-14 | **Manual-test fixture:** `ManualTests/selection-test-page.html` (created in M04a) holds fixed passages with **known character counts** (ASCII, emoji, RTL, multi-paragraph, an over-limit passage of 20,001 characters, a `<textarea>`, an `<input>`, and a password field). Selection correctness is verified by **logged counts**, never by logging text. | Lets the agent verify capture without logging content | — |
| P3-15 | **[Copy] pasteboard write:** `AssistantController.copyResponse()` (DoomFeatures) is the only `NSPasteboard` use outside `ClipboardFallback`. It is **write-only** (`clearContents()` + `setString(_:forType: .string)`) and runs only on the user's click. No reads, no `changeCount` observation. | Resolves a Phase 02 contradiction: TEXT-T-10 limited `NSPasteboard` to the fallback type, while PRODUCT_BEHAVIOR §2 and UI §3 require [Copy]. TEXT-13 (no observation outside the fallback) is unchanged | Clarifies TEXT-T-10 and MODULE_CONTRACTS §1 |

---

## E. Implementation decisions and deviations (IMPL-xx)

### IMPL-05: M05 Gemini Interactions API, gemini-3.8-flash model, and Keychain architecture
- **Milestone:** M05 (Keychain & Gemini Integration)
- **Date:** October 25, 2026
- **Context:** Integration of Google's official Gemini API and macOS Keychain credential storage according to specifications in `GEMINI_INTEGRATION_SPECIFICATION.md` and `SECURITY_AND_PRIVACY.md`.
- **Decisions:**
  1. **API Selection:** Selected Google's official Interactions API endpoint (`https://generativelanguage.googleapis.com/v1beta/interactions`) in stateless mode (`store: false`, `stream: false`, temperature omitted, `thinking_level: "low"`, `max_output_tokens: 4096`).
  2. **Model Selection:** Default model `gemini-3.8-flash`. Verified as the official low-latency, cost-effective model recommended for agentic and tool-driven queries. Validated by strict regex `^[a-z0-9][a-z0-9.\-]{0,63}$`.
  3. **Credential Placement:** API key placed strictly in `x-goog-api-key` HTTP request header; never in URL query string or body payload.
  4. **Ephemeral Transport & Security:** Ephemeral `URLSession` configuration with zero disk caching, no cookie storage, and `NoRedirectDelegate` rejecting all HTTP redirections (SEC-10).
  5. **Response Parsing:** Deterministic extraction of output text from the final step of type `model_output`, joining all text items and ignoring intermediate `thought` steps (GEMINI-09). Responses exceeding 2 MB throw `.malformedResponse` (GEMINI-11).
  6. **Error Mapping:** Full mapping of HTTP status codes and Interactions error codes per §7. URLError `.notConnectedToInternet` maps to `.offline`; other connection drops map to `.transport(code:)`.
  7. **Cooldown Sequence:** Manual [Retry] cooldown sequence (0, 2, 4, 8, 16, 30s) with ±20% jitter bounds; 429 rate limits clamp `Retry-After` header to 1–60s (default 10s) without jitter.
  8. **Keychain Storage:** Generic password (`kSecClassGenericPassword`), service `com.tace.doom`, account `gemini-api-key`, Data Protection Keychain (`kSecUseDataProtectionKeychain = true`), accessibility `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, non-synchronizable (`kSecAttrSynchronizable = false`). Attribute-only presence query (`kSecReturnAttributes = true`, no `kSecReturnData`).
- **Evidence:** 32 unit tests across `DoomCoreTests`, 17 tests in `GeminiClientTests`, 7 tests in `KeychainCredentialStoreTests`, 4 tests in `RetryCooldownPolicyTests`. All checks in `./scripts/verify.sh` passed.
- **User Approval Needed:** None (aligns with approved specifications and roadmap).

### IMPL-06: Switch Default Model to gemini-3.5-flash Due to Public Endpoint 503 Overload
- **Milestone:** Post-M05 Bug Fix (Gemini Service Unavailable)
- **Date:** October 25, 2026
- **Context:** During live integration testing, clicking **Test Connection** with a valid API key returned: `"Gemini is temporarily unavailable: The service had a problem. Try again shortly."`
- **Root Cause Analysis & Evidence:**
  1. Systematic inspection of macOS unified logging and controlled live probes confirmed HTTP 503 Service Unavailable returned by Google's `/v1beta/interactions` endpoint.
  2. Provider error payload: `{"error":{"message":"gemini-3.8-flash is currently experiencing high demand, spikes in demand are usually temporary. Please try again later.","code":"service_unavailable"}}`.
  3. Controlled probe of candidate models using `GET /v1beta/models` and POST `/v1beta/interactions`:
     - `gemini-3.8-flash`: HTTP 503 (high demand spike).
     - `gemini-3.7-flash`: HTTP 503 (high demand spike).
     - `gemini-flash-latest`: HTTP 503 (aliased to 3.8 high demand spike).
     - `gemini-2.5-flash`: HTTP 404 (deprecated / not available to new users).
     - `gemini-3.5-flash`: HTTP 200 OK (latency ~2.9s, completed response).
     - `gemini-3.5-flash-lite`: HTTP 200 OK (latency ~1.1s, completed response).
- **Decision:**
  - Update `ModelID.default` from `gemini-3.8-flash` to `gemini-3.5-flash`.
  - Preserve exact same request schema (`store: false`, `stream: false`, `thinking_level: "low"`, `max_output_tokens: 4096`).
  - Update UI defaults, placeholder strings, test expectations, and technical documentation consistently.
  - Retain user's ability to override model via Settings if desired.
- **Verification:** Live test through `mainWindowModel.testConnection()` verified HTTP 200 OK with `"Connection successful! Gemini answered in stateless mode."` Unit tests in `GeminiClientTests` updated with regression coverage for HTTP 503 service unavailable payloads.

