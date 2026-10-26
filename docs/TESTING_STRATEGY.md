# DOOM — Testing Strategy (Phase 03)

| | |
|---|---|
| **Status** | Approved plan. **No test exists yet and none has been run.** |
| **Date** | 2026-10-24 |
| **Owner from handoff onward** | Antigravity (sole development agent) |
| **Companions** | `ACCEPTANCE_CRITERIA.md` (what must be true), `IMPLEMENTATION_ROADMAP.md` (when), `ENGINEERING_STANDARDS.md` §7 (test rules), the Phase 02 specs (detailed procedures) |

This document defines **how** DOOM is verified: test layers, the exact commands, how real-Mac checks are run when the agent cannot see the screen, which review greps apply, how live Gemini tests are run without exposing the API key, and how evidence is recorded.

---

## 1. Test layers

| Layer | Code | Runs where | Who acts | Examples |
|---|---|---|---|---|
| Unit (automated) | AUTO | `swift test` on the Mac; no permissions, no network, no clock, no randomness | Antigravity | `ChordRecognizer`, `SelectionValidator`, request builder, parser, error mapper, `AssistantController` transitions, `PanelGeometry` |
| Review gate | REV | `scripts/review-checks.sh` + reading the code | Antigravity | Layering, ownership of privileged APIs, logging hygiene |
| Script checks | AUTO | `verify-bundle.sh`, `smoke-test.sh`, `check-secrets.sh`, `verify.sh` | Antigravity | Bundle identity, hardened runtime, no sandbox, `DOOM_SMOKE_OK` |
| Live integration | INT | `swift test --filter GeminiLiveTests` with opt-in environment variables | **The user, in their own Terminal** (P3-09) | GEMINI-INT-01…04 |
| Real Mac, no permission | RM | DOOM launched with `open` | The user performs numbered physical steps; Antigravity reads logs | Menu, main window, ⌃⇧H |
| Real Mac, permission | RM + PERM | Same, with Accessibility granted to DOOM | Same | Fn chord, Chrome selection |

**Swift Testing** (`import Testing`, `@Test`, `#expect`, `#require`) is used for all unit tests (Phase 01 decision). Test doubles are the fakes listed in `MODULE_CONTRACTS.md`. No mocking framework.

---

## 2. Status values and evidence

- Status vocabulary, completion rule and gate rule: `ACCEPTANCE_CRITERIA.md` §11 (PASS / FAIL / BLOCKED / NOT TESTED / NOT APPLICABLE).
- **Evidence** is recorded in `docs/VERIFICATION_LOG.md` (created in M00). Each entry has this form:

```markdown
### <YYYY-MM-DD HH:MM> — <milestone> — <criterion or procedure IDs>
- Build: <Debug|Release> <MARKETING_VERSION>(<CURRENT_PROJECT_VERSION>), git <short SHA or "uncommitted">
- macOS: <ProductVersion> (<BuildVersion>)
- Command(s): `<exact command>`
- Exit code(s): <n>
- Counts: <tests passed / failed / skipped, or activations observed / expected>
- Evidence excerpt: <≤ 20 lines of output or log, content-free>
- User observation (RM only): "<what the user reported>", <date>
- Result: PASS | FAIL | BLOCKED (<blocker>) | NOT TESTED (<reason>)
```

- **Never** paste into the log: the API key, selected text, model responses, clipboard contents, Apple ID, full team ID, certificate names, serial numbers, or user-name paths (replace with `~`).
- A build that succeeds is evidence that the code **builds**, nothing more.
- Synthetic key events (`CGEventPost`, `osascript … keystroke`) are **never** evidence for shortcut criteria.

---

## 3. Command reference

All commands run from the repository root on the user's Mac. `build/` is git-ignored. Antigravity creates `build/logs/` with `mkdir -p build/logs` before the first logged command. `${PIPESTATUS[0]}` gives the exit code of the first command in a pipe (bash/zsh: in zsh use `${pipestatus[1]}`; the scripts are bash).

| ID | Purpose | Command |
|---|---|---|
| CMD-ENV | Environment facts (M00) | See `IMPLEMENTATION_ROADMAP.md` M00 §9 |
| CMD-PKG-TEST | Unit tests, warnings as errors | `swift test --package-path DoomKit -Xswiftc -warnings-as-errors 2>&1 \| tee build/logs/swift-test.log; echo "exit=${PIPESTATUS[0]}"` |
| CMD-PKG-XCTEST | Same tests through Xcode's toolchain | `(cd DoomKit && xcodebuild -scheme DoomKit-Package -destination 'platform=macOS,arch=arm64' -derivedDataPath ../build/PackageDerivedData test SWIFT_TREAT_WARNINGS_AS_ERRORS=YES) 2>&1 \| tee build/logs/xcodebuild-test.log`. The scheme name `DoomKit-Package` is SwiftPM's generated scheme for multi-product packages *[Assumed: confirm with `(cd DoomKit && xcodebuild -list)` in M01 and record the actual name]* |
| CMD-PROJECT | Project validity (FND-02/03) | `plutil -lint DOOM.xcodeproj/project.pbxproj` · `xcodebuild -list -project DOOM.xcodeproj` · `xcodebuild -project DOOM.xcodeproj -scheme DOOM -configuration Debug -showBuildSettings 2>/dev/null \| grep -E '^ *(PRODUCT_BUNDLE_IDENTIFIER\|MACOSX_DEPLOYMENT_TARGET\|ARCHS\|ENABLE_HARDENED_RUNTIME\|ENABLE_APP_SANDBOX\|SWIFT_VERSION\|SWIFT_STRICT_CONCURRENCY\|CODE_SIGN_STYLE\|INFOPLIST_KEY_LSUIElement) ='` |
| CMD-BUILD-DEBUG | Debug build, zero warnings | `scripts/build.sh debug SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -allowProvisioningUpdates 2>&1 \| tee build/logs/build-debug.log; echo "exit=${PIPESTATUS[0]}"; grep -c ' warning: ' build/logs/build-debug.log` |
| CMD-BUILD-RELEASE | Release build | Same with `release` and `build-release.log` |
| CMD-VERIFY-BUNDLE | Bundle checks (D-16) | `scripts/verify-bundle.sh debug` / `release` |
| CMD-SMOKE | Launch smoke test (D-15) | `scripts/smoke-test.sh debug` / `release`. Runs the binary directly. **Never** use it for TCC checks (P3-07) |
| CMD-SECRETS | Secret scan | `scripts/check-secrets.sh` |
| CMD-REVIEW | Review greps (§6) | `scripts/review-checks.sh` |
| CMD-VERIFY | Everything above in sequence | `scripts/verify.sh` → last line `ALL CHECKS PASSED`; full log in `build/verification.log` |
| CMD-SIGN | Signing facts (FND-05, PKG-03) | `codesign -dvv <app> 2>&1 \| grep -E '^(Identifier\|Authority\|TeamIdentifier\|Runtime Version\|Signature)'` · `codesign --verify --deep --strict --verbose=2 <app>` · `codesign -d --entitlements - --xml <app> \| plutil -p -` · `P=<app>/Contents/embedded.provisionprofile; [ -f "$P" ] && security cms -D -i "$P" \| plutil -extract ExpirationDate raw -o - -` |
| CMD-LAUNCH | Launch through LaunchServices (P3-07) | `open build/DerivedData/Build/Products/Debug/DOOM.app` (installed copy: `open ~/Applications/DOOM.app`) |
| CMD-STOP | Stop a running DOOM between builds | Ask the user to choose **Quit DOOM** from the menu (needed for LIFE-12 evidence); otherwise `pkill -x DOOM \|\| true` |
| CMD-LOG-SHOW | Read evidence after the user's steps | `log show --last 10m --style compact --predicate 'subsystem == "com.tace.doom"' \| tee build/logs/<procedure-id>.log` |
| CMD-LOG-STREAM | Live diagnostic detail, including `debug` | `log stream --style compact --level debug --predicate 'subsystem == "com.tace.doom"'`. Run as a background process, or ask the user to run it in Terminal and stop it with ⌃C. Debug lines are **not persisted** and cannot be recovered with `log show` |
| CMD-DEFAULTS | Stored preferences (SEC-06) | `defaults read com.tace.doom` |
| CMD-KEYCHAIN-CLI | File-based keychain check (SEC-RM-04) | `security find-generic-password -s com.tace.doom -a gemini-api-key` (**never** `-w`, `-g` or `dump-keychain`) |
| CMD-TCC-RESET | Reset DOOM's Accessibility grant | `tccutil reset Accessibility com.tace.doom`. **Only after the user says yes** in that session |
| CMD-FS | File writes (SEC-RM-01) | `sudo fs_usage -w -f filesys DOOM` (needs `sudo`, so **the user runs it** in Terminal and stops it with ⌃C) |
| CMD-NET | Connections (SEC-RM-02) | `lsof -nP -iTCP -a -c DOOM` snapshots after launch, after each activation and after 2 minutes idle; optionally `nettop -P -m tcp -p $(pgrep -x DOOM)` run by the user |
| CMD-LIVE | Live Gemini tests | §7 (the user runs it) |

**Exit codes:** every command's exit code is recorded. A non-zero exit is a FAIL for that step unless the procedure says a non-zero exit is expected (for example `security find-generic-password` exits 44 when the item is not found).

---

## 4. Test inventory (planned)

The Phase 02 specs define the procedures. Planned test files (names may be refined through an IMPL decision; every test maps to an acceptance or procedure ID: TEST-04):

| Module | Test file (planned) | Procedures |
|---|---|---|
| DoomCoreTests | Phase 01 tests (`AppConfigurationTests`, `LaunchOptionsTests`, `AppContextTests`) | FND-04 |
| DoomCoreTests | `SelectionValidatorTests` | TEXT-T-01…06 |
| DoomCoreTests | `ModelIDTests`, `APIKeyTests` | GEMINI-07, UI-T-07, key length 20–256 |
| DoomServicesTests | `ChordRecognizerTests` | SHORTCUT-T-01…07 |
| DoomServicesTests | `KeyCodeResolverTests` | SHORTCUT-T-08 |
| DoomServicesTests | `SelectionStrategyTests`, `SelectionTimeoutTests` | TEXT-T-07, TEXT-T-09, TEXT-18 (pure Chromium set) |
| DoomServicesTests | `ClipboardFallbackTests` (in-memory `PasteboardAccess` fake) | TEXT-T-08, TEXT-10, -11, -12, -16 |
| DoomServicesTests | `InteractionsRequestBuilderTests`, `InteractionsResponseParserTests`, `GeminiErrorMapperTests`, `GeminiClientTests` (`StubURLProtocol`) | GEMINI-T-01…06 |
| DoomServicesTests | `GeminiLiveTests` (skipped unless opted in; reported as skipped) | GEMINI-INT-01…04, TEST-03 |
| DoomFeaturesTests | `AssistantControllerTests` | LIFE-T-01…04, SHORTCUT-T-09, GEMINI-T-07, SHORTCUT-08 |
| DoomFeaturesTests | `PanelGeometryTests` | UI-T-01…03 |
| DoomFeaturesTests | `MessageCatalogTests` | UI-T-04 |
| DoomFeaturesTests | `MainWindowModelTests` (evolves `HomeViewModelTests`) | UI-T-05…08 |
| DoomFeaturesTests | `SingleInstancePolicyTests` (pure decision function) | LIFE-14 |
| DoomFeaturesTests | `MarkdownRenderingTests` (links not actionable) | UI-36, SEC-11 |

Pure contrast test for UI-02: a test over the token pairs actually used (computed WCAG luminance), in `DoomFeaturesTests/ThemeContrastTests`.

**Not unit-testable** (stated, not faked): real `AXUIElement` reads, real `NSEvent` monitors, Carbon hotkey registration, the data protection keychain from a test bundle, TCC, non-activating panel focus behaviour, screen capture. These are covered by RM procedures.

---

## 5. Real-Mac verification protocol (the agent cannot see the screen)

1. **Build and sign** with CMD-BUILD-DEBUG, then CMD-VERIFY-BUNDLE.
2. **Stop any running instance** (CMD-STOP).
3. **Launch with CMD-LAUNCH.** Never run the binary directly for permission-related checks (P3-07).
4. **Prepare synthetic content** (TEST-07): the fixture `ManualTests/selection-test-page.html` (P3-14) opened in Chrome with `open -a "Google Chrome" ManualTests/selection-test-page.html`, or a TextEdit document whose text Antigravity writes into `build/manual/` (git-ignored).
5. **Give the user numbered physical steps,** at most about 8 per message, each with what they should see. Example: "3. Click the button *Select passage B (ASCII, 412 characters)*. 4. Press and hold fn, control and option together, then release all three. 5. Repeat step 4 nineteen more times, about one second apart. 6. Tell me 'done', plus anything unexpected you saw."
6. **Read the evidence** with CMD-LOG-SHOW (notice-level events, §8) and compare counts and durations with the expected values.
7. **Ask one confirmation question** only for what logs cannot show (for example "Did the emoji picker appear?" or "Is the panel visible above the full-screen window?").
8. **Record** the entry in `VERIFICATION_LOG.md` (§2).
9. If behaviour differs from the spec, **do not re-label the requirement**. Record FAIL with measurements, then follow the milestone's recovery strategy.

**Permission hygiene:** before any `tccutil reset`, ask: "May I reset DOOM's Accessibility permission? You will need to grant it again in System Settings." System Settings steps are written out in full (System Settings › Privacy & Security › Accessibility › DOOM switch).

---

## 6. Review checks (`scripts/review-checks.sh`)

The script is created in M01 and grows with each milestone. Each rule is a grep with an **allowed-files list**. Any match outside the allowed files fails the script (exit 1), which prints `file:line` only. Paths below are relative to `DoomKit/Sources/` unless they start with `DOOM/` or `Config/`.

### 6.1 Rules active from M01

| Rule | Pattern (extended regex) | Allowed in |
|---|---|---|
| R-LAYER-1 | `^import (SwiftUI\|AppKit\|Cocoa)` in `DoomCore/` | nowhere |
| R-LAYER-2 | `^import (Carbon\|ApplicationServices\|Security)` | `DoomServices/` only |
| R-LAYER-3 | `^import DoomServices` in `DoomFeatures/` | nowhere |
| R-GLOBALS | `Bundle\.main\|ProcessInfo` in `DoomKit/Sources` | nowhere (only `DOOM/AppDelegate.swift`, which is outside the package) |
| R-UNSAFE | `fatalError\|try!\|preconditionFailure\|@unchecked Sendable\|nonisolated\(unsafe\)\|Task\.detached\|DispatchQueue\|print\(\|NSLog` | nowhere, except `DispatchQueue` in `DoomServices/Selection/AccessibilitySelectionReader.swift` for the dedicated serial Accessibility queue (P2-04), if that design is used |
| R-PBXPROJ | `DEVELOPMENT_TEAM\|SWIFT_DEFAULT_ACTOR_ISOLATION\|SWIFT_APPROACHABLE_CONCURRENCY\|PRODUCT_BUNDLE_IDENTIFIER\|INFOPLIST_KEY_` in `DOOM.xcodeproj/project.pbxproj` | nowhere |
| R-XCCONFIG | `DEVELOPMENT_TEAM\|SWIFT_TREAT_WARNINGS_AS_ERRORS` in `Config/DOOM.xcconfig` | nowhere |
| R-BUNDLEID | `com\.tace\.doom` in Swift sources | nowhere (derived from `Bundle.main` in the app target and passed in; LIFE-15) |
| R-SECRET-LOG | `Logger` calls that interpolate `key`, `apiKey`, `text`, `body`, `message`, `response`, `selection` without being a count | nowhere (manual reading backs this grep: SEC-04) |

### 6.2 Rules added per milestone (privileged API ownership)

| Milestone | Rule | Pattern | Allowed in |
|---|---|---|---|
| M01 → until replaced | R-FUTURE | `AXUIElement\|AXIsProcessTrusted\|CGEvent\|RegisterEventHotKey\|addGlobalMonitorForEvents\|NSPanel\|SecItem\|URLSession\|NSPasteboard\|generativelanguage\|LSUIElement\|UsageDescription` | nowhere. Each token **leaves** this rule only in the milestone that introduces it, and moves to an ownership rule below |
| M03a | R-OWN-MONITOR | `addGlobalMonitorForEvents\|addLocalMonitorForEvents` | `DoomServices/Shortcuts/SystemShortcutMonitor.swift` |
| M03a | R-OWN-TRUST | `AXIsProcessTrusted` | `DoomServices/SystemPermissionChecker.swift` |
| M03a | R-NO-CHARS | `\.characters\b\|charactersIgnoringModifiers` | nowhere in `Shortcuts/` except `KeyCodeResolver.swift` (layout resolution, no event text) — SHORTCUT-10 |
| M03a | R-NO-TAP | `CGEventTapCreate\|tapCreate\|CGPreflightListenEventAccess\|CGRequestListenEventAccess` | nowhere, unless the user approves fallback option A |
| M02 | R-OWN-PANEL | `NSPanel` | `DoomFeatures/Panel/DoomPanel.swift`, `DoomFeatures/Panel/PanelController.swift` |
| M02 | R-LSUIELEMENT | `LSUIElement` | `Config/DOOM.xcconfig` only (as `INFOPLIST_KEY_LSUIElement = YES`) |
| M02 | R-NO-CAPTURE | `sharingType` | nowhere (P2-12) |
| M03b | R-OWN-HOTKEY | `RegisterEventHotKey\|UnregisterEventHotKey\|InstallEventHandler` | `DoomServices/Shortcuts/SystemShortcutMonitor.swift` |
| M03b | R-OWN-TIS | `TISCopy\|UCKeyTranslate` | `DoomServices/Shortcuts/KeyCodeResolver.swift` |
| M04a | R-OWN-AX | `AXUIElement` | `DoomServices/Selection/AccessibilitySelectionReader.swift`, `DoomServices/SystemPermissionChecker.swift` (only if needed for the trust check) |
| M04a | R-AX-SYSWIDE-TIMEOUT | `AXUIElementSetMessagingTimeout\(\s*AXUIElementCreateSystemWide` | nowhere (TEXT-17) |
| M04a | R-ENHANCED-UI | `AXEnhancedUserInterface` | `AccessibilitySelectionReader.swift` only, guarded by the Chromium bundle-ID set (TEXT-18) |
| M04b | R-OWN-PASTEBOARD | `NSPasteboard` | `DoomServices/Selection/ClipboardFallback.swift`; `DoomFeatures/Assistant/AssistantController.swift` (write-only `copyResponse()`, P3-15) |
| M04b | R-OWN-CGEVENT | `CGEvent` | `DoomServices/Selection/ClipboardFallback.swift` (posting ⌘C only) |
| M04b | R-USERDEFAULTS | `UserDefaults` | `DoomServices/UserDefaultsPreferences.swift` (first needed for `copyFallbackEnabled`) |
| M04b | R-NO-POLL | `Timer\b\|scheduledTimer\|DispatchSourceTimer` | nowhere (UI-22, TEXT-13). Delays use `Task.sleep` |
| M05 | R-OWN-SECITEM | `SecItem` | `DoomServices/KeychainCredentialStore.swift` |
| M05 | R-NO-RETURNDATA-PRESENCE | `kSecReturnData` | only in the read-for-request function of `KeychainCredentialStore.swift`, never in `hasAPIKey` (SEC-02, checked by reading) |
| M05 | R-OWN-NET | `URLSession\|URLRequest` | `DoomServices/Gemini/` |
| M05 | R-HOST | `generativelanguage\.googleapis\.com` | `DoomCore/Configuration/GeminiConfiguration.swift` |
| M05 | R-NO-SHARED-SESSION | `URLSession\.shared\|\.default\b.*URLSessionConfiguration` | nowhere (ephemeral only: GEMINI-05) |
| M06 | R-ONE-CALLSITE | `\.respond\(` (the `AIResponding` call) | exactly one occurrence, in `AssistantController.swift` (GEMINI-28) |
| M06 | R-NO-OPENURL | `NSWorkspace\.shared\.open\|openURL\|OpenURLAction` within `DoomFeatures/Panel/` (response rendering) | nowhere (SEC-11). Opening System Settings from the main window (`x-apple.systempreferences:` URL) is allowed outside `Panel/` |
| Always | R-DEPS | `.package(` in `DoomKit/Package.swift` | nowhere (SEC-12) |
| Always | R-NO-USAGE | `UsageDescription` | nowhere (SEC-08) |

The script must be **readable**: one function per rule, with the rule ID printed on failure. A rule may be relaxed only through an IMPL decision in `TECHNICAL_DECISIONS.md` §E that names the file and the reason.

---

## 7. Live Gemini tests (P2-17, P3-09)

**Antigravity never handles the key.** The user runs the live tests in **their own Terminal app** (not Antigravity's terminal):

```bash
cd "<repository folder>"
read -rs DOOM_GEMINI_TEST_API_KEY      # paste the key, press Return; nothing is echoed
export DOOM_GEMINI_TEST_API_KEY
DOOM_LIVE_GEMINI_TESTS=1 swift test --package-path DoomKit --filter GeminiLiveTests 2>&1 | tee build/logs/live-tests.log
unset DOOM_GEMINI_TEST_API_KEY
```

- The live tests send only **fixed synthetic input** (for example "Reply with the single word: ready"). They print only HTTP status, provider error codes, the `status` field, field **paths** observed in the JSON (for example `steps[].content[].text`) and durations. They **never** print the key, the response text or headers.
- Antigravity then reads `build/logs/live-tests.log` and confirms there is no key pattern (`scripts/check-secrets.sh` also scans `build/logs` for this check).
- Without the variables set, the tests are **skipped and reported as skipped** (TEST-03).
- Tier note for the user: with a free-tier key, Google may use the synthetic input for improvement (`SECURITY_AND_PRIVACY.md` §2.4). The input is synthetic, so no private content is involved.

---

## 8. Log evidence (content-free)

Logs use `os.Logger` with subsystem `com.tace.doom` and the categories in `SECURITY_AND_PRIVACY.md` §2.7. **Evidence events are logged at `notice` level** because `debug` (and in practice `info`) messages are not persisted and cannot be read back with `log show`. Diagnostic detail stays at `debug`.

Recommended evidence events (Antigravity may refine the names through an IMPL decision; the values must stay within the §2.7 allowlist):

| Category | Event (notice) | Values |
|---|---|---|
| `lifecycle` | `launch`, `instance.duplicate`, `terminate` | build number |
| `shortcut` | `chord.fired`, `chord.cancelled` (debug), `hotkey.registered`, `hotkey.pressed` | `status=<OSStatus>`, `hold_ms=<n>` |
| `permissions` | `accessibility` | `trusted=<bool>` |
| `selection` | `acquire.result` | `outcome=<enum>`, `strategy=<A\|B\|C\|fallback>`, `chars=<grapheme count>`, `duration_ms=<n>`, `warmup=<bool>` |
| `gemini` | `request.start`, `request.end` | `model=<id>`, `http=<n>`, `code=<provider code>`, `duration_ms=<n>`, `outcome=<enum>` |
| `keychain` | `op` | `kind=<add\|read\|presence\|delete>`, `status=<OSStatus>` |
| `panel` | `show`, `hide` | `reason=<enum>` |

`chars` is a count, never text. No source-app names or bundle IDs (TEXT-19). The `chars` value must match the count the fixture page displays (P3-14), and this is how selection correctness is verified without logging content.

---

## 9. Test data

- **Synthetic only** (TEST-07). The fixture page (created in M04a) contains:
  - fixed passages: ASCII prose; emoji with ZWJ sequences; Arabic or Hebrew RTL; multi-paragraph text; a combining-mark sample
  - a `<textarea>` and an `<input type="text">` with known text
  - an `<input type="password">` holding a dummy value
  - a JavaScript-generated passage of exactly **20,001** graphemes and one of exactly **20,000**
- Each passage shows its expected **grapheme count**, computed in the page with `Intl.Segmenter` (granularity `grapheme`), on text with no leading or trailing whitespace. That counting rule matches `SelectionValidator`, which counts graphemes after trimming.
- **Select passage X** buttons set the selection programmatically (`Selection.selectAllChildren`) so selections are exact and reproducible. The user still presses the shortcut physically.
- The page is a static file opened locally. It loads no external resources and needs no network.
- TextEdit content is written by Antigravity to `build/manual/*.txt` or `.rtf` (git-ignored) and opened with `open -a TextEdit <file>`.

---

## 10. Performance measurements

| Criterion | Method |
|---|---|
| UI-30 panel ≤ 150 ms | The user records the screen with ⇧⌘5 while activating 10 times; Antigravity steps through frames (`ffprobe` is not installed by default, so frames are counted by the user in QuickTime with the arrow keys, or `show`/`hide` notice timestamps are compared with `chord.fired` timestamps, which is the preferred method). Median of 10. |
| TEXT-23 Chrome latency | `acquire.result duration_ms` for the first activation after Chrome launch and 10 warm activations. Median and max. |
| GEMINI-27 latency (observation only) | `request.end duration_ms` |
| UI-37 main-thread hangs | Instruments › Time Profiler or the hang detector, run by the user if they agree; otherwise NOT TESTED with the reason |

---

## 11. Regression and full runs

- Every bug fix adds or updates a test that fails before the fix, where the bug is unit-testable. Otherwise an RM step is added to the affected procedure.
- `scripts/verify.sh` runs at the end of **every** milestone.
- **M08** runs everything: CMD-VERIFY, CMD-PKG-XCTEST, the REV reading pass, and a re-run of every RM procedure whose code path changed since it last passed (tracked in `PHASE_TRACKER.md`). Counts are recorded (TEST-06).

---

## 12. Limits of agent verification (R-32)

Antigravity **cannot** directly observe: what is on screen, whether a system prompt or the emoji picker appeared, physical key presses, focus behaviour, audio (VoiceOver), screen-capture output. For each it relies on the user's answer to one specific question **plus** content-free logs. When the user cannot or does not perform a step, the criterion stays **NOT TESTED** (never PASS).
