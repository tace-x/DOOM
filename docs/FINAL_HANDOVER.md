# DOOM — Final Project Handover Document (Milestone 12)

| Document Details | |
| :--- | :--- |
| **Product Name** | DOOM (Native macOS AI Assistant) |
| **Bundle Identifier** | `com.tace.doom` |
| **Version & Build** | `0.1.0 (1)` |
| **Target Platform** | macOS 27.0+ (Apple Silicon `arm64`) |
| **Verified Hardware** | MacBook Air (Mac17,3, Apple M5, 16 GB), macOS 27.0.1 (26A434) |
| **Installed Location** | `~/Applications/DOOM.app` |
| **Milestone** | M12 — Final Project Handover |
| **Overall Status** | **COMPLETE & READY FOR DAILY USE** |
| **Date** | 2026-10-26 |

---

## 1. Project Status Summary

DOOM has successfully traversed all implementation and verification phases (M00 through M12). The core product is fully built, thoroughly tested, hardened against edge cases, and installed at `~/Applications/DOOM.app`.

### Key Metrics:
- **Acceptance Criteria**: 130 / 130 Priority 0 (P0) criteria PASS (100.0%); 144 / 148 total criteria PASS (97.3%); 0 FAIL, 0 BLOCKED.
- **Unit Tests**: 185 unit tests across 24 test suites in `DoomKit` (`DoomCore`, `DoomServices`, `DoomFeatures`) — 100% passing with `-warnings-as-errors`.
- **Architectural Rules**: 21 review rules enforced via `./scripts/review-checks.sh` (0 violations).
- **Secrets Scan**: 0 secrets detected via `./scripts/check-secrets.sh`.
- **Packaging**: Verified Release build packaged with hardened runtime, no sandbox, and installed to `~/Applications/DOOM.app`.
- **v1 Acceptance Verdict**: **READY WITH LIMITATIONS** (v1 accepted per `ACCEPTANCE_CRITERIA.md §11`).

---

## 2. Verified Capabilities

The following capabilities have been confirmed through rigorous automated test suites and device execution:

1. **Global Text Selection Acquisition**:
   - Direct accessibility inspection via `AXUIElementCopyAttributeValue` from native macOS applications (TextEdit, Safari, Notes, Xcode) and Chromium browsers (Google Chrome).
   - Aborts immediately on own-app selection (`E-SEL-05`) and password/secure input fields (`E-SEL-03`).
   - Normalizes text up to 20,000 characters without truncation; trims leading/trailing whitespace and removes NUL characters.
2. **Opt-in Clipboard Fallback**:
   - Strictly opt-in (disabled by default).
   - When enabled, falls back to synthetic copy (`⌘C`) only when accessibility returns `.unsupported`.
   - Never falls back on password fields, transient password manager items (`org.nspasteboard.TransientType`), or concealed types (`com.agilebits.onepassword`).
   - Restores the original clipboard snapshot, and skips restoration safely if the user copied new data in the interim.
3. **Secure Gemini AI Integration**:
   - Zero-retention AI communication directly to Google Gemini (`gemini-2.5-flash`) over TLS 1.3.
   - API keys stored in macOS Data Protection Keychain under service `com.tace.doom` and account `gemini-api-key`.
   - Exponential retry cooldown policy with jitter for transient errors (500, 503, 504, transport).
   - Rate limit (HTTP 429) detection supporting lowercase `retry-after` header and quota exhaustion (`RESOURCE_EXHAUSTED`).
   - Provider error message sanitization preventing API key leakage in logs or UI.
4. **Floating HUD Panel**:
   - Non-activating `NSPanel` (`.floating` window level) that does not steal focus from the user's active work.
   - Smooth SwiftUI presentation with dark metallic theme tokens (`bgDeep`, `bgHigh`, `accentEmerald`).
   - Native Markdown rendering for bold, italic, code, lists, and headings, with clickable URLs stripped for security.
   - Dismissal via `Escape`, `⌘W`, or clicking outside.
   - Copy response to clipboard via `⌘C` or dedicated UI button.
5. **System Shortcuts & Control**:
   - Double-tap `fn` chord detection via global `flagsChanged` event monitor.
   - Global Carbon hotkey `Control+Shift+H` for panel visibility toggle, with layout-independent keycode resolution for `H`.
   - Single-flight enforcement: duplicate triggers while busy are rejected; in-flight requests survive panel toggling.

---

## 3. Repository Architecture

The project is structured into a clean macOS host application and a local modular Swift package (`DoomKit`):

```
DOOM/
├── DOOM/                                    # Host Application
│   ├── App.swift                            # SwiftUI App entry point
│   ├── AppDelegate.swift                    # Application coordinator & lifecycle
│   └── DOOM.entitlements                    # App entitlements (no sandbox, hardened runtime)
│
├── DoomKit/                                 # Modular Swift Package
│   ├── Sources/
│   │   ├── DoomCore/                        # Domain models, policies, contracts
│   │   │   ├── Domain/                      # SelectedText, APIKey, ModelID, Shortcut
│   │   │   ├── Policies/                    # RetryCooldownPolicy, SelectionValidator
│   │   │   └── Contracts/                   # TextAcquiring, AIResponding, CredentialStoring
│   │   │
│   │   ├── DoomServices/                    # Infrastructure implementations
│   │   │   ├── Gemini/                      # GeminiClient, Interaction DTOs
│   │   │   ├── Keychain/                    # KeychainCredentialStore (kSecUseDataProtectionKeychain)
│   │   │   ├── TextAcquisition/             # SystemTextAcquirer, AccessibilityReader, ClipboardFallback
│   │   │   ├── Shortcuts/                   # SystemShortcutMonitor, KeyCodeResolver
│   │   │   └── Permissions/                 # SystemPermissionChecker
│   │   │
│   │   └── DoomFeatures/                    # Presentation layer
│   │       ├── Assistant/                   # AssistantController, MessageCatalog
│   │       ├── Panel/                       # DoomPanel, PanelController, PanelView
│   │       ├── MainWindow/                  # MainWindowModel, MainWindowView, PrivacyNoticeView
│   │       └── Theme/                       # Dark metallic design tokens & contrast ratios
│   │
│   └── Tests/                               # Comprehensive unit tests (185 tests)
│       ├── DoomCoreTests/                   # 37 tests (Validator, APIKey, Cooldown, AppContext)
│       ├── DoomServicesTests/               # 87 tests (Gemini, Keychain, Acquirer, Shortcuts, Permissions)
│       └── DoomFeaturesTests/               # 61 tests (AssistantController, Panel, Theme, Markdown)
│
├── Config/                                  # Xcode configuration files
│   ├── Base.xcconfig
│   ├── Debug.xcconfig
│   └── Release.xcconfig
│
├── scripts/                                 # Verification, build, and management scripts
│   ├── build.sh                             # Builds Debug or Release configuration
│   ├── verify-bundle.sh                     # Validates app bundle structure and entitlements
│   ├── smoke-test.sh                        # Headless verification using --doom-smoke-test
│   ├── check-secrets.sh                     # Scans for exposed API keys or tokens
│   ├── review-checks.sh                     # Enforces 21 architectural and safety rules
│   ├── verify.sh                            # Complete automated verification pipeline
│   ├── install.sh                           # Builds, verifies, and installs to ~/Applications/DOOM.app
│   └── uninstall.sh                         # Safe uninstaller with --dry-run option
│
└── docs/                                    # Documentation and verification evidence
    ├── PHASE_TRACKER.md                     # Milestone progress tracker
    ├── VERIFICATION_LOG.md                  # Detailed execution evidence log
    ├── ACCEPTANCE_CRITERIA.md               # 148 acceptance criteria definitions
    ├── TESTING_STRATEGY.md                  # Quality gates and test architecture
    ├── FINAL_ACCEPTANCE_REPORT.md           # M10 acceptance report
    ├── POST_ACCEPTANCE_HARDENING.md         # M11 post-acceptance hardening report
    └── FINAL_HANDOVER.md                    # This document
```

---

## 4. Build, Installation, and Launch Instructions

### Building Debug and Release
```bash
# Debug build
./scripts/build.sh debug

# Release build (with warnings treated as errors)
./scripts/build.sh release SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

### Installing the Application
```bash
./scripts/install.sh
```
This builds the Release configuration, validates code signing, stages a backup, installs to `~/Applications/DOOM.app`, and runs a smoke test.

### Launching the Application
```bash
# From terminal
open ~/Applications/DOOM.app

# Or via Finder / Spotlight
# Open ~/Applications/DOOM.app
```

### Safe Uninstallation
```bash
# Preview uninstallation steps (dry run)
./scripts/uninstall.sh --dry-run

# Execute clean uninstallation
./scripts/uninstall.sh
```

---

## 5. Required Permissions and Shortcuts

### macOS Permissions
- **Accessibility (`AXIsProcessTrusted`)**: Required. Prompted on first launch or text acquisition. Must be enabled in **System Settings > Privacy & Security > Accessibility**.
- **Keychain**: Native macOS Data Protection Keychain. Does not require special prompts; isolated to `com.tace.doom`.
- **Screen Recording**: **NOT REQUIRED AND NOT USED.** DOOM strictly avoids screen capture APIs.

### Keyboard Shortcuts
- **Double-tap `fn`** (Fn chord): Asks DOOM about currently highlighted text.
- **`Control+Shift+H`**: Toggles assistant panel visibility without cancelling active queries.
- **`Escape`**: Cancels in-flight query or closes the panel.
- **`⌘W`**: Closes the assistant panel.
- **`⌘C`**: Copies AI response to clipboard when panel is displayed.
- **`⌘,`**: Opens Settings window.
- **`⌘Q`**: Quits DOOM cleanly.

---

## 6. Verification Commands and Outcomes

The entire verification suite was executed to establish final handover validity:

| Command | Purpose | Result |
|---|---|---|
| `./scripts/check-secrets.sh` | Leaked credential detection | **PASS** (0 secrets detected) |
| `./scripts/review-checks.sh` | 21 architectural and security rules | **PASS** (0 violations) |
| `swift test --package-path DoomKit -Xswiftc -warnings-as-errors` | 185 unit tests across 24 suites | **PASS** (100% pass, 0 warnings, 0 failures) |
| `./scripts/verify.sh` | Full end-to-end verification pipeline | **PASS** (`ALL CHECKS PASSED`, exit 0) |
| `./scripts/install.sh` | Build, bundle check, install to `~/Applications` | **PASS** (Clean install & smoke test passed) |
| `codesign --verify --deep --strict ~/Applications/DOOM.app` | Installed binary code signature | **PASS** (Valid signature, hardened runtime) |
| `./scripts/smoke-test.sh ~/Applications/DOOM.app` | Headless execution smoke test | **PASS** (`DOOM_SMOKE_OK` received, exit 0) |

---

## 7. Privacy and Security Considerations

1. **Zero Retention**: User text and AI responses are held strictly in ephemeral memory during an active request and immediately cleared. No databases, sqlite, json files, or cache files are written.
2. **Zero Telemetry**: No crash reporting, tracking, or network requests other than direct TLS 1.3 calls to the official Gemini endpoint.
3. **Keychain Protection**: Keys are stored using `kSecUseDataProtectionKeychain` and are never logged or exposed.
4. **Input Sanitization**: Selections are checked for maximum length (20,000 characters) and stripped of NUL characters. Password fields are never read.
5. **Hyperlink Stripping**: External hyperlinks in Gemini responses have URLs removed and are rendered as underlined text to prevent unintentional browser redirection (`SEC-11`).

---

## 8. Known Bugs and External Service Limitations

1. **Gemini Free-Tier Rate Limits (HTTP 429)**:
   - Free Gemini API keys have strict requests-per-minute limits. When exceeded, DOOM presents `E-API-04` ("Gemini API quota exhausted for this account.") and blocks requests until the quota window resets.
2. **Accessibility TCC Token Invalidation**:
   - If the application binary is re-signed or rebuilt, macOS TCC may invalidate the trust token. The remedy is toggling DOOM in System Settings > Accessibility or running `tccutil reset Accessibility com.tace.doom`.
3. **Non-Standard Canvas Applications**:
   - Electron or web apps that render text on canvas without standard accessibility elements require **Copy Fallback** to be enabled in Settings.

---

## 9. Manual Checks Still Outstanding

Four Priority 1 (P1) operational items remain documented for manual observation on the physical Mac:

| ID | Description | How to Verify on Physical Mac |
|---|---|---|
| **UI-30** | VoiceOver Screen Reader | Enable VoiceOver (`⌘F5`), activate DOOM, and confirm accessibility element descriptions are spoken accurately. |
| **UI-32** | Reduce Motion | Enable **System Settings > Accessibility > Display > Reduce motion** and verify panel transitions switch to instant opacity fades. |
| **UI-37** | Animation Smoothness | Visually verify that panel expansion and loading spinners feel fluid without dropped frames. |
| **UI-38** | Main Thread Responsiveness | Profile DOOM with Xcode Instruments (Time Profiler) to confirm main thread remains responsive during network requests. |

---

## 10. Changed Files and Final Git Status

The changes across Milestone 11 and Milestone 12 encompass the following files:

```
Modified Files:
  DOOM/AppDelegate.swift                                           # Activation debounce guard
  DoomKit/Sources/DoomCore/Domain/SelectedText.swift               # restoreSkipped property
  DoomKit/Sources/DoomCore/Domain/SelectionValidator.swift          # restoreSkipped preservation
  DoomKit/Sources/DoomFeatures/Panel/DoomPanel.swift               # Escape cancelOperation & ⌘W key equivalent
  DoomKit/Sources/DoomFeatures/Panel/PanelController.swift         # onCancelOrClose wiring
  DoomKit/Sources/DoomServices/Gemini/GeminiClient.swift           # Case-insensitive Retry-After & proxy JSON fallback
  DoomKit/Sources/DoomServices/TextAcquisition/SystemTextAcquirer.swift # restoreSkipped propagation
  DoomKit/Tests/DoomCoreTests/SelectionValidatorTests.swift         # HARDEN-01 regression test
  DoomKit/Tests/DoomFeaturesTests/AssistantControllerTests.swift   # HARDEN-02 regression test
  DoomKit/Tests/DoomFeaturesTests/PanelControllerTests.swift       # HARDEN-03 regression test
  DoomKit/Tests/DoomServicesTests/GeminiClientTests.swift          # HARDEN-04, HARDEN-05 regression tests
  README.md                                                        # Comprehensive finalized documentation
  docs/PHASE_TRACKER.md                                            # Milestones M00-M12 marked COMPLETE
  docs/VERIFICATION_LOG.md                                         # Verification log updated through M12

New Handover Reports:
  docs/FINAL_ACCEPTANCE_REPORT.md                                  # Acceptance report (M10)
  docs/POST_ACCEPTANCE_HARDENING.md                                # Hardening report (M11)
  docs/FINAL_HANDOVER.md                                           # Handover report (M12)
```

---

## 11. Recommended Next Steps

1. **Daily Personal Use**: Launch `~/Applications/DOOM.app` and add DOOM to macOS Login Items (**System Settings > General > Login Items**) if auto-launch at startup is desired.
2. **Paid API Key Consideration**: If the free-tier Gemini rate limits (HTTP 429) prove restrictive during daily heavy use, attaching a billing method in Google Cloud console removes the rate caps.
3. **Periodic Maintenance**: Re-run `./scripts/verify.sh` after any major macOS software update to verify compatibility.

---

### Conclusion
DOOM is feature-complete, architecturally clean, data-race safe, and fully hardened. Milestone M12 is **COMPLETE**.
