# DOOM — Initial Project Structure

| | |
|---|---|
| **Status** | Approved. Phase 01 design, amended by Phase 02 (§C of `TECHNICAL_DECISIONS.md`) and Phase 03 (§D). Not yet implemented |
| **Date** | 2026-10-24 |
| **Governing decisions** | D-01 (Xcode app + local package), D-02 as amended by **P3-01** (agent-authored project; GUI fallback), D-03/D-04 (modules), D-08/D-09 (settings, plist) |

This is the **complete** file list for the foundation. Do not add files that are not listed here, and do not create empty folders or placeholders for future features (Shortcuts, Selection, Intelligence, ResponsePanel, Services, Keychain, Permissions, Diagnostics).

No file in this document exists yet. Phase 01 produces only the documents in `docs/`.

---

## 1. Directory tree

```
DOOM/                                        ← repository root (location chosen by the user)
├── .gitignore
├── README.md
├── Config/
│   ├── DOOM.xcconfig                        ← all app-target build settings (source of truth)
│   └── Local.xcconfig.example               ← template for the git-ignored Local.xcconfig
├── DOOM.xcodeproj/                          ← authored by Antigravity (P3-01; GUI fallback: IMPLEMENTATION_ROADMAP App. A)
│   ├── project.pbxproj
│   ├── project.xcworkspace/contents.xcworkspacedata      (+ xcshareddata/ files if Xcode creates them)
│   └── xcshareddata/xcschemes/DOOM.xcscheme              ← shared scheme, committed
├── DOOM/                                    ← app target sources (Xcode synchronized folder)
│   ├── DOOMApp.swift
│   ├── AppDelegate.swift
│   └── Assets.xcassets/
│       ├── Contents.json
│       ├── AccentColor.colorset/Contents.json
│       └── AppIcon.appiconset/Contents.json             ← Xcode template set, left empty (icon deferred: DD-10)
├── DoomKit/                                 ← local Swift package
│   ├── Package.swift
│   ├── Sources/
│   │   ├── DoomCore/
│   │   │   ├── AppConfiguration.swift
│   │   │   ├── ConfigurationError.swift
│   │   │   ├── LaunchOptions.swift
│   │   │   ├── AppContext.swift
│   │   │   └── Logging.swift
│   │   └── DoomFeatures/
│   │       ├── DesignSystem/
│   │       │   └── DoomTheme.swift
│   │       └── Home/
│   │           ├── HomeView.swift
│   │           └── HomeViewModel.swift
│   └── Tests/
│       ├── DoomCoreTests/
│       │   ├── AppConfigurationTests.swift
│       │   ├── LaunchOptionsTests.swift
│       │   └── AppContextTests.swift
│       └── DoomFeaturesTests/
│           └── HomeViewModelTests.swift
├── scripts/
│   ├── build.sh
│   ├── verify-bundle.sh
│   ├── smoke-test.sh
│   ├── check-secrets.sh
│   ├── review-checks.sh                     ← added in Phase 03 (M01)
│   └── verify.sh
└── docs/
    ├── ARCHITECTURE.md
    ├── TECHNICAL_DECISIONS.md
    ├── PROJECT_STRUCTURE.md
    ├── ENGINEERING_STANDARDS.md
    ├── PHASE_01_SUMMARY.md
    └── …                                    ← Phase 02 and Phase 03 documents (full list: docs/HANDOFF_README.md)
```

**Generated and git-ignored (never committed):** `build/` (scripted DerivedData, built apps, verification logs), `DoomKit/.build/`, `DoomKit/.swiftpm/`, `xcuserdata/`, `*.xcuserstate`, `Config/Local.xcconfig`.

**If the GUI fallback (P3-01, Appendix A) is used, remove these Xcode template files after creating the project.** An agent-authored project never creates them:
- `ContentView.swift`, which is replaced by `HomeView`.
- The `DOOM.entitlements` sandbox file, together with its `CODE_SIGN_ENTITLEMENTS` and `ENABLE_APP_SANDBOX` settings (D-17).
- Any `Preview Content` folder.
- Any template unit-test or UI-test targets. Tests live in the package (D-14).

`DoomCore` is deliberately flat (five files). Introduce subfolders only once it exceeds roughly eight files.

---

## 2. File-by-file specification

Columns: **Responsibility** · **Why here** · **May depend on** · **Tested by**.

### 2.1 Repository root and configuration

| File | Responsibility | Why here | May depend on | Tested by |
|---|---|---|---|---|
| `.gitignore` | Excludes build artifacts, user state, local signing config and credential-type files (`ENGINEERING_STANDARDS.md` §6) | Repository-wide policy | — | `verify.sh` hygiene step (`git check-ignore`) |
| `README.md` | Purpose, a "not affiliated with Marvel/Disney/id Software/Bethesda" notice, requirements (macOS ≥ D-06, Apple Silicon, full Xcode 16+), quick start, current capabilities, deferred features, links to `docs/` | Entry point for humans | — | Review: the commands in it match the scripts |
| `Config/DOOM.xcconfig` | The single source of app-target build settings (§3) | Text-reviewable settings (D-08) | Ends with `#include? "Local.xcconfig"` | `xcodebuild -showBuildSettings` and `verify-bundle.sh` |
| `Config/Local.xcconfig.example` | Documents the overridable keys `DEVELOPMENT_TEAM` and `CODE_SIGN_IDENTITY`, with no real values | Lets the user enable a stable signing identity without committing personal data (D-19) | — | Review |

### 2.2 Xcode project and app target (`DOOM/`)

| File | Responsibility | Why here | May depend on | Tested by |
|---|---|---|---|---|
| `DOOM.xcodeproj/project.pbxproj` | Defines the `DOOM` app target, the synchronized `DOOM/` folder, the linked `DoomCore` and `DoomFeatures` package products, and `Config/DOOM.xcconfig` as the base configuration for Debug and Release. It contains **no target-level build-setting overrides.** | Required by D-01 | — | Review of the `buildSettings` blocks; `xcodebuild -showBuildSettings` |
| `DOOM.xcodeproj/xcshareddata/xcschemes/DOOM.xcscheme` | Shared scheme, so `xcodebuild -scheme DOOM` is reproducible on any machine | Shared schemes are what get committed | — | `scripts/build.sh` |
| `DOOM/DOOMApp.swift` | `@main struct DOOMApp: App`. It uses `@NSApplicationDelegateAdaptor(AppDelegate.self)` and declares one `Window("DOOM", id: "main")` scene showing `HomeView(viewModel: HomeViewModel(context: appDelegate.context))`, with `.windowResizability(.contentSize)`. | The entry point belongs in the executable | SwiftUI, DoomFeatures, DoomCore | Smoke test (window visible); manual run |
| `DOOM/AppDelegate.swift` | `@MainActor final class AppDelegate: NSObject, NSApplicationDelegate`. It is the **composition root**: `init()` builds `AppContext.make(infoDictionary: Bundle.main.infoDictionary ?? [:], arguments: ProcessInfo.processInfo.arguments)`. It also logs lifecycle events, logs any configuration issue (key name only), runs the smoke check when the flag is present, returns `true` from `applicationShouldTerminateAfterLastWindowClosed`, and logs in `applicationWillTerminate`. | The only place allowed to touch process globals (`ARCHITECTURE.md` §2.1) | AppKit, DoomCore, OSLog | Smoke test (launch → visible window → `DOOM_SMOKE_OK` → exit 0); manual ⌘Q check |
| `DOOM/Assets.xcassets/AccentColor.colorset` | System accent colour set to emerald `#2FA36B` (sRGB), so standard controls tint consistently | Asset catalogs belong to the app target | — | Visual check |
| `DOOM/Assets.xcassets/AppIcon.appiconset` | Left empty as generated by the Xcode template; the system default icon is shown | Removing it would require changing `ASSETCATALOG_COMPILER_APPICON_NAME`; the icon is deferred (DD-10) | — | — |

### 2.3 `DoomKit/Package.swift`

The required content (tools version 6.0, so Swift 6 language mode is the default):
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DoomKit",
    platforms: [.macOS("27.0")],            // = verified macOS major from M00 (P3-02); must equal MACOSX_DEPLOYMENT_TARGET
    products: [
        .library(name: "DoomCore", targets: ["DoomCore"]),
        .library(name: "DoomFeatures", targets: ["DoomFeatures"]),
    ],
    targets: [
        .target(name: "DoomCore"),
        .target(name: "DoomFeatures", dependencies: ["DoomCore"]),
        .testTarget(name: "DoomCoreTests", dependencies: ["DoomCore"]),
        .testTarget(name: "DoomFeaturesTests", dependencies: ["DoomFeatures", "DoomCore"]),
    ]
)
```
No dependencies, no resources, no `unsafeFlags`. Tested by `swift build` and `swift test --package-path DoomKit`.

### 2.4 `DoomCore` (imports `Foundation`, `OSLog` only)

| File | Responsibility and public surface | Why here | May depend on | Tested by |
|---|---|---|---|---|
| `AppConfiguration.swift` | `public struct AppConfiguration: Equatable, Sendable` with `displayName`, `bundleIdentifier`, `version`, `build`. It also provides `public static let fallback` (`"DOOM"`, `"local.doom.unbundled"`, `"0.0.0"`, `"0"`), a `public enum Key` holding the plist key constants, and `public static func load(from info: [String: Any]) throws(ConfigurationError) -> AppConfiguration`. The validation rules are in `ENGINEERING_STANDARDS.md` §3.3. | Configuration is domain logic with no UI | Foundation | `AppConfigurationTests` |
| `ConfigurationError.swift` | `public enum ConfigurationError: Error, Equatable, Sendable { case missingValue(key: String); case invalidValue(key: String, reason: Reason) }`, where `public enum Reason: String, Sendable { case notReverseDNS, notVersionFormat, notBuildFormat }` and `public var key: String`. It carries **no** user-facing text and **no** offending values. | A domain error, separate from its presentation (D-12) | — | `AppConfigurationTests` |
| `LaunchOptions.swift` | `public struct LaunchOptions: Equatable, Sendable` with `public static let smokeTestFlag = "--doom-smoke-test"`, `public let isSmokeTest: Bool` and `public init(arguments: [String])`. argv[0] is ignored, as are unknown arguments (for example Xcode's `-NSDocumentRevisionsDebugMode YES`). | Pure parsing logic | Foundation | `LaunchOptionsTests` |
| `AppContext.swift` | `public struct AppContext: Sendable` with `configuration`, `configurationIssue: ConfigurationError?` and `launchOptions`. It has a memberwise `public init` and `public static func make(infoDictionary: [String: Any], arguments: [String]) -> AppContext`, which is **pure** and applies the fallback when loading fails. It has **no** `live()`; reading process globals happens only in `AppDelegate`. | The dependency value features receive. It is named `AppContext` to avoid confusion with SwiftUI's `Environment`. | Foundation | `AppContextTests` |
| `Logging.swift` | `public enum LogCategory: String, Sendable { case lifecycle, configuration }` and `extension Logger { public init(category: LogCategory, configuration: AppConfiguration) }`, where the subsystem is the bundle identifier. Loggers are created on demand and not stored in `Sendable` structs. | One place for subsystem and category naming | OSLog | Not unit-tested (no logic worth testing); review checks the privacy rules |

### 2.5 `DoomFeatures` (imports `DoomCore`, `SwiftUI`; no `AppKit` in Phase 01)

| File | Responsibility and public surface | Why here | May depend on | Tested by |
|---|---|---|---|---|
| `DesignSystem/DoomTheme.swift` | `public enum DoomTheme` with **computed** `static var` tokens: `background` and `metal` (`LinearGradient`), `steel`, `accent`, `warning`, `textSecondary` (`Color`), a `Spacing` scale (4/8/12/16/24) and `cornerRadius` (10). It holds the values from D-22. There are no assets and no custom fonts. | Visual tokens are a presentation concern | SwiftUI | Not unit-tested (constants); visual review |
| `Home/HomeViewModel.swift` | `public struct HomeViewModel: Equatable, Sendable` with `title`, `versionText` (`"Version \(version) (\(build))"`), `status: Status` (`.ready` / `.degraded`), `statusText` (`"Core systems online"`, or the degraded message `"DOOM is running with default settings because its app information is incomplete."`) and `phaseNote` (`"Foundation build. Assistant features arrive in later phases."`). Its initializer is `public init(context: AppContext)`. This is where domain errors are mapped to user text. | Presentation state and logic, without view code (MVVM) | DoomCore | `HomeViewModelTests` |
| `Home/HomeView.swift` | `public struct HomeView: View` with `public init(viewModel: HomeViewModel)`. It contains layout only: background gradient, a thin steel inset border, the heavy tracked silver wordmark, the version in monospaced caption style, an emerald hairline, and a status row (dot plus text, combined into one accessibility element labelled `"Status: …"`), followed by the phase note. It is 520 × 320 pt and `.preferredColorScheme(.dark)`. It includes a `#Preview` that uses `AppContext.make` with a valid dictionary. | A view in its feature folder | SwiftUI, DoomCore (types only) | Visual and manual review. **No** snapshot or layout unit tests. |

### 2.6 Tests (Swift Testing: `import Testing`, `@Test`, `#expect`, `#require`)

| File | Owns (test cases) |
|---|---|
| `DoomCoreTests/AppConfigurationTests.swift` | (1) A valid dictionary loads all four fields exactly. (2) `CFBundleName` is used when `CFBundleDisplayName` is absent. (3) Whitespace is trimmed. (4) Parameterised: each required key missing gives `.missingValue(key:)`; both name keys missing gives `.missingValue("CFBundleDisplayName")`. (5) A non-`String` value counts as missing. (6) Parameterised invalid bundle IDs (`"doom"`, `"com..doom"`, `"com.doom."`, `"com.do om"`) give `.invalidValue(key:, .notReverseDNS)`. (7) Parameterised invalid versions (`"1.2.3.4"`, `"v1"`, `"1.x"`) and valid ones (`"1"`, `"0.1"`, `"10.20.30"`); empty after trimming gives `.missingValue`. (8) Build-number rules are the same as for versions. |
| `DoomCoreTests/LaunchOptionsTests.swift` | (1) argv[0] only gives `false`. (2) The flag present gives `true`. (3) The flag only as argv[0] gives `false`. (4) Unknown arguments are ignored. |
| `DoomCoreTests/AppContextTests.swift` | (1) A valid dictionary plus the flag gives the loaded configuration, `configurationIssue == nil` and `isSmokeTest`. (2) An empty dictionary gives `configuration == .fallback` and the expected `configurationIssue`, with no crash. (3) `make` is deterministic: the same input gives equal output. |
| `DoomFeaturesTests/HomeViewModelTests.swift` | (1) A valid context gives title `DOOM`, `"Version 0.1.0 (1)"`, `.ready` and `"Core systems online"`. (2) A degraded context gives `.degraded` and the degraded message. (3) The degraded message contains no plist key names (`"CFBundle"`) and no raw values. |

Roughly 25–30 cases, counting parameterised arguments. No test may touch `Bundle.main`, `ProcessInfo`, the file system, the network, the clock or random numbers.

### 2.7 Scripts (`bash`, `set -euo pipefail`, macOS-only, relative paths only)

| File | Responsibility |
|---|---|
| `scripts/build.sh [debug\|release] [extra xcodebuild args…]` | Runs `xcodebuild -project DOOM.xcodeproj -scheme DOOM -configuration <Debug\|Release> -derivedDataPath build/DerivedData build`. The product is `build/DerivedData/Build/Products/<Config>/DOOM.app`. |
| `scripts/verify-bundle.sh [debug\|release]` | Checks the built app (D-16): identifier equals the xcconfig value; display name and executable are `DOOM`; `LSMinimumSystemVersion` equals the deployment target; version formats are valid; **no `*UsageDescription` keys**; `lipo -archs` is `arm64`; `codesign --verify --strict` passes; hardened-runtime flag is present; **no app-sandbox entitlement**. |
| `scripts/smoke-test.sh [debug\|release]` | Launches `…/DOOM.app/Contents/MacOS/DOOM --doom-smoke-test` with a timeout (default 15 s). It requires exit status 0 and a line exactly matching `DOOM_SMOKE_OK`, and needs a GUI login session. |
| `scripts/review-checks.sh` | *(Added in Phase 03, M01.)* Runs the milestone-aware review greps from `TESTING_STRATEGY.md` §6 and exits non-zero on any violation. It prints file and line numbers, never file contents beyond the matched line. |
| `scripts/check-secrets.sh` | Scans tracked and untracked-but-not-ignored files for Google API-key patterns (`AIza[0-9A-Za-z_-]{35}`) and PEM private keys, and for credential-type files that would be committed (`.env*`, `*.p12`, `*.pem`, `*.key`, `*.mobileprovision`, `*.provisionprofile`, `Local.xcconfig`). |
| `scripts/verify.sh` | The full sequence, logged with `tee` to `build/verification.log`. Steps: environment report (fails if `xcode-select -p` points at Command Line Tools); secret scan; `swift test --package-path DoomKit -Xswiftc -warnings-as-errors`; Debug and Release builds with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`; `verify-bundle.sh` and `smoke-test.sh` for both; hygiene checks. The last line on success is `ALL CHECKS PASSED` (Phase 03: renamed from `ALL PHASE 01 CHECKS PASSED`, because the script grows with each milestone; from M01 it also runs `scripts/review-checks.sh`). |

---

## 3. Required `Config/DOOM.xcconfig` keys

| Key | Value | Notes |
|---|---|---|
| `PRODUCT_NAME` | `DOOM` | Executable and bundle name |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.tace.doom` | **Fixed, P3-03** (resolves D-10). Changing it orphans the Keychain item, TCC grants and preferences |
| `MARKETING_VERSION` | `0.1.0` | D-09 |
| `CURRENT_PROJECT_VERSION` | `1` | D-09 |
| `MACOSX_DEPLOYMENT_TARGET` | the verified macOS major version from M00, expected `27.0` | **P3-02** (resolves D-06). No higher than `xcrun --show-sdk-version`; must equal `Package.swift` |
| `ARCHS` | `arm64` | D-07 |
| `SWIFT_VERSION` | `6.0` | D-05 |
| `SWIFT_STRICT_CONCURRENCY` | `complete` | D-05 |
| `GENERATE_INFOPLIST_FILE` | `YES` | D-09 |
| `INFOPLIST_KEY_CFBundleDisplayName` | `DOOM` | |
| `INFOPLIST_KEY_LSApplicationCategoryType` | `public.app-category.productivity` | |
| `ENABLE_HARDENED_RUNTIME` | `YES` | D-18 |
| `ENABLE_APP_SANDBOX` | `NO` | D-17; there is also no sandbox entitlement |
| `CODE_SIGN_STYLE` | `Automatic` | |
| `CODE_SIGN_IDENTITY` | `-` | Fallback for a checkout without `Local.xcconfig`. On the user's Mac, `Local.xcconfig` sets `DEVELOPMENT_TEAM` and `CODE_SIGN_IDENTITY = Apple Development` (**P3-04**) |
| `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` | `AccentColor` | |
| `ENABLE_USER_SCRIPT_SANDBOXING` | `YES` | Xcode default; there are no build-phase scripts anyway |
| `LD_RUNPATH_SEARCH_PATHS` | `$(inherited) @executable_path/../Frameworks` | Xcode's template normally sets this at target level; it moves here |
| `SWIFT_EMIT_LOC_STRINGS` | `YES` | Template default, moved here (prepares for localisation) |
| *(last line)* | `#include? "Local.xcconfig"` | Optional include; the file is git-ignored |

**Template settings rule.** When the project is created, every target-level build setting that Xcode's template generates must be either **moved into this file**, if it is still meaningful, or **deleted**. The exact list depends on the Xcode version actually installed, so the handoff checklist will list it for that version. Project-level template defaults (for example `SDKROOT = macosx`) may stay in `pbxproj` because the target's xcconfig takes precedence over them. The only exception would be a project-level setting that contradicts this table; delete any such setting.

Must **not** appear anywhere (xcconfig or `pbxproj`):
- `DEVELOPMENT_TEAM` (only in `Local.xcconfig`)
- `SWIFT_DEFAULT_ACTOR_ISOLATION`, `SWIFT_APPROACHABLE_CONCURRENCY` (D-05)
- `SWIFT_TREAT_WARNINGS_AS_ERRORS` (D-26)
- `CODE_SIGN_ENTITLEMENTS`. **Exception:** P3-13 contingency only (a keychain-access-groups-only entitlements file, recorded as an IMPL decision)
- any `INFOPLIST_KEY_*UsageDescription`
- any `INFOPLIST_KEY_LSUIElement` **until M02**, when P2-01 requires `INFOPLIST_KEY_LSUIElement = YES` in the xcconfig (never in `pbxproj`)

**Phase 03 note.** This file describes the **foundation** (milestone M01). Later milestones add the files listed in `MODULE_CONTRACTS.md` §7, which is the approved extension of this list. Paths are relative to the repository root (`DoomKit/...`, not `Packages/DoomKit/...`).

---

## 4. Module ownership and dependency restrictions (summary)

| Module | Owner of | Allowed imports | Forbidden |
|---|---|---|---|
| App target `DOOM` | Lifecycle, composition root, bundle identity, assets | Anything needed (AppKit, SwiftUI, OSLog, DoomCore, DoomFeatures) | Business logic; being imported by anything else |
| `DoomCore` | Configuration, errors, launch options, `AppContext`, logging categories | Foundation, OSLog | SwiftUI, AppKit, Cocoa, DoomFeatures, process globals other than via parameters |
| `DoomFeatures` | Views, view models, presentation mapping, design system | DoomCore, SwiftUI (AppKit only when documented) | `Bundle.main`, `ProcessInfo`, `UserDefaults.standard`, networking, privileged system APIs |
| `DoomCoreTests` | Core unit tests | Testing, Foundation, DoomCore | I/O, clock, network, process globals |
| `DoomFeaturesTests` | View-model tests | Testing, DoomCore, DoomFeatures | SwiftUI rendering, I/O |

## 5. Testing ownership (summary)

| What | Verified by |
|---|---|
| Configuration validation, fallback, error mapping, launch options | Package unit tests (`swift test`) |
| Bundle metadata, architecture, signing, hardened runtime, no sandbox, no usage descriptions | `scripts/verify-bundle.sh` on the built app |
| Launch → visible window → clean termination | `scripts/smoke-test.sh` plus a manual ⌘Q and window-close check |
| Repository hygiene and secrets | `scripts/check-secrets.sh`; `verify.sh` hygiene step |
| Layering rules, no future-phase code | Review greps (`ENGINEERING_STANDARDS.md` §8) |
| Visual quality | Manual review of the running app (no snapshot tests in Phase 01) |
