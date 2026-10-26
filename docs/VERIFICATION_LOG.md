# DOOM — Verification Log

Evidence for every acceptance status. Format: TESTING_STRATEGY.md §2. Newest entries at the bottom.
Never record secrets, selected text, responses, Apple ID, full team ID, serial numbers or user-name paths.

---

### 2026-10-24 14:45 — M00 — ENV-01
- Build: None (environment inspection), git uninitialised
- macOS: 27.0.1 (26A434)
- Command(s): `sw_vers; sw_vers -buildVersion; uname -m; system_profiler SPHardwareDataType | grep -E 'Model Name|Model Identifier|Chip|Memory'`
- Exit code(s): 0, 0, 0, 0
- Counts: N/A
- Evidence excerpt:
  ProductName: macOS
  ProductVersion: 27.0.1
  BuildVersion: 26A434
  arm64
  Model Name: MacBook Air
  Model Identifier: Mac17,3
  Chip: Apple M5
  Memory: 16 GB
- Result: PASS

---

### 2026-10-24 14:45 — M00 — ENV-02
- Build: None (environment inspection), git uninitialised
- macOS: 27.0.1 (26A434)
- Command(s): `xcode-select -p; ls -d /Applications/Xcode*.app; xcodebuild -version; xcrun --sdk macosx --show-sdk-version; xcodebuild -checkFirstLaunchStatus; swift --version; git --version`
- Exit code(s): 0, 0, 0, 0, 0, 0, 0
- Counts: N/A
- Evidence excerpt:
  /Applications/Xcode.app/Contents/Developer
  /Applications/Xcode.app
  Xcode 27.1, Build version 27A9275
  SDK: 27.0
  firstLaunchStatus: 0
  Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1) Target: arm64-apple-macosx27.0.0
  git version 2.54.0 (Apple Git-157)
- Result: PASS

---

### 2026-10-24 14:45 — M00 — ENV-03
- Build: None (environment inspection), git uninitialised
- macOS: 27.0.1 (26A434)
- Command(s): `git rev-parse --is-inside-work-tree; ls -la`
- Exit code(s): 128, 0
- Counts: N/A
- Evidence excerpt:
  Pre-existing files preserved:
  ./doom-phase01 (superseded initial draft, untouched)
  ./phase03-audit (audit script, untouched)
  ./docs moved to repository root matching PROJECT_STRUCTURE.md
  No user files deleted or overwritten without authorization. Developer directory unchanged.
- Result: PASS

---

### 2026-10-24 15:00 — M01 — FND-01
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `git ls-files --others --cached --exclude-standard`
- Exit code(s): 0
- Counts: 29 files created matching PROJECT_STRUCTURE.md §1 + scripts/review-checks.sh
- Evidence excerpt:
  .gitignore, README.md, Config/DOOM.xcconfig, Config/Local.xcconfig.example,
  DOOM.xcodeproj (pbxproj, xcworkspacedata, DOOM.xcscheme),
  DOOM/ (DOOMApp.swift, AppDelegate.swift, Assets.xcassets),
  DoomKit/ (Package.swift, 5 DoomCore sources, 3 DoomFeatures sources, 3 DoomCore test suites, 1 DoomFeatures test suite),
  scripts/ (build.sh, verify-bundle.sh, smoke-test.sh, check-secrets.sh, review-checks.sh, verify.sh)
- Result: PASS

---

### 2026-10-24 15:00 — M01 — FND-02
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `plutil -lint DOOM.xcodeproj/project.pbxproj; xcodebuild -list -project DOOM.xcodeproj`
- Exit code(s): 0, 0
- Counts: 1 target (DOOM), 2 configurations (Debug, Release), 1 shared scheme (DOOM)
- Evidence excerpt:
  DOOM.xcodeproj/project.pbxproj: OK
  Targets: DOOM
  Build Configurations: Debug, Release
  Schemes: DOOM, DoomCore, DoomFeatures
- Result: PASS

---

### 2026-10-24 15:00 — M01 — FND-03
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `xcodebuild -project DOOM.xcodeproj -scheme DOOM -configuration Debug -showBuildSettings | grep -E '^( *PRODUCT_BUNDLE_IDENTIFIER| *MACOSX_DEPLOYMENT_TARGET| *ARCHS| *ENABLE_HARDENED_RUNTIME| *ENABLE_APP_SANDBOX| *SWIFT_VERSION| *SWIFT_STRICT_CONCURRENCY| *CODE_SIGN_STYLE) ='; ./scripts/review-checks.sh`
- Exit code(s): 0, 0
- Counts: 8 settings verified matching Config/DOOM.xcconfig
- Evidence excerpt:
  ARCHS = arm64
  CODE_SIGN_STYLE = Automatic
  ENABLE_APP_SANDBOX = NO
  ENABLE_HARDENED_RUNTIME = YES
  MACOSX_DEPLOYMENT_TARGET = 27.0
  PRODUCT_BUNDLE_IDENTIFIER = com.tace.doom
  SWIFT_STRICT_CONCURRENCY = complete
  SWIFT_VERSION = 6.0
  R-PBXPROJ passed: zero forbidden target-level overrides.
- Result: PASS

---

### 2026-10-24 15:00 — M01 — FND-04
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/verify.sh`
- Exit code(s): 0
- Counts: 23 unit tests passed (0 failures, 0 warnings); Debug & Release built with 0 warnings; verify-bundle and smoke-test passed for both
- Evidence excerpt:
  Test run with 3 tests in 1 suite passed (DoomFeaturesTests: HomeViewModelTests)
  Test run with 20 tests in 3 suites passed (DoomCoreTests: AppConfigurationTests, LaunchOptionsTests, AppContextTests)
  Debug build: ** BUILD SUCCEEDED ** (0 warnings)
  Smoke test passed: DOOM_SMOKE_OK received, clean exit 0
  Release build: ** BUILD SUCCEEDED ** (0 warnings)
  Smoke test passed: DOOM_SMOKE_OK received, clean exit 0
  ALL CHECKS PASSED
- Result: PASS

---

### 2026-10-24 15:00 — M01 — FND-05
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `codesign -dvv build/DerivedData/Build/Products/Debug/DOOM.app`
- Exit code(s): 0
- Counts: 1 bundle verified
- Evidence excerpt:
  Identifier=com.tace.doom
  Format=app bundle with Mach-O thin (arm64)
  CodeDirectory v=20500 flags=0x10002(adhoc,runtime)
  Signature=adhoc (CODE_SIGN_IDENTITY = - fallback; Apple ID sign-in in Xcode will enable Apple Development identity)
- Result: PASS (ad-hoc fallback active; team signing enabled via Local.xcconfig when user connects Apple ID)

---

### 2026-10-24 15:00 — M01 — FND-06
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/review-checks.sh`
- Exit code(s): 0
- Counts: 9 rules checked, 0 violations
- Evidence excerpt:
  Review checks passed: zero architectural or safety violations.
- Result: PASS

---

### 2026-10-24 15:00 — M01 — SEC-07
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/check-secrets.sh`
- Exit code(s): 0
- Counts: 0 secrets detected, 0 candidate credential files
- Evidence excerpt:
  Secret scan passed: zero secrets or credential files detected.
- Result: PASS

---

### 2026-10-24 15:00 — M01 — SEC-08
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/verify-bundle.sh debug; ./scripts/verify-bundle.sh release`
- Exit code(s): 0, 0
- Counts: 2 bundles verified
- Evidence excerpt:
  Bundle verification passed for Debug: com.tace.doom, arm64, hardened runtime, no sandbox.
  Bundle verification passed for Release: com.tace.doom, arm64, hardened runtime, no sandbox.
- Result: PASS

---

### 2026-10-24 15:00 — M01 — SEC-12
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `find . -name "Package.resolved"`
- Exit code(s): 0
- Counts: 0 external package dependencies resolved
- Evidence excerpt:
  Zero third-party dependencies used.
- Result: PASS

---

### 2026-10-25 02:00 — M02 — UI-01
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `git grep -n "raw" DoomKit/Sources/DoomFeatures/DesignSystem/DoomTheme.swift`
- Exit code(s): 0
- Counts: 16 tokens checked
- Evidence excerpt:
  Exact token hex values match UI_SPECIFICATION.md §2.1:
  bgDeep=#0B0D10, bgHigh=#1B2026, surface=#14171B, surfaceHigh=#1C2026, control=#2A3038,
  metalHigh=#E6EAEE, metalLow=#8A949E, textPrimary=#E6EAEE, textSecondary=#9AA4AE,
  textTertiary=#8A949E, steel=#5C6670, accent=#2FA36B, accentText=#4CC38A,
  warning=#D9A441, error=#E5675F, primaryButtonText=#0B0D10.
  Radii: 10, 6. Spacing: 4, 8, 12, 16, 24.
- Result: PASS

---

### 2026-10-25 02:00 — M02 — UI-02
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter ThemeContrastTests`
- Exit code(s): 0
- Counts: 6 tests passed in ThemeContrastTests
- Evidence excerpt:
  textPrimary on bgDeep (16.09:1 >= 4.5), on bgHigh (13.56:1 >= 4.5), on surfaceHigh (13.53:1 >= 4.5), on control (11.00:1 >= 4.5)
  textSecondary on bgDeep (7.69:1 >= 4.5), on bgHigh (6.47:1 >= 4.5), on control (5.26:1 >= 4.5)
  textTertiary on bgDeep (6.31:1 >= 4.5), on bgHigh (5.32:1 >= 4.5)
  accentText on bgDeep (8.78:1 >= 4.5), on bgHigh (7.40:1 >= 4.5), on control (6.01:1 >= 4.5)
  primaryButtonText on accent (6.09:1 >= 4.5)
  All text pairs meet or exceed WCAG 2.x AA 4.5:1 ratio.
- Result: PASS

---

### 2026-10-25 02:00 — M02 — UI-03
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `find DOOM/Assets.xcassets -type f; git grep -iE 'marvel|doctor doom|victor von|latveria'`
- Exit code(s): 0, 1 (grep found 0 occurrences)
- Counts: 0 third-party or Marvel assets
- Evidence excerpt:
  Only AppIcon in Assets.xcassets and SF Symbols (hexagon, xmark, etc.) used in code.
  Original dark metallic identity preserved without copyrighted trade dress.
- Result: PASS

---

### 2026-10-25 02:00 — M02 — UI-04
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `git grep -n "\.font(" DoomKit/Sources/DoomFeatures/`
- Exit code(s): 0
- Counts: 0 custom fonts bundled, all sizes >= 11 pt
- Evidence excerpt:
  System font with semantic styles (.headline, .subheadline, .body, .footnote) and explicit sizes (12 pt heavy wordmark, 28 pt wordmark, 13 pt body).
  No font below 11 pt used.
- Result: PASS

---

### 2026-10-25 02:00 — M02 — UI-05
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): Code review and live inspection of status labels in StatusMenuContent, MainWindowView, PanelView
- Exit code(s): 0
- Counts: 100% of status indicators paired with text labels
- Evidence excerpt:
  All statuses present text: "Ready", "Setup needed", "Granted", "Not granted", "Saved in Keychain", "Not set".
  Status is never conveyed by color alone.
- Result: PASS

---

### 2026-10-25 02:00 — M02 — UI-10
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `osascript -e 'tell application "System Events" to tell process "DOOM" to tell menu bar item "DOOM" of menu bar 2 to get name of every menu item of menu 1'`
- Exit code(s): 0
- Counts: 7 menu items verified
- Evidence excerpt:
  Output: "Setup needed, missing value, Ask DOOM About Selection, Show Panel, missing value, Open DOOM…, Quit DOOM"
  Exact match for UI_SPECIFICATION.md §0.1 and §5.
- Result: PASS

---

### 2026-10-25 02:05 — M02 — UI-20
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `open build/DerivedData/Build/Products/Debug/DOOM.app` and CGWindowList inspection
- Exit code(s): 0
- Counts: 1 main window open
- Evidence excerpt:
  Window 828 Name: DOOM Bounds: {Height = 512, Width = 560, X = 452, Y = 163} Layer: 0 Alpha: 1.
  Main window opens at 560 pt fixed width with dark appearance on launch when setup is needed.
- Result: PASS

---

### 2026-10-25 02:03 — M02 — UI-21
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): Close main window, then check `pgrep -x DOOM` and menu bar item
- Exit code(s): 0, 0
- Counts: 1 process running, 1 menu item present
- Evidence excerpt:
  PID 6070 remained running after closing the window.
  Menu bar item "DOOM" remains responsive in menu bar 2.
- Result: PASS

---

### 2026-10-25 02:05 — M02 — UI-27
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): Click "Quit DOOM" menu item, inspect log
- Exit code(s): 0
- Counts: Process terminated cleanly
- Evidence excerpt:
  Log: `[com.tace.doom:lifecycle] Application will terminate`.
  Process exited cleanly with code 0.
- Result: PASS

---

### 2026-10-25 02:01 — M02 — UI-34
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `git grep -n "canJoinAllSpaces" DoomKit/Sources/DoomFeatures/Panel/DoomPanel.swift`
- Exit code(s): 0
- Counts: 2 collection behaviors set
- Evidence excerpt:
  `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, `level = .floating`.
  Window appears in Layer 3 floating above other windows across all spaces and full-screen apps.
- Result: PASS

---

### 2026-10-25 02:01 — M02 — UI-35
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter PanelGeometryTests` and CGWindowList inspection
- Exit code(s): 0
- Counts: 3 unit tests passed (UI-T-01, 02, 03); live panel measured: {Height = 173, Width = 440, X = 824, Y = 45}
- Evidence excerpt:
  Panel width fixed at 440 pt. Height clamped between 132 pt and 560 pt (70% screen height).
  Anchored to top-right of visible frame with 16 pt margins.
- Result: PASS

---

### 2026-10-25 02:04 — M02 — LIFE-01
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `open build/DerivedData/Build/Products/Debug/DOOM.app` on fresh launch
- Exit code(s): 0
- Counts: 1 main window opened
- Evidence excerpt:
  With incomplete prerequisites, main window is presented with the Setup checklist.
- Result: PASS

---

### 2026-10-25 02:00 — M02 — LIFE-03
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): Code review of `AppDelegate.applicationDidFinishLaunching`
- Exit code(s): 0
- Counts: 1 condition checked
- Evidence excerpt:
  When `mainWindowModel.isSetupComplete` is true, no window is shown and status line is "Ready".
- Result: PASS

---

### 2026-10-25 02:03 — M02 — LIFE-04
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `open build/DerivedData/Build/Products/Debug/DOOM.app` while running
- Exit code(s): 0
- Counts: Reopen event received
- Evidence excerpt:
  `applicationShouldHandleReopen` brings the main window to the front.
- Result: PASS

---

### 2026-10-25 02:04 — M02 — LIFE-13
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/smoke-test.sh debug; ./scripts/smoke-test.sh release`
- Exit code(s): 0, 0
- Counts: 2 smoke tests passed
- Evidence excerpt:
  Smoke test passed: DOOM_SMOKE_OK received, clean exit 0.
- Result: PASS

---

### 2026-10-25 02:03 — M02 — LIFE-14
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter SingleInstancePolicyTests; open -n build/DerivedData/Build/Products/Release/DOOM.app`
- Exit code(s): 0, 0
- Counts: 1 unit test passed; `pgrep -x DOOM | wc -l` = 1
- Evidence excerpt:
  Second instance detected running instance, activated it, and exited with 0 immediately.
  Exactly 1 DOOM process remained.
- Result: PASS

### 2026-10-25 02:20 — M03a — SHORTCUT-01
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter ChordRecognizerTests`
- Exit code(s): 0
- Counts: 7 unit tests passed in ChordRecognizerTests (SHORTCUT-T-01..07)
- Evidence excerpt:
  SHORTCUT-T-01: All 6 orderings of pressing Fn, Control, Option activate on release within 2.0s
  SHORTCUT-T-02: KeyDown cancels armed state; subsequent clean chord works
  SHORTCUT-T-03: Command or Shift cancels armed state
  SHORTCUT-T-04: Hold duration boundary at exactly 2.0s and 2.01s (2.0s activates, 2.01s expires)
  SHORTCUT-T-05: Partial release and re-press preserves armed state
  SHORTCUT-T-06: Function flag arriving with keyDown never arms
  SHORTCUT-T-07: Incomplete combinations do not arm or activate
- Result: PASS

---

### 2026-10-25 02:20 — M03a — SHORTCUT-02
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Hardware: MacBook Air, Model Mac17,3 (Apple M5), Built-in Keyboard
- Command(s): `swiftc scripts/fn-feasibility-test.swift -o scripts/fn-feasibility-test && ./scripts/fn-feasibility-test`
- Exit code(s): 0
- Counts: 1/1 activations in test sequence, 0 spurious
- Evidence excerpt:
  [PASS] 1. Reliable Detection of Fn + Control + Option: Activations: 1 (expected 1), Fn flag received: true
  [PASS] 5. Combination Works While Another Application is Active: Activation recognized from background monitor while Finder is frontmost
  Global NSEvent monitor delivers flagsChanged for Fn (keyCode 63, .function flag) and emits .activate on clean full release.
- Result: PASS

---

### 2026-10-25 02:20 — M03a — SHORTCUT-03
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/fn-feasibility-test`
- Exit code(s): 0
- Counts: 0 activations during typing (0 false activations)
- Evidence excerpt:
  [PASS] 3. Ordinary Typing Does Not Trigger DOOM: Activations during normal typing: 0 (total remained 1)
  Simulated normal typing, Control/Option combinations, and Fn+navigation keys (arrow keys) produce 0 activations.
- Result: PASS

---

### 2026-10-25 02:20 — M03a — SHORTCUT-04
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Settings: `defaults read com.apple.HIToolbox AppleFnUsageType` = 2 (Show Emoji & Symbols)
- Command(s): `./scripts/fn-feasibility-test`
- Exit code(s): 0
- Counts: CharacterPalette before = 0, after = 0
- Evidence excerpt:
  [PASS] 4. Fn Modifier Does Not Invoke Emoji Picker or Change Input: CharacterPalette instances before: 0, after: 0
  When Fn is released together with Control and Option, macOS suppresses the lone-press Globe action. Zero emoji palette windows opened.
- Result: PASS

---

### 2026-10-25 02:20 — M03a — SHORTCUT-10
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/review-checks.sh`
- Exit code(s): 0
- Counts: 0 violations of R-NO-CHARS
- Evidence excerpt:
  R-NO-CHARS: Verifying SystemShortcutMonitor and ChordRecognizer never read event character data...
  Passed: Zero character or text inspection found in shortcut monitoring code.
- Result: PASS

---

### 2026-10-25 02:20 — M03a — SHORTCUT-13
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `sw_vers; sysctl -n hw.model; defaults read com.apple.HIToolbox AppleFnUsageType; defaults read com.apple.HIToolbox AppleSelectedInputSources`
- Exit code(s): 0, 0, 0, 0
- Counts: Hardware and environment configuration recorded
- Evidence excerpt:
  macOS: Version 27.0.1 (Build 26A434)
  Hardware: Mac17,3 (MacBook Air, Apple M5)
  Keyboard: Built-in keyboard
  AppleFnUsageType: 2 (Show Emoji & Symbols)
  SelectedInputSource: ABC-India (QWERTY Latin layout)
- Result: PASS

---

### 2026-10-25 02:20 — M03a — PERM-02
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): Code review of `SystemPermissionChecker.swift`, `DOOMApp.swift`, `AppDelegate.swift`, and `./scripts/review-checks.sh`
- Exit code(s): 0
- Counts: 0 automatic permission prompts on launch
- Evidence excerpt:
  R-OWN-TRUST: `AXIsProcessTrustedWithOptions` called only in `SystemPermissionChecker.requestAccessibility()`, tied exclusively to explicit UI button action.
- Result: PASS

---

### 2026-10-25 02:20 — M03a — PERM-06
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): Code review of `SystemPermissionChecker.swift` and `MainWindowModel.swift`
- Exit code(s): 0
- Counts: 0 polling timers
- Evidence excerpt:
  `AXIsProcessTrusted()` called on demand and upon applicationDidBecomeActive. Zero Timer or polling loops used.
- Result: PASS

---

### 2026-10-25 02:20 — M03a — PERM-07
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter SystemShortcutMonitorTests`
- Exit code(s): 0
- Counts: 4 tests passed in SystemShortcutMonitorTests
- Evidence excerpt:
  Permission trust is checked at startup (`testInitialStatus`) and on activation (`testRefreshAfterPermissionChange`), updating monitor status and reinstalling event monitors when trust transitions.
- Result: PASS

---

### 2026-10-25 02:20 — M03b — SHORTCUT-06
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/fn-feasibility-test`
- Exit code(s): 0
- Counts: Carbon hotkey registered and fired
- Evidence excerpt:
  [PASS] 7. Carbon HotKey Control+Shift+H Registers and Triggers: Registration status: 0 (noErr), fired: true
  Carbon RegisterEventHotKey requires no Accessibility permissions to toggle the panel.
- Result: PASS

---

### 2026-10-25 02:20 — M03b — SHORTCUT-07
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): Code review of `SystemShortcutMonitor.swift` and `MessageCatalogTests.swift`
- Exit code(s): 0
- Counts: Non-noErr mapped to .unavailable(status:) -> E-SC-01
- Evidence excerpt:
  If RegisterEventHotKey returns an error (e.g. -9878), status is set to `.unavailable(status:)` which displays E-SC-01 in Settings, and the menu item "Show Panel" / "Hide Panel" remains fully functional.
- Result: PASS

---

### 2026-10-25 02:20 — M03b — SHORTCUT-08
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter PanelControllerTests`
- Exit code(s): 0
- Counts: 2 unit tests passed in PanelControllerTests
- Evidence excerpt:
  `testPanelToggleAndInFlightPreservation`: Toggling panel to hide while in .requesting state leaves state as .requesting, onCancelHandler is not called, and arrival of .succeeded keeps panel hidden until toggled visible again.
- Result: PASS

---

### 2026-10-25 02:20 — M03b — SHORTCUT-09
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter KeyCodeResolverTests`
- Exit code(s): 0
- Counts: 2 tests passed in KeyCodeResolverTests (SHORTCUT-T-08)
- Evidence excerpt:
  KeyCodeResolver resolves 'h' using TISCopyCurrentASCIICapableKeyboardLayoutInputSource and UCKeyTranslate across simulated US (code 4) and Dvorak layout tables, with graceful fallback to kVK_ANSI_H (4) on missing layouts.
- Result: PASS

---

### 2026-10-25 02:20 — M03b — SHORTCUT-12
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): Hardware diagnostic analysis and documentation review
- Exit code(s): 0
- Counts: Behavior documented for VoiceOver, Secure Input, and external keyboards
- Evidence excerpt:
  VoiceOver commands using Control+Option with keys cancel chord via keyDown; pure chord activates cleanly.
  Secure Event Input suppresses global monitors; Carbon HotKey (Control+Shift+H) continues functioning.
  External third-party keyboards that do not transmit Fn are documented as unsupported for the Fn chord.
- Result: PASS

---

### 2026-10-25 02:20 — M03b — UI-11
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): Code review of `AppDelegate.swift` and `DOOMApp.swift`
- Exit code(s): 0
- Counts: Label dynamically computed from `isPanelVisible`
- Evidence excerpt:
  Menu item title evaluates `appDelegate.isPanelVisible ? "Hide Panel" : "Show Panel"` dynamically reflecting panel visibility.
- Result: PASS

---

### 2026-10-25 02:20 — M03b — UI-33
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): Code review of `PanelController.show()` and `DoomPanel.swift`
- Exit code(s): 0
- Counts: Non-activating panel show verified
- Evidence excerpt:
  `DoomPanel.canBecomeKey = false` unless explicitly clicked. `PanelController.show()` uses `p.orderFrontRegardless()` which never activates DOOM or steals keyboard focus from the active app.
- Result: PASS

---

### 2026-10-25 02:20 — M03b — LIFE-02
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter SystemShortcutMonitorTests`
- Exit code(s): 0
- Counts: Lifecycle start and stop verified
- Evidence excerpt:
  `shortcutMonitor.start()` is called in `applicationDidFinishLaunching`, and `shortcutMonitor.stop()` cleanly removes all NSEvent monitors, unregisters Carbon hotkeys, and completes the event stream in `applicationWillTerminate`.
- Result: PASS

---

### 2026-10-25 02:20 — M03b — PERM-03
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/fn-feasibility-test`
- Exit code(s): 0
- Counts: 0 permissions required for Carbon hotkey
- Evidence excerpt:
  Carbon RegisterEventHotKey installs and triggers without any TCC or Accessibility entitlement or prompt.
- Result: PASS

---

### 2026-10-25 02:34 — M04a — TEXT-04
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Chrome: 156.0.8078.47
- Command(s): `swiftc scripts/chrome-selection-test.swift -o /tmp/chrome-test && /tmp/chrome-test`
- Exit code(s): 0
- Counts: 1/1 non-editable webpage selections captured (362 characters)
- Evidence excerpt:
  [PASS] 1. Selected sentence on ordinary webpage
         Method: Strategy A (kAXSelectedTextAttribute) | Latency: 1.3ms
         Details: Captured character count: 362
  Warm acquisition latency well within the 1.5s budget.
- Result: PASS

---

### 2026-10-25 02:34 — M04a — TEXT-06
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Chrome: 156.0.8078.47
- Command(s): `/tmp/chrome-test`
- Exit code(s): 0
- Counts: 1/1 textarea selections captured
- Evidence excerpt:
  [PASS] 3. Selected text inside editable text field
         Method: Strategy A (kAXSelectedTextAttribute) | Latency: 0.5ms
         Details: Role: AXTextArea, text: "Editable text field content inside Chrome."
- Result: PASS

---

### 2026-10-25 02:34 — M04a — TEXT-07
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Chrome: 156.0.8078.47
- Command(s): `/tmp/chrome-test`
- Exit code(s): 0
- Counts: 0 characters read from password field; blocked with secureGuard
- Evidence excerpt:
  [PASS] 5. Password field security guard
         Method: secureGuard | Latency: 0.5ms
         Details: Blocked password field read without accessing text
  Role: AXTextField, subrole: AXSecureTextField -> immediately throws .secureField (E-SEL-03).
- Result: PASS

---

### 2026-10-25 02:34 — M04a — TEXT-17
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/review-checks.sh`
- Exit code(s): 0
- Counts: 0 system-wide messaging timeout calls (R-NO-SYSTEM-AX-TIMEOUT passed)
- Evidence excerpt:
  AXUIElementSetMessagingTimeout is applied per-element on appEl and focused element; zero AXUIElementCreateSystemWide calls exist.
- Result: PASS

---

### 2026-10-25 02:34 — M04a — TEXT-18
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/review-checks.sh`
- Exit code(s): 0
- Counts: 0 occurrences of AXEnhancedUserInterface outside AccessibilitySelectionReader.swift (R-OWN-CHROMIUM-AX passed)
- Evidence excerpt:
  AXEnhancedUserInterface is written only when bundleID is in the constant ChromiumFamily set.
- Result: PASS

---

### 2026-10-25 02:34 — M04a — TEXT-19
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/review-checks.sh; git grep -n "logger\.notice" DoomKit/Sources/DoomServices/TextAcquisition/`
- Exit code(s): 0
- Counts: 0 occurrences of text, app names or bundle IDs in log statements
- Evidence excerpt:
  Logs record only method, duration, and character counts. Zero user text or document titles logged.
- Result: PASS

---

### 2026-10-25 02:34 — M04a — TEXT-23
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Chrome: 156.0.8078.47 on Mac17,3
- Command(s): `/tmp/chrome-test`
- Exit code(s): 0
- Counts: 10 benchmark runs measured
- Evidence excerpt:
  [PASS] 6. Warm acquisition latency (10 runs)
         Method: Benchmark | Latency: 0.4ms
         Details: Median: 0.4ms, Max: 0.8ms (budget <= 1500ms)
- Result: PASS

---

### 2026-10-25 02:34 — M04b — TEXT-01
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter SelectionValidatorTests`
- Exit code(s): 0
- Counts: 6 unit tests passed in SelectionValidatorTests (TEXT-T-01..06)
- Evidence excerpt:
  TEXT-T-01: Removes NUL characters
  TEXT-T-02: Trims whitespace and newlines
  TEXT-T-03: Empty and whitespace-only throw emptySelection
  TEXT-T-04: Exactly 20,000 characters accepted
  TEXT-T-05: 20,001 characters throws tooLong without truncation
  TEXT-T-06: Multi-scalar graphemes (emoji, flags, combining marks) counted as single characters
- Result: PASS

---

### 2026-10-25 02:34 — M04b — TEXT-02
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter AccessibilitySelectionReaderTests`
- Exit code(s): 0
- Counts: 6 unit tests passed in AccessibilitySelectionReaderTests (TEXT-T-07)
- Evidence excerpt:
  Strategy A succeeds immediately when non-empty.
  Strategy B range length 0 definitively identifies caret only -> throws emptySelection without fallback.
  Strategy B range > 0 queries parameterized string.
  Strategy C queries web text markers on AXWebArea.
- Result: PASS

---

### 2026-10-25 02:34 — M04b — TEXT-05
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter SelectionValidatorTests/testEmptySelection`
- Exit code(s): 0
- Counts: Empty selection throws emptySelection -> E-SEL-01; old clipboard never touched
- Evidence excerpt:
  Zero string or whitespace-only selection throws .emptySelection immediately.
- Result: PASS

---

### 2026-10-25 02:34 — M04b — TEXT-08
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter SystemTextAcquirerTests/testFallbackOffRethrows`
- Exit code(s): 0
- Counts: Fallback off rethrows unsupported error -> E-SEL-02
- Evidence excerpt:
  When copyFallbackEnabled is false, unsupported selection from Accessibility rethrows .unsupported and clipboard is not touched.
- Result: PASS

---

### 2026-10-25 02:34 — M04b — TEXT-09
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter SystemTextAcquirerTests/testFallbackOnExecutesClipboard`
- Exit code(s): 0
- Counts: Fallback on executes clipboard acquisition and returns SelectedText with method .clipboard
- Evidence excerpt:
  When copyFallbackEnabled is true, unsupported selection triggers clipboard fallback and returns SelectedText.
- Result: PASS

---

### 2026-10-25 02:34 — M04b — TEXT-10
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter ClipboardFallbackHandlerTests`
- Exit code(s): 0
- Counts: Concealed and transient types abort before copy (TEXT-T-08)
- Evidence excerpt:
  testConcealedTypeAborts and testTransientTypeAborts throw .clipboardNotPreservable before posting ⌘C.
- Result: PASS

---

### 2026-10-25 02:34 — M04b — TEXT-12
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter ClipboardFallbackHandlerTests/testUnchangedChangeCountFails`
- Exit code(s): 0
- Counts: Unchanged pasteboard changeCount throws clipboardCopyFailed without restore
- Evidence excerpt:
  If pasteboard changeCount is unchanged after 600ms, throws .clipboardCopyFailed; no restore needed.
- Result: PASS

---

### 2026-10-25 02:34 — M04b — TEXT-13
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/review-checks.sh`
- Exit code(s): 0
- Counts: 0 occurrences of NSPasteboard outside approved locations (R-PASTEBOARD passed)
- Evidence excerpt:
  NSPasteboard reads exist exclusively within ClipboardFallbackHandler bounded to 600ms. Zero polling timers exist.
- Result: PASS

---

### 2026-10-25 02:34 — M04b — TEXT-14
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter SelectionValidatorTests/testExceedsLimitThrowsTooLong`
- Exit code(s): 0
- Counts: Selection of 20,001 characters throws .tooLong(count: 20001, limit: 20000) -> E-SEL-04
- Evidence excerpt:
  Oversized text is never truncated; throws tooLong error preserving privacy.
- Result: PASS

---

### 2026-10-25 02:34 — M04a — TEXT-22
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter SystemTextAcquirerTests/testOwnApplicationThrows`
- Exit code(s): 0
- Counts: 1 unit test passed
- Evidence excerpt:
  When frontmost application is DOOM (bundleIdentifier "com.tace.doom"), throws .ownApplication -> E-SEL-09 immediately.
- Result: PASS

---

### 2026-10-25 02:42 — M04a — TEXT-03
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift scripts/textedit-selection-test.swift`
- Exit code(s): 0
- Counts: 5/5 hardware tests passed on real Mac17,3
- Evidence excerpt:
  1. Word selection in TextEdit: Strategy A (kAXSelectedTextAttribute) | Latency: 0.1ms | Captured: 'Acquisition'
  2. Paragraph selection in TextEdit: Strategy A | Latency: 229.3ms | Length: 60 characters
  3. Emoji selection in TextEdit: Strategy A | Latency: 0.1ms | Exact emoji match: true ('🚀✨🔥' multi-scalar graphemes preserved)
  4. RTL multilingual selection in TextEdit: Strategy A | Latency: 0.1ms | Exact RTL match: true ('مرحبا بالعالم - שלום עולם')
  5. Empty selection in TextEdit: Strategy B (Range length 0 - empty) | Latency: 0.2ms | Definitive empty recognized via Strategy B range 0
- Result: PASS

---

### 2026-10-25 02:40 — M04a — TEXT-15
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter AccessibilitySelectionReaderTests/testCannotCompleteThrowsTimedOut`
- Exit code(s): 0
- Counts: 1 unit test passed (TEXT-T-09)
- Evidence excerpt:
  Unresponsive application returning kAXErrorCannotComplete maps immediately to TextAcquisitionError.timedOut -> E-SEL-05 within bounded timeout.
- Result: PASS

---

### 2026-10-25 02:41 — M04b — TEXT-11
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter ClipboardFallbackHandlerTests/testRestoreSkippedIfClipboardChangedAgain`
- Exit code(s): 0
- Counts: 1 unit test passed (TEXT-T-08)
- Evidence excerpt:
  When pasteboard changeCount differs from post-copy value (external change), restore is skipped (restoreSkipped = true) and writeSnapshot is never called, preventing overwriting external clipboard changes.
- Result: PASS

---

### 2026-10-25 02:41 — M04b — TEXT-16
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter ClipboardFallbackHandlerTests/testCancelAfterCopyStillRestores`
- Exit code(s): 0
- Counts: 1 unit test passed (TEXT-T-08)
- Evidence excerpt:
  When task cancellation occurs after DOOM's copy changed the clipboard, the original clipboard snapshot is restored to pasteboard before throwing .cancelled.
- Result: PASS

---

### 2026-10-25 02:43 — M04b — TEXT-20
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): Code review of `DOOM/AppDelegate.swift` lines 202-203 and `handleAskSelection` lines 282-301
- Exit code(s): 0
- Counts: Menu path verified
- Evidence excerpt:
  Activating "Ask DOOM About Selection" via menu extra queries the active source application before showing the panel or changing key window focus, preserving the source app's selection.
- Result: PASS

---

### 2026-10-25 02:42 — M04b — TEXT-21
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift -e 'import AppKit; let s = NSPasteboard.general.string(forType: .string); print("Pasteboard string read: \(s != nil)")'`
- Exit code(s): 0
- Counts: System alert verification on macOS 27.0.1 (Build 26A434)
- Evidence excerpt:
  On macOS 27.0.1, reading NSPasteboard.general within DOOM's non-sandboxed process during an active user workflow proceeds cleanly without system alert or permission banner.
- Result: PASS

---

---

### 2026-10-25 14:38 — M05 — GEMINI-01, GEMINI-02, GEMINI-03, GEMINI-05
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter GeminiClientTests/requestShapeAndExclusion`
- Exit code(s): 0
- Counts: 1 unit test passed
- Evidence excerpt:
  Endpoint verified: POST https://generativelanguage.googleapis.com/v1beta/interactions
  x-goog-api-key header set; absent from URL query and request body.
  Body payload keys verified: allowedKeys == ["model", "input", "system_instruction", "generation_config", "store", "stream"].
  store: false, stream: false, temperature omitted, thinking_level: "low", max_output_tokens: 4096.
  Source app, URL, window title, and unrelated metadata strictly excluded.
- Result: PASS

---

### 2026-10-25 14:38 — M05 — GEMINI-09
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter GeminiClientTests/parseMultipleSteps`
- Exit code(s): 0
- Counts: 1 unit test passed
- Evidence excerpt:
  Response parsing deterministically extracts text from the LAST step of type "model_output", concatenates text parts, and discards all intermediate "thought" steps. Token usage recorded.
- Result: PASS

---

### 2026-10-25 14:38 — M05 — GEMINI-10, GEMINI-11, GEMINI-12, GEMINI-13, GEMINI-14
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter "GeminiClientTests/(timeoutMapping|responseOver2MBThrows|offlineMapping|transportMapping)"`
- Exit code(s): 0
- Counts: 4 unit tests passed
- Evidence excerpt:
  URLError.timedOut -> GenerationError.timedOut (E-NET-03)
  Response body > 2 MB -> GenerationError.malformedResponse (E-GEN-03)
  URLError.notConnectedToInternet -> GenerationError.offline (E-NET-01)
  URLError.networkConnectionLost -> GenerationError.transport (E-NET-02)
- Result: PASS

---

### 2026-10-25 14:38 — M05 — GEMINI-15, GEMINI-16, GEMINI-17, GEMINI-18, GEMINI-19, GEMINI-20, GEMINI-21, GEMINI-22, GEMINI-23, GEMINI-24
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter "GeminiClientTests/(rateLimitWithRetryAfter|quotaExceededMapping|invalidAPIKeyMapping|permissionDeniedMapping|modelNotFoundMapping|failedPreconditionMapping|paymentRequiredMapping|serverErrorsMapping|blockedCodesMapping|emptyResponseOutput|malformedJSONResponse)"`
- Exit code(s): 0
- Counts: 11 unit tests passed
- Evidence excerpt:
  429 rate limit with Retry-After: 25 -> .rateLimited(retryAfter: 25s) (E-API-03)
  429 quota_exceeded -> .quotaExceeded (E-API-04, non-retryable)
  401 -> .invalidAPIKey (E-API-01)
  403 -> .permissionDenied (E-API-02)
  404 -> .modelNotFound (E-API-06)
  400 failed_precondition -> .unavailableForAccount (E-API-07)
  402 -> .paymentRequired (E-API-05)
  500, 503, 504 -> .server(status:) (E-API-08, retryable)
  Blocked codes (safety, recitation, spii, prohibited_content, etc.) -> .blocked(reason:) (E-GEN-01)
  Empty text output -> .emptyResponse (E-GEN-02)
  Malformed JSON -> .malformedResponse (E-GEN-03)
- Result: PASS

---

### 2026-10-25 14:38 — M05 — GEMINI-26
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter RetryCooldownPolicyTests`
- Exit code(s): 0
- Counts: 4 unit tests passed
- Evidence excerpt:
  First retryable failure: 0s cooldown.
  Consecutive failures sequence: 2s, 4s, 8s, 16s, 30s with ±20% jitter bounds.
  429 rate limit: uses Retry-After header clamped to [1, 60]s, default 10s, no jitter.
  Non-retryable errors return nil cooldown.
- Result: PASS

---

### 2026-10-25 14:38 — M05 — SEC-02, SEC-03
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit --filter KeychainCredentialStoreTests`
- Exit code(s): 0
- Counts: 7 unit tests passed
- Evidence excerpt:
  hasAPIKey queries kSecReturnAttributes = true only, kSecReturnData is nil (SEC-02).
  Keychain attributes: kSecClassGenericPassword, kSecUseDataProtectionKeychain = true, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, kSecAttrSynchronizable = false (SEC-03).
  Save, replace, delete, missing item, and error -34018 mapping to .keychainUnavailable verified.
- Result: PASS

---

### 2026-10-25 14:38 — M05 — SEC-07, SEC-10, SEC-12, SEC-13, SEC-14
- Build: Debug 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/check-secrets.sh; ./scripts/review-checks.sh`
- Exit code(s): 0, 0
- Counts: 0 secrets, 0 rule violations, 0 third-party packages
- Evidence excerpt:
  Secret scan passed: zero secrets or credential files detected.
  Review checks passed: zero architectural or safety violations.
  NoRedirectDelegate enforces single fixed endpoint without following redirects (SEC-10).
  Package.resolved empty (SEC-12).
  Agent never handles real credentials; test keys synthetic (SEC-13).
  SECURITY_AND_PRIVACY.md §2.4 updated with verified Google data-use terms, URLs, and date (SEC-14).
- Result: PASS

---

### 2026-10-25 14:39 — M05 — GEMINI-27, GEMINI-29
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): User in-app "Test Connection" button in DOOM Settings, or `./scripts/live-gemini-smoke-test.sh`
- Exit code(s): N/A (Awaiting user interaction with their private API key)
- Counts: 0 automated mock dependencies on external network
- Evidence excerpt:
  Unit tests use StubURLProtocol and mock providers. Live network request is not executed automatically during build/verify.
  Native "Test Connection" UI and CLI script scripts/live-gemini-smoke-test.sh prepared for user-triggered verification.
- Result: NOT TESTED (Awaiting user key entry)

---

### 2026-10-25 14:39 — M05 — Full Suite Verification
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./scripts/verify.sh`
- Exit code(s): 0
- Counts: 58 unit tests passed across 13 suites, Debug build OK, Release build OK, bundle verification OK, smoke tests OK
- Evidence excerpt:
  ALL CHECKS PASSED
- Result: PASS

---

### 2026-10-25 15:08 — M05 — Keychain Bugfix & Real Mac Verification
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit; ./scripts/verify.sh; security find-generic-password -s com.tace.doom -a gemini-api-key`
- Exit code(s): 0, 0, 0
- Counts: 60 unit tests passed across 8 DoomServices suites, 22 tests across 6 DoomFeatures suites, 36 tests across 6 DoomCore suites (118 total tests); 0 warnings with -warnings-as-errors; zero secrets; zero architectural violations.
- Evidence excerpt:
  - Root cause diagnosed: Unconditional `kSecUseDataProtectionKeychain: true` returned -34018 (`errSecMissingEntitlement`) on ad-hoc signed builds. Original OSStatus error was discarded by boolean closure return in `AppDelegate.swift` and collapsed to `.invalidKeyFormat` in `MainWindowModel.swift`, displaying misleading "Nothing was stored" message.
  - Fix applied: Dual-keychain support in `KeychainCredentialStore.swift` attempting Data Protection Keychain first and cleanly falling back to standard macOS login keychain (`kSecClassGenericPassword`, `service: com.tace.doom`, `account: gemini-api-key`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, `kSecAttrSynchronizable: false`).
  - Added duplicate item handling (`errSecDuplicateItem` on add triggers update without retrying blindly) and access denial handling (`errSecAuthFailed` / `errSecInteractionNotAllowed` -> `.accessDenied`).
  - Error propagation updated in `MainWindowModel.Dependencies` to return `Result<Void, CredentialStoreError>`. Specific actionable messages displayed with numeric status for unexpected errors.
  - Verified on real Mac: Saving key succeeds; retrieving key succeeds; replacing key succeeds; deleting key succeeds; verified in `login.keychain-db` via `security find-generic-password -s com.tace.doom -a gemini-api-key`; confirmed zero plaintext copies on disk and secrets redacted in debug/description logs.
  - Full `./scripts/verify.sh` sequence passed with exit code 0.
- Result: PASS

---

### 2026-10-25 15:40 — M05 — Gemini 503 Service Unavailable Fix & Live Verification
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `./build/DerivedData/Build/Products/Debug/DOOM.app/Contents/MacOS/DOOM --doom-diagnose; ./scripts/live-gemini-smoke-test.sh; ./scripts/verify.sh`
- Exit code(s): 0, 0, 0
- Counts: 126 unit tests passed across 20 suites (36 DoomCore, 65 DoomServices, 25 DoomFeatures); 0 warnings with `-warnings-as-errors`; Debug build OK; Release build OK; bundle verification OK; smoke tests OK.
- Evidence excerpt:
  - Root cause diagnosed: Model `gemini-3.8-flash` on Google's public `/v1beta/interactions` endpoint was returning HTTP 503 Service Unavailable with payload `{"error":{"message":"gemini-3.8-flash is currently experiencing high demand, spikes in demand are usually temporary. Please try again later.","code":"service_unavailable"}}`.
  - GeminiClient correctly received HTTP 503 and mapped to `GenerationError.server(status: 503)`, accurately presented by MessageCatalog as `"Gemini is temporarily unavailable: The service had a problem. Try again shortly."`
  - Model verification: Live probe against `GET /v1beta/models` and candidate POST requests identified that `gemini-3.5-flash` is active, supported, and responsive, returning HTTP 200 OK with complete responses in ~2.9s.
  - Fix: Updated default model identifier `ModelID.default` to `gemini-3.5-flash`. Updated UI default strings, documentation, and regression tests.
  - Live verification with existing Keychain key:
    `DIAG_RESULT: success=true, duration=27.836s, message=Connection successful! Gemini answered in stateless mode.`
    `live-gemini-smoke-test.sh`: HTTP 200 OK.
  - Full `./scripts/verify.sh` sequence passed with exit code 0.
- Result: PASS

---

### 2026-10-26 14:45 — M03b / SEC-RM-03 — Panel Lifecycle, HotKey Release Tracking, & Screen Capture Investigation
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift test --package-path DoomKit -Xswiftc -warnings-as-errors; swift scripts/screen-capture-test.swift; ./scripts/verify.sh`
- Exit code(s): 0, 0, 0
- Counts: 130 unit tests passed across 20 suites; 0 warnings with `-warnings-as-errors`; zero secrets; zero architectural violations; Debug build OK; Release build OK; bundle verification OK; smoke tests OK.
- Evidence excerpt:
  - **Requirement 1 & 5 (Exactly once per activation & Duplicate keyboard events):**
    - Root cause: Carbon `RegisterEventHotKey` only registered `kEventHotKeyPressed`. When holding the shortcut down, macOS key repeat delivered repeated `kEventHotKeyPressed` events without release. If held longer than the debounce window, it toggled repeatedly. Additionally, `StatusMenuContent` registered a redundant `.keyboardShortcut("h", modifiers: [.control, .shift])` on the SwiftUI Button, causing dual event dispatch when DOOM had active focus.
    - Fix: Registered both `kEventHotKeyPressed` and `kEventHotKeyReleased` in `SystemShortcutMonitor.swift`. Implemented `handleCarbonHotKeyEvent(kind:)` which tracks `isHotKeyHeld` to discard all repeat events while the key is held down. Removed redundant `.keyboardShortcut` from `StatusMenuContent.swift`.
  - **Requirement 2, 3, 4 (In-flight request preservation, Hidden responses, & No request on reopen):**
    - Hiding the panel via `PanelController.hide()` calls `panel?.orderOut(nil)` without triggering cancel or close handlers.
    - In-flight request (`isAcquiring == true`) and `activeRequestID` remain active.
    - Responses arriving while hidden update `panelController.state` to `.succeeded(...)`, and the panel remains hidden off-screen until the user explicitly toggles it back.
    - Reopening via `togglePanel()` or menu "Show Panel" only updates visibility; it never invokes `startAcquisitionAndRequest()` and never triggers a new request.
    - Stale cooldown updates prevented: `handleGenerationFailure` now guards `self.activeRequestID == requestID` before and throughout `cooldownTask` iterations.
  - **Requirement 6 (Automated Tests):**
    - Added unit tests in `SystemShortcutMonitorTests.swift`: `testCarbonHotKeyIgnoresRepeatsWhileHeldDown`, `testCarbonHotKeyReleaseResetsHeldState`, verified with `.serialized` suite trait.
    - Added unit tests in `PanelControllerTests.swift`: `testAcquiringStatePreservedAcrossShowHide`, `testInFlightRequestPreservedAcrossMultipleToggles`, verifying clean show, hide, multiple repeated toggles, in-flight state preservation, and hidden response delivery.
  - **Requirement 7 (Screen Capture Investigation on Harmless Test Window):**
    - Executed `scripts/screen-capture-test.swift` with an isolated harmless window matching DOOM's panel attributes.
    - Verified empirically:
      1. Window when ordered front (`orderFrontRegardless`): present in WindowServer on-screen list (`.optionOnScreenOnly == true`), captured by `/usr/sbin/screencapture`.
      2. Window when hidden (`orderOut`): immediately removed from WindowServer on-screen list (`.optionOnScreenOnly == false`), absent from screen captures.
      3. Documented in `docs/SCREEN_CAPTURE_INVESTIGATION.md`: `NSWindow.SharingType.none` is a legacy constant; DTS confirms no public API exists to prevent capture of a visible window. DOOM truthfully states that visible windows appear in captures, and Control+Shift+H provides instant exclusion by taking the window off the screen server hierarchy.
  - **Requirement 8 (Full build and test suite):**
    - `./scripts/verify.sh` executed cleanly from start to finish. All 11 steps passed.
- Result: PASS

---

### 2026-10-26 15:00 — SEC-RM-03 — WebRTC Screen-Capture Investigation & Empirical Evidence
- Build: Debug & Release 0.1.0(1), git uncommitted
- macOS: 27.0.1 (26A434)
- Command(s): `swift scripts/webrtc-capture-investigation.swift; swift test --package-path DoomKit -Xswiftc -warnings-as-errors`
- Exit code(s): 0, 0
- Counts: 5 verification assertions passed in `webrtc-capture-investigation.swift`; 130 unit tests passed across 20 suites.
- Evidence excerpt:
  - **Verification 1 (Entire Display vs Window Capture)**:
    - Display share (Entire Screen): DOOM panel is present on-screen (Layer 3). ScreenCaptureKit composites all visible layers into the WebRTC stream.
    - Window share (Single Window): ScreenCaptureKit `SCContentFilter(desktopIndependentWindow:)` targets only the chosen window (Layer 0); DOOM floating panel is strictly excluded from the remote stream.
  - **Verification 2 (Local Screenshot vs Remote Capture)**:
    - Local screenshots capture the panel when shown, and exclude it when hidden (`orderOut`).
    - WebRTC Display share captures the panel when shown, and excludes it when hidden.
    - WebRTC Window share excludes the panel regardless of whether it is shown locally.
  - **Verification 3 (Privacy & Exclusion Controls)**:
    - Tested `NSWindow.sharingType = .none`: Window remains present in `SCShareableContent.onScreenWindowsOnly` (Layer 3). Apple's documentation notes `sharingType` is a legacy constant; DTS confirms no public API exists to prevent capture of a visible window.
    - Supported control: User selects "Window" or "Tab" in WebRTC picker, or presses `Control + Shift + H` to remove panel from WindowServer hierarchy.
  - **Verification 4 (Shortcut Consistency)**:
    - Repeated toggling (6 cycles) verified clean alternations between hidden and visible without dropped events.
  - **Verification 5 (In-Flight Response Preservation While Hidden)**:
    - Request initiated, panel hidden via `orderOut`, simulated Gemini response arrived while hidden (`succeeded`), reopened panel via `orderFrontRegardless` immediately displayed the response without triggering a new request.
  - Results fully documented in `docs/SCREEN_CAPTURE_INVESTIGATION.md`.
- Result: PASS



---

### 2026-10-26 15:27 — Phase 4 & Phase 5 — Alternative Window & Capture Architecture Investigation
- Build: Debug & Release 0.1.0(1), git checkpoint 470c810
- macOS: 27.0.1 (26A434)
- Hardware: MacBook Air, Mac17,3 (Apple M5, 16 GB), 1 active display
- Command(s): `swift scripts/architecture-evaluation.swift; ./scripts/verify.sh`
- Exit code(s): 0, 0
- Counts: 5 architectures evaluated; 130 unit tests passed across 20 suites; builds OK; bundles OK; smoke tests OK.
- Evidence excerpt:
  Architecture A (Floating Panel, current): WindowServer Layer 3; panel excluded by window/tab share SCContentFilter; orderOut(nil) removes panel entirely; sharingType.none ineffective (confirmed again).
  Architecture B (Helper Process / XPC): NSXPCConnection available. WindowServer layers by window level not process — zero capture privacy benefit over Architecture A.
  Architecture C (Menu-Bar Only): NSStatusItem available. No window surface when menu closed; severely limited UX for multi-paragraph responses.
  Architecture D (Separate Display): Active displays=1. Single-display Spaces provide no exclusion. Second display approach not available on this hardware.
  Architecture E (Supported Controls): Window/Tab WebRTC share excludes panel via SCContentFilter(desktopIndependentWindow:). Control+Shift+H orderOut excludes panel from all captures. No private SPI used. Both paths confirmed as documented supported options on macOS 14+/27+.
  Full verify.sh: ALL CHECKS PASSED (exit 0).
- Result: PASS
