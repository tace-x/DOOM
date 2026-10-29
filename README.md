# DOOM — Native macOS AI Assistant

DOOM is a high-performance, privacy-conscious native macOS AI assistant built specifically for personal daily use. Operating globally across macOS applications, DOOM allows you to highlight text anywhere on your Mac, trigger an assistant chord, and receive fast, contextual AI explanations and summaries in a non-intrusive floating panel.

> **Notice:** DOOM is an independent personal project and is not affiliated with, endorsed by, or connected to Marvel, Disney, id Software, Bethesda, or any of their affiliates or trademarks.

---

## 1. Project Overview

DOOM is written from scratch in modern Swift 6 with AppKit and SwiftUI. It operates as a lightweight menu bar utility with a floating assistant overlay panel. Unlike browser wrappers or bloated Electron apps, DOOM uses zero web views, starts instantly, executes with strict Swift 6 data-race safety, and consumes minimal system resources.

---

## 2. Feature List (Verified Functionality)

All features below are verified by automated tests and physical device evaluation:

- **Global Text Acquisition via Accessibility**: Directly extracts highlighted text from native macOS apps (TextEdit, Safari, Notes, Xcode) and web browsers (Chrome) using `AXUIElementCopyAttributeValue` without modifying the system clipboard.
- **Opt-in Clipboard Fallback**: Fallback acquisition via synthetic copy (`⌘C`) and pasteboard inspection is strictly opt-in (disabled by default). If enabled, it aborts immediately on password fields, transient password manager items, and concealed types, and restores the original clipboard content.
- **Fast AI Reasoning via Gemini**: Connects directly to Google Gemini models (default: `gemini-2.5-flash`) over TLS 1.3 with zero intermediate servers.
- **Floating Metallic HUD Panel**: Custom non-activating `NSPanel` (`.floating` window level) that displays AI responses without stealing keyboard focus or changing frontmost application state.
- **Rich Markdown Formatting**: Native SwiftUI rendering for bold, italic, inline code blocks, lists, and headings, with clickable external links stripped and underlined for safety.
- **Full Keyboard Control**:
  - Double-tap `fn` (Fn chord) to ask about the current selection.
  - `Control+Shift+H` global hotkey to toggle panel visibility at any time without cancelling active requests.
  - `Escape` to cancel in-flight requests or dismiss the panel.
  - `⌘W` to close the panel.
  - `⌘C` to copy the response to the clipboard.
- **Single-Flight & Lifecycle Discipline**: Duplicate activations during an active query are rejected. In-flight requests survive panel toggling. Application termination during acquisition gracefully waits for clipboard restoration before exiting.
- **Local Packaging & Uninstallation**: Repeatable script-driven installation to `~/Applications/DOOM.app` and safe uninstaller with dry-run support.

---

## 3. Architecture Overview

DOOM follows a strict three-layer architecture with unidirectional dependencies and strict compile-time boundary enforcement:

```
┌────────────────────────────────────────────────────────┐
│                        DOOM App                        │
│          (AppDelegate, Lifecycle, App Structure)       │
└───────────────────────────┬────────────────────────────┘
                            │ imports
┌───────────────────────────▼────────────────────────────┐
│                    DoomFeatures                        │
│   (AssistantController, PanelController, SwiftUI Views)│
└───────────────────────────┬────────────────────────────┘
                            │ imports
┌───────────────────────────▼────────────────────────────┐
│                    DoomServices                        │
│(GeminiClient, Keychain, TextAcquisition, ShortcutMonitor)│
└───────────────────────────┬────────────────────────────┘
                            │ imports
┌───────────────────────────▼────────────────────────────┐
│                      DoomCore                          │
│     (Domain Models, Protocols, Policies, Contracts)    │
└────────────────────────────────────────────────────────┘
```

- **`DOOM/`**: Application entry point, `NSApplicationDelegate`, menu-bar item lifecycle, and top-level event dispatch.
- **`DoomKit/Sources/DoomFeatures/`**: State presentation (`MainWindowModel`, `PanelController`, `AssistantController`), custom `DoomPanel`, and SwiftUI presentation views (`PanelView`, `MainWindowView`).
- **`DoomKit/Sources/DoomServices/`**: System infrastructure implementations (`GeminiClient`, `KeychainCredentialStore`, `SystemTextAcquirer`, `AccessibilitySelectionReader`, `ClipboardFallbackHandler`, `SystemShortcutMonitor`, `KeyCodeResolver`).
- **`DoomKit/Sources/DoomCore/`**: Core contracts, value types (`SelectedText`, `APIKey`, `ModelID`), validation policies (`SelectionValidator`), error representations, and launch configuration (`AppContext`).

---

## 4. Prerequisites

- **Operating System:** macOS 27.0 or later (verified on macOS 27.0.1, build `26A434`).
- **Hardware Architecture:** Apple Silicon (`arm64`, M-series Mac).
- **Development Toolchain:** Xcode 16.0 or later (verified on Xcode 27.1, Swift 6.4).
- **Signing Identity:** Local personal-use signing (`Sign to Run Locally` / `-`) or free Apple Development certificate. No paid developer membership is required.
- **API Key:** A valid Google Gemini API key (from Google AI Studio).

---

## 5. Build and Launch Instructions

### Building from Source

Build Debug configuration:
```bash
./scripts/build.sh debug
```

Build Release configuration with all warnings treated as errors:
```bash
./scripts/build.sh release SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

### Installing Locally

To build, verify, stage, and install DOOM into your user Applications directory (`~/Applications/DOOM.app`):
```bash
./scripts/install.sh
```

`install.sh` performs:
1. Release compilation with `-warnings-as-errors`.
2. Bundle structure verification (proper `Info.plist`, entitlements, architecture).
3. Graceful termination of any active DOOM instance.
4. Backup preservation of any existing install.
5. Installation into `~/Applications/DOOM.app`.
6. Code signature verification and headless smoke testing.

### Launching the Application

Launch DOOM from the terminal:
```bash
open ~/Applications/DOOM.app
```
Or launch **DOOM** from Spotlight or Finder in `~/Applications`.

### Headless CLI Flags
- Smoke test: `~/Applications/DOOM.app/Contents/MacOS/DOOM --doom-smoke-test`
- Diagnostics: `~/Applications/DOOM.app/Contents/MacOS/DOOM --doom-diagnose`

---

## 6. Secure API Key Configuration

DOOM uses Apple Data Protection Keychain (`kSecUseDataProtectionKeychain`) to store your Google Gemini API key. Keys are never logged, printed, or exported to disk.

### Setup Workflow:
1. Launch DOOM.
2. If setup is needed, the main Settings window opens automatically. (You can also open it via the menu bar status icon > **Settings…** or `⌘,`).
3. In the **Gemini API Key** section:
   - Enter your Gemini API key (starts with `AIzaSy...`, 39 characters).
   - Click **Save Key**. The key is stored securely in your macOS Keychain under service `com.tace.doom` and account `gemini-api-key`.
4. Click **Test Connection** to execute an end-to-end handshake with Gemini. Upon success, the UI displays `Connection verified` with round-trip latency.
5. To remove your key at any time, click **Delete Key**.

---

## 7. Required macOS Permissions

DOOM requires one macOS permission:

### Accessibility (`AXIsProcessTrusted`)
- **Purpose:** Allows DOOM to inspect the accessibility hierarchy and copy selected text from the active application using `AXUIElementCopyAttributeValue`.
- **How to Grant:**
  1. Open **System Settings > Privacy & Security > Accessibility**.
  2. Locate **DOOM** in the list and toggle the switch to **ON**.
  3. If prompted, restart DOOM.
- **Permission Recovery:** If DOOM is recompiled or re-signed, macOS TCC may invalidate the trust token. If DOOM reports `Accessibility permission required`, toggle DOOM OFF and ON in System Settings, or reset via terminal:
  ```bash
  tccutil reset Accessibility com.tace.doom
  ```

### Screen Recording
- **Status: NOT REQUIRED AND NOT USED.**
- Screen capture APIs (`ScreenCaptureKit`, `CGWindowListCreateImage`, `AVFoundation`) are strictly forbidden by architectural rules (`R-NO-SCREENCAPTUREKIT`) and verified in automated reviews.

---

## 8. Keyboard Shortcuts

| Shortcut | Scope | Function |
|---|---|---|
| **Double-tap `fn`** (Fn chord) | Global | Asks DOOM about currently highlighted text. |
| **`Control+Shift+H`** | Global (Carbon) | Toggles the assistant panel visibility without cancelling active queries. |
| **`Escape`** | Panel Key | Cancels active in-flight request, or closes/hides the panel if idle/finished. |
| **`⌘W`** | Panel Key | Closes/hides the assistant panel. |
| **`⌘C`** | Panel Key | Copies the displayed AI response to the clipboard. |
| **`⌘,`** | Menu | Opens the DOOM Settings / Main Window. |
| **`⌘Q`** | Menu | Quits DOOM cleanly (defers exit if clipboard restore is in flight). |

---

## 9. Testing and Verification

DOOM includes an extensive automated verification pipeline.

### Run Full Verification Suite
```bash
./scripts/verify.sh
```
`verify.sh` executes the entire quality gate:
1. Xcode developer directory validation.
2. Secret scan (`scripts/check-secrets.sh`) checking all files for credentials.
3. Architecture review checks (`scripts/review-checks.sh`) enforcing 21 rules (layer boundaries, zero file writes, no hardcoded bundle IDs, no banned APIs).
4. Unit tests with warnings as errors:
   - `DoomCoreTests` (37 tests)
   - `DoomServicesTests` (87 tests)
   - `DoomFeaturesTests` (61 tests)
   - Total: **185 tests in 24 suites (100% pass, 0 failures, 0 warnings)**.
5. Debug build and bundle verification.
6. Headless smoke test of Debug build.
7. Release build and bundle verification.
8. Headless smoke test of Release build.
9. Shell script syntax verification (`bash -n scripts/*.sh`).
10. Uninstaller dry run verification.
11. Git hygiene check.

### Running Subsets:
- **Scan secrets:** `./scripts/check-secrets.sh`
- **Architectural review checks:** `./scripts/review-checks.sh`
- **Run all unit tests:** `swift test --package-path DoomKit -Xswiftc -warnings-as-errors`
- **Verify application bundle:** `./scripts/verify-bundle.sh release`
- **Smoke test application:** `./scripts/smoke-test.sh release`

---

## 10. Known Limitations and Troubleshooting

### Known Limitations
1. **Gemini API Quota Limits (HTTP 429)**:
   - Free-tier Gemini API keys are subject to Google request-per-minute and daily quota ceilings. When exhausted, DOOM surfaces `E-API-04` ("Gemini API quota exhausted for this account.") and blocks requests until the window resets.
2. **Password Field Protection**:
   - DOOM intentionally refuses to extract text from secure input fields (`NSSecureTextField`, password fields). This is a security feature, not a defect (`E-SEL-03`).
3. **Opt-in Clipboard Fallback**:
   - For applications that do not support Accessibility text selection (e.g. non-standard canvas editors), text acquisition fails unless **Copy Fallback** is explicitly enabled in Settings.
4. **Physical Verification Items (P1)**:
   - VoiceOver spoken audio cues (`UI-30`), Reduce Motion setting response (`UI-32`), perceptual frame smoothness (`UI-37`), and Time Profiler thread analysis (`UI-38`) require physical desktop inspection and are recorded as operational verifications.

### Troubleshooting Guide

| Issue | Cause | Resolution |
|---|---|---|
| **"Accessibility permission required"** (`E-PREREQ-01`) | macOS TCC token missing or invalidated after rebuild. | Open **System Settings > Privacy & Security > Accessibility**, remove and re-add DOOM, or run `tccutil reset Accessibility com.tace.doom`. |
| **"Gemini API key not configured"** (`E-PREREQ-03`) | API key missing from Keychain. | Open Settings (`⌘,`), enter a valid Gemini API key, and click **Save Key**. |
| **"Connection test failed (401 / 400)"** | Invalid API key or malformed key string. | Verify your key in Google AI Studio, re-enter it, and test again. |
| **"Rate limited / Quota exhausted"** (`E-API-03` / `E-API-04`) | Exceeded Gemini free-tier rate limits. | Wait for the quota cooldown window to reset, or check usage in Google Cloud console. |
| **"No text selected"** (`E-SEL-01`) | Focus element has no highlighted text. | Highlight text in the target application before activating DOOM. |
| **"Panel won't open"** | Carbon hotkey conflict. | Press `Control+Shift+H` or use the menu bar status item > **Open DOOM**. |

---

## 11. Privacy and Data-Handling Summary

DOOM is designed around strict local privacy principles:
- **Zero Disk Writes for User Data**: Selected text and AI responses are held strictly in memory during an active request and immediately cleared. They are never written to disk, caches, temp files, or logs.
- **Zero Analytics or Telemetry**: DOOM contains no tracking, telemetry, phone-home code, crash reporters, or background monitoring services.
- **Credential Isolation**: API keys reside strictly in the local macOS Keychain with Data Protection.
- **Zero Screen Capture**: DOOM never captures screens, windows, or video frames.
- **Strict Error Sanitization**: All provider error messages are scrubbed of API key patterns prior to logging or UI presentation.

---

## 12. Safe Uninstallation

To preview what would be removed:
```bash
./scripts/uninstall.sh --dry-run
```

To perform a clean uninstallation:
```bash
./scripts/uninstall.sh
```
This terminates DOOM, removes `~/Applications/DOOM.app`, deletes `com.tace.doom` preferences, and resets the Accessibility TCC permission.

---

## 13. Development Status

| Milestone | Description | Status |
|---|---|---|
| **M00** | Environment verification and work preservation | **COMPLETE** |
| **M01** | Foundation, Xcode project and signing | **COMPLETE** |
| **M02** | Menu-bar shell and panel foundation | **COMPLETE** |
| **M03** | Activation chord feasibility & shortcut skeleton | **COMPLETE** |
| **M04** | Full text acquisition & Chrome feasibility | **COMPLETE** |
| **M05** | Keychain and Gemini client integration | **COMPLETE** |
| **M06** | End-to-end assistant flow & markdown rendering | **COMPLETE** |
| **M07** | Security, privacy and permissions verification | **COMPLETE** |
| **M08** | Full test run & regression suite (180 tests) | **COMPLETE** |
| **M09** | Release build, packaging & local installation | **COMPLETE** |
| **M10** | Final acceptance audit (v1 Accepted: 130/130 P0 PASS) | **COMPLETE** |
| **M11** | Post-acceptance hardening (5 fixes, 185 tests) | **COMPLETE** |
| **M12** | Final project handover | **COMPLETE** |

DOOM v1.0 is complete, hardened, and ready for daily use.
