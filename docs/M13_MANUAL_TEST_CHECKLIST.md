# DOOM — M13 Real-World Reliability & User Experience Manual Test Checklist

| Document Metadata | |
| :--- | :--- |
| **Product** | DOOM (Native macOS AI Assistant) |
| **Target Application** | `~/Applications/DOOM.app` (`com.tace.doom`, Release arm64) |
| **Milestone** | M13 — Real-World Reliability & User Experience Testing |
| **Target Host** | MacBook Air (Mac17,3, Apple M5, 16 GB), macOS 27.0.1 (26A434) |
| **Status** | PENDING PHYSICAL MAC EXECUTION (Automated test suite 100% PASS) |
| **Creation Date** | 2026-10-26 |

---

## 1. Overview & Execution Rules

This checklist documents the exact real-world verification procedures to be executed on a physical Mac running macOS 27+. All automated unit tests, static code audits, and build validations have passed with zero warnings.

> [!IMPORTANT]
> **Real-World Test Rule**:
> Do not mark any test in this document as `PASS` or `FAIL` until it is physically executed on hardware with an operator observing real behavior. All items are initialized to `[PENDING]`.

---

## 2. Shortcut Reference Table

Verify shortcut definitions before executing tests:

| Action | Documented & Implemented Shortcut | Mechanism |
|---|---|---|
| **Activate on Selected Text** | `Fn + Control + Option` | Held simultaneously and released within 2.0s via `ChordRecognizer` |
| **Toggle / Reveal Panel** | `Control + Shift + H` | Global Carbon hotkey via `RegisterEventHotKey` |
| **Hide / Dismiss Panel** | `Escape` or `Command + W` | Standard AppKit key equivalents via `DoomPanel` |
| **Open Settings** | Menu Bar -> `Open DOOM…` or `⌘,` | Standard SwiftUI window activation |
| **Quit DOOM** | Menu Bar -> `Quit DOOM` or `⌘Q` | Clean termination via `NSApp.terminate(nil)` |

---

## 3. Manual Test Checklist

### Category 1: First Launch & Permission Onboarding

| ID | Test Case | Procedure | Expected Outcome | Status | Actual Result |
|---|---|---|---|---|---|
| **M13-PERM-01** | First launch without permissions | Launch `open ~/Applications/DOOM.app` on a clean account. | Main window opens centered with title "DOOM", version displayed, and status indicator showing "Setup needed". Menu-bar hexagon icon appears. | `[PENDING]` | |
| **M13-PERM-02** | Accessibility permission grant | Click "Open Accessibility Settings" in DOOM. Enable DOOM in System Settings > Privacy & Security > Accessibility. Switch back to DOOM. | DOOM detects granted permission upon `applicationDidBecomeActive`. Accessibility indicator updates from missing to granted without app restart. | `[PENDING]` | |
| **M13-PERM-03** | Privacy notice acknowledgment | In DOOM Settings, click "Review Privacy Notice". Review the 6 privacy guarantees, then click "I Understand". | Sheet dismisses. Privacy reviewed flag updates to acknowledged. Status reflects review completion. | `[PENDING]` | |
| **M13-PERM-04** | API key setup & Keychain validation | Enter a valid Gemini API key (`AIzaSy...`) in Settings and click "Save Key". | Key is securely validated and committed to Keychain (`com.tace.doom` / `gemini-api-key`). Status changes to "Ready". "Test Connection" button becomes active. | `[PENDING]` | |

---

### Category 2: Activation Shortcut & Text Acquisition Workflows

| ID | Test Case | Procedure | Expected Outcome | Status | Actual Result |
|---|---|---|---|---|---|
| **M13-TEXT-01** | Activation chord detection (`Fn + Control + Option`) | With an application open, press and hold `Fn`, `Control`, and `Option` simultaneously, then release within 2 seconds. | Shortcut triggers DOOM assistant flow. If text was selected, assistant enters acquisition/request phase. | `[PENDING]` | |
| **M13-TEXT-02** | TextEdit native selection acquisition | Open TextEdit, type 2–3 paragraphs of text, highlight one paragraph. Trigger `Fn + Control + Option`. | Text is read directly via Accessibility AXUIElement (`AXSelectedText`). Floating panel appears top-right with app name "TextEdit", character count, and progress indicator. System pasteboard is NOT modified. | `[PENDING]` | |
| **M13-TEXT-03** | Google Chrome web page selection | Open Google Chrome, highlight a sentence on a web page. Trigger `Fn + Control + Option`. | Text is acquired via AXWebArea without error. Request is dispatched to Gemini. | `[PENDING]` | |
| **M13-TEXT-04** | Web browser textarea selection | In Safari or Chrome, enter text into a textarea or editable web form. Highlight text and trigger `Fn + Control + Option`. | Selected text from form field is acquired accurately. | `[PENDING]` | |
| **M13-TEXT-05** | Password field security guard (`SEC-09`) | Highlight text in a secure password input field (or system password prompt). Trigger activation chord. | DOOM immediately rejects acquisition with a secure-field notification. DOOM NEVER attempts clipboard fallback on password fields. | `[PENDING]` | |
| **M13-TEXT-06** | Opt-in clipboard fallback | In DOOM Settings, check "Enable copy fallback". Select text in an application that does not expose AX text selection. Trigger chord. | DOOM performs simulated copy (`⌘C`), acquires text, dispatches request, and automatically restores previous clipboard contents. | `[PENDING]` | |
| **M13-TEXT-07** | Clipboard restore user-protection guard | While clipboard fallback is acquiring, manually copy something else before restore executes. | DOOM detects changeCount increment and skips clipboard restore, preserving the user's newer copied item. | `[PENDING]` | |

---

### Category 3: Privacy Mode & Menu-Bar Status Workflows

| ID | Test Case | Procedure | Expected Outcome | Status | Actual Result |
|---|---|---|---|---|---|
| **M13-PRIV-01** | Privacy Mode toggle activation | Open DOOM Settings. Scroll to Privacy section. Toggle "Privacy Mode" to ON. | Exclusion property (`sharingType = .none`) is applied to overlay window. Overlay remains visible locally by default. Honest status badge indicates exclusion requested and unverified for full screen. | `[PENDING]` | |
| **M13-PRIV-02** | Local overlay usability with Privacy Mode ON | With Privacy Mode ON, highlight text in TextEdit and press `Fn + Control + Option`. | Panel appears on screen normally, shows acquiring/requesting spinner, and displays Gemini response. Local interaction is fully functional. | `[PENDING]` | |
| **M13-PRIV-03** | Shortcut operation in Privacy Mode | With Privacy Mode ON, press `Control + Shift + H` to hide, then press `Control + Shift + H` to show. Dismiss via `Escape` or `⌘W`. | Global shortcut toggles panel smoothly. Dismiss shortcuts work identically to Privacy Mode OFF. Shortcut is NEVER blocked. | `[PENDING]` | |
| **M13-PRIV-04** | Menu bar Show/Hide in Privacy Mode | Open DOOM menu bar extra while Privacy Mode is ON. Click "Hide Panel" / "Show Panel". | Menu item is enabled and interactively toggles overlay visibility without restriction. | `[PENDING]` | |
| **M13-PRIV-05** | In-flight request preservation across Privacy Mode toggle | Trigger request via chord. While spinner is active, toggle Privacy Mode in Settings. | In-flight request is preserved and continues uninterrupted. Completed response renders in overlay. | `[PENDING]` | |
| **M13-PRIV-06** | Optional opt-in local hide fallback | In Settings with Privacy Mode ON, enable "Hide overlay locally while sharing". Trigger request. | Panel hides locally (`orderOut`). Menu bar shows "Response ready" upon completion. Panel does not appear until explicitly re-shown. | `[PENDING]` | |
| **M13-PRIV-07** | Sharing method context selector | In Settings with Privacy Mode ON, switch sharing method between "Entire screen", "A single window", and "Not sure". | Status text dynamically updates to reflect honest evidence: "Entire screen" / "Not sure" state exclusion is unverified; "A single window" states compositor-level isolation. Never shows false "Protected" claim. | `[PENDING]` | |

---

### Category 4: Panel Interaction, Lifecycles & Gestures

| ID | Test Case | Procedure | Expected Outcome | Status | Actual Result |
|---|---|---|---|---|---|
| **M13-PANEL-01** | Escape key dismiss | With response panel open and active, press `Escape`. | Panel hides cleanly (`cancelOperation`). | `[PENDING]` | |
| **M13-PANEL-02** | Command + W dismiss | With panel focused, press `Command + W`. | Panel hides cleanly without terminating the application. | `[PENDING]` | |
| **M13-PANEL-03** | Close button dismiss | Click the close button (top corner) on the panel. | Panel hides immediately. | `[PENDING]` | |
| **M13-PANEL-04** | Response copy action | Click the "Copy" button below the response text. | Complete response is copied to system pasteboard. Brief "Copied" feedback is displayed. | `[PENDING]` | |
| **M13-PANEL-05** | Drag repositioning | Click and drag the panel header to a new screen location. Press `Control + Shift + H` twice. | Panel reappears at the user-dragged position, preserving user origin. | `[PENDING]` | |

---

### Category 5: Gemini Connectivity, Quota & Error Handling

| ID | Test Case | Procedure | Expected Outcome | Status | Actual Result |
|---|---|---|---|---|---|
| **M13-GEMINI-01** | Settings Test Connection | In Settings, click "Test Connection" with valid key. | Progress indicator shows; connection completes within 2–5 seconds with "Connection successful (Xs)". | `[PENDING]` | |
| **M13-GEMINI-02** | Invalid API Key feedback | Save an invalid key `AIzaSyInvalidKeyTest1234567890123456`. Click "Test Connection". | Clear, sanitized error message is displayed (e.g. "API key not valid"). No secrets or key fragments leak into logs. | `[PENDING]` | |
| **M13-GEMINI-03** | Network Offline / Timeout | Disconnect Wi-Fi and trigger activation on selected text. | After timeout, panel displays friendly error message: "Unable to reach Gemini. Check your internet connection." with a "Retry" button. No app crash. | `[PENDING]` | |
| **M13-GEMINI-04** | Rapid duplicate activation guard | Rapidly spam `Fn + Control + Option` 4–5 times in quick succession. | Activation debouncing (250ms) suppresses duplicates. Exactly one request is sent to Gemini. | `[PENDING]` | |

---

### Category 6: Accessibility (a11y), VoiceOver & Motion

| ID | Test Case | Procedure | Expected Outcome | Status | Actual Result |
|---|---|---|---|---|---|
| **M13-A11Y-01** | VoiceOver navigation | Enable VoiceOver (`⌘F5`). Navigate through DOOM Settings and Response Panel. | All elements (Status, Toggles, Buttons, Text fields, Markdown response) have descriptive accessibility labels and readable values. | `[PENDING]` | |
| **M13-A11Y-02** | Reduce Motion preference | In System Settings > Accessibility > Display, enable "Reduce Motion". Open/close panel and trigger requests. | Animations and spinners respect reduced motion guidelines without jumpy visual artifacts. | `[PENDING]` | |
| **M13-A11Y-03** | Dark Mode contrast & appearance | Switch macOS between Dark and Light mode. | Panel enforces dark aqua HUD styling with crisp, readable high-contrast typography in all system appearances. | `[PENDING]` | |

---

### Category 7: Phase 6 WebRTC Screen-Sharing Live Capture Verification Matrix

> [!IMPORTANT]
> **Manual WebRTC Verification Mandate**:
> Automated tests and property validation do NOT establish capture behavior in third-party WebRTC software.
> This matrix must be executed manually on a live Mac during an actual test call (e.g. Google Meet, Zoom, or Microsoft Teams) with a remote observer or second device.
>
> **Record for each test run**:
> - **macOS Version**: e.g., macOS 15.1 / macOS 27.0.1
> - **DOOM Build**: `~/Applications/DOOM.app` (commit hash / build timestamp)
> - **Browser / Conferencing App**: e.g., Google Chrome 131.0.6778.86, Zoom 6.2.5
> - **Capture Mechanism**: ScreenCaptureKit display vs window picker
> - **Observed Result**:
>   - (i) Local Screen-Share Preview
>   - (ii) Remote Receiver / Participant View
> - **Classification**: `EXCLUDED` (overlay not seen) / `INCLUDED` (overlay visible) / `INCONCLUSIVE` / `NOT YET RUN`

| Matrix ID | Privacy Mode | Sharing Method | Overlay State | Procedure & Trigger | Expected Outcome & UI Honesty | Status | Remote Result |
|---|---|---|---|---|---|---|---|
| **RTC-01** | **OFF** | Entire screen | Visible locally | Start full-screen share in WebRTC call. Trigger DOOM overlay via chord. | Overlay is INCLUDED in screen share. UI status indicates Privacy Mode is off. | `[NOT YET RUN]` | |
| **RTC-02** | **OFF** | Entire screen | Hidden locally | Press `Control + Shift + H` to hide overlay. | Overlay is EXCLUDED while hidden. | `[NOT YET RUN]` | |
| **RTC-03** | **OFF** | Entire screen | Re-shown locally | Press `Control + Shift + H` to re-show overlay. | Overlay is INCLUDED again in screen share. | `[NOT YET RUN]` | |
| **RTC-04** | **OFF** | Entire screen | Dismissed | Press `Escape` or `⌘W`. | Overlay is EXCLUDED immediately upon dismiss. | `[NOT YET RUN]` | |
| **RTC-05** | **OFF** | Single window (other app) | Visible locally | Share TextEdit window. Trigger DOOM overlay floating on top. | Overlay is EXCLUDED from shared window stream (compositor isolation). | `[NOT YET RUN]` | |
| **RTC-06** | **OFF** | Single window (active app) | Overlapping | Share browser window. Position DOOM overlay directly overlapping shared window content. | Overlay is EXCLUDED from window stream; underlying browser content is captured unobscured. | `[NOT YET RUN]` | |
| **RTC-07** | **OFF** | Browser tab sharing | Visible locally | In Chrome, share single tab. Keep DOOM overlay open on top. | Overlay is EXCLUDED from tab stream. | `[NOT YET RUN]` | |
| **RTC-08** | **OFF** | Separate display | Visible on Disp 2 | Share Display 1. Position DOOM overlay on Display 2 (or Sidecar iPad). | Overlay is EXCLUDED from Display 1 stream. | `[NOT YET RUN]` | |
| **RTC-09** | **ON** | Entire screen | Visible locally | Enable Privacy Mode. Select "Entire screen". Start full-screen share. Trigger DOOM overlay. | Overlay remains visible locally. In remote stream: observe whether specific WebRTC app honors `sharingType = .none`. UI status explicitly states unverified for third-party WebRTC. | `[NOT YET RUN]` | |
| **RTC-10** | **ON** | Entire screen | Hidden locally | Press `Control + Shift + H` while Privacy Mode is ON. | Overlay hides cleanly (`orderOut`). Completely EXCLUDED from share. | `[NOT YET RUN]` | |
| **RTC-11** | **ON** | Entire screen | Re-shown locally | Press `Control + Shift + H` again to re-show. | Overlay re-appears locally. Remote stream observation matches RTC-09. | `[NOT YET RUN]` | |
| **RTC-12** | **ON** | Entire screen | Dismissed | Press `Escape` or `⌘W`. | Overlay dismisses immediately locally and remotely. | `[NOT YET RUN]` | |
| **RTC-13** | **ON** | Entire screen | Activation chord | Trigger `Fn + Control + Option` while sharing. | Overlay activates, shows acquiring/requesting spinner, and renders response locally. | `[NOT YET RUN]` | |
| **RTC-14** | **ON** | Single window (other app) | Visible locally | Enable Privacy Mode. Select "A single window". Share TextEdit window. Open DOOM overlay. | Overlay is EXCLUDED from shared window stream at compositor level. UI badge indicates compositor isolation. | `[NOT YET RUN]` | |
| **RTC-15** | **ON** | Single window (active app) | Overlapping | Share browser window. Position DOOM overlay directly overlapping shared window content. | Overlay is EXCLUDED from window capture; underlying content captured clean. | `[NOT YET RUN]` | |
| **RTC-16** | **ON** | Browser tab sharing | Visible locally | In Chrome, share a tab. Use DOOM overlay on top of browser. | Overlay is EXCLUDED from tab stream. | `[NOT YET RUN]` | |
| **RTC-17** | **ON** | Separate display | Visible on Disp 2 | Share Display 1. Place DOOM overlay on Display 2. | Overlay is EXCLUDED from Display 1 capture. | `[NOT YET RUN]` | |
| **RTC-18** | **ON** | Opt-in local hide fallback | Hidden while sharing | Enable "Hide overlay locally while sharing". Trigger request. | Overlay remains hidden locally during share. Menu bar alerts when response is ready. EXCLUDED from all captures. | `[NOT YET RUN]` | |
| **RTC-19** | **ON** | In-flight toggle | In-flight request | Trigger request. Toggle Privacy Mode ON while request is in flight. | Request completes without error. Response remains available in memory and renders upon display. | `[NOT YET RUN]` | |
| **RTC-20** | **ON** | UI honesty check | Any sharing mode | Review UI text across all Privacy Mode states. | UI NEVER shows "Protected", "Secure", "Invisible", or "Hidden from screen share" without verified evidence for the specific capture path. | `[NOT YET RUN]` | |

---

## 4. Section 9: Google Meet Manual Acceptance Test Protocol

This test protocol is executed manually on physical hardware by the operator in Google Meet running in Google Chrome.

### Execution Procedure:
1. **Launch DOOM**: Launch `/Users/immanuelmelbin/Applications/DOOM.app`. Confirm build identifier displays: `Version 0.1.0 (Build 1, commit f8ec5da)`.
2. **Enable Privacy Mode**: In DOOM Settings, toggle **Privacy Mode** to ON.
3. **Keep Overlay Visible Locally**: Keep "Hide overlay locally while sharing" disabled so the overlay remains on-screen and interactive.
4. **Open Google Meet in Chrome**: Join a meeting in Google Chrome 156.0.8078.47.
5. **Share Entire Screen**: Choose "Entire screen" in the Chrome screen picker.
6. **Trigger DOOM**: Press `Fn + Control + Option` on selected text to display a response.
7. **Check Received Screen**: Inspect the remote participant's view and Chrome's presentation preview tile.
8. **Record Result**: Record whether the overlay is `INCLUDED` or `EXCLUDED`.
9. **Test Explicit Fallback**:
   - (a) Enable "Hide overlay locally while sharing".
   - (b) Trigger activation (`Fn + Control + Option`); verify request processes while hidden.
   - (c) Verify menu-bar item shows "Privacy Mode: Response ready" when completed.
   - (d) Press `Control + Shift + H` to deliberately reveal the response; check remote participant view.
   - (e) Press `Control + Shift + H` again to hide; check remote participant view.

### Acceptance Test Log Matrix:

| Run ID | macOS Build | DOOM Build ID | Chrome Version | Sharing Mode | Privacy Mode | Fallback Mode | Overlay Visibility | Observed Result | App Status Text Displayed | Matches Reality? | Operator Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **M13-MEET-01** | macOS 27.0.1 (26A434) | 0.1.0 (Build 1, f8ec5da) | 156.0.8078.47 | Entire screen | ON | None | Visible locally | `[PENDING MANUAL VERIFICATION]` | "Exclusion requested, but not effective for entire-screen sharing in Google Meet/Chrome on macOS 27. DOOM may appear on your shared screen." | PENDING | `NOT YET RUN` |
| **M13-MEET-02** | macOS 27.0.1 (26A434) | 0.1.0 (Build 1, f8ec5da) | 156.0.8078.47 | Entire screen | ON | localHideWhileSharing | Hidden locally | `[PENDING MANUAL VERIFICATION]` | "Explicit opt-in. Keeps the overlay hidden off-screen during active sharing..." | PENDING | `NOT YET RUN` |
| **M13-MEET-03** | macOS 27.0.1 (26A434) | 0.1.0 (Build 1, f8ec5da) | 156.0.8078.47 | Entire screen | ON | localHideWhileSharing | Deliberate reveal (⌃⇧H) | `[PENDING MANUAL VERIFICATION]` | Preserved response displayed on demand | PENDING | `NOT YET RUN` |
| **M13-MEET-04** | macOS 27.0.1 (26A434) | 0.1.0 (Build 1, f8ec5da) | 156.0.8078.47 | Entire screen | ON | localHideWhileSharing | Re-hidden (⌃⇧H) | `[PENDING MANUAL VERIFICATION]` | Response preserved in memory; overlay hidden | PENDING | `NOT YET RUN` |
| **M13-MEET-05** | macOS 27.0.1 (26A434) | 0.1.0 (Build 1, f8ec5da) | 156.0.8078.47 | Single window | ON | None | Visible locally | `[PENDING MANUAL VERIFICATION]` | "Exclusion requested; not confirmed for A single window. It may appear on your shared screen." | PENDING | `NOT YET RUN` |
| **M13-MEET-06** | macOS 27.0.1 (26A434) | 0.1.0 (Build 1, f8ec5da) | 156.0.8078.47 | Separate display | ON | None | Visible on Disp 2 | `[PENDING MANUAL VERIFICATION]` | "Exclusion requested; not confirmed for Separate display. It may appear on your shared screen." | PENDING | `NOT YET RUN` |

### Recommended Informational Alternatives:
If entire-screen exclusion is not achievable:
1. **Share a Single Window**: Share only the specific app window (e.g. TextEdit or browser) rather than the entire screen. WindowServer compositor isolates the shared window and omits DOOM.
2. **Share a Separate Display**: Place DOOM on an unshared secondary display or Sidecar iPad.

---

## 5. Execution Summary

| Metric | Target | Actual |
|---|---|---|
| **Total Test Cases** | 54 | 54 (28 Functional + 20 WebRTC Matrix + 6 Section 9 Acceptance) |
| **Section 9 Acceptance Status** | Pending Manual Verification | **PENDING MANUAL VERIFICATION** |
| **Automated Unit Tests** | 217 / 217 | **217 PASS (100%)** |
| **Architecture Violations** | 0 | **0 PASS** |
| **Secret Leaks** | 0 | **0 PASS** |

