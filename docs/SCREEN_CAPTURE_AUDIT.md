# DOOM — Screen Capture Evidence Audit

| Attribute | Details |
|---|---|
| **Author** | Antigravity |
| **Date** | 2026-10-26 |
| **Host** | MacBook Air, Mac17,3 (Apple M5), macOS 27.0.1 (26A434) |
| **Scope** | `scripts/screen-capture-test.swift`, `scripts/webrtc-capture-investigation.swift`, `scripts/architecture-evaluation.swift`, `docs/SCREEN_CAPTURE_INVESTIGATION.md`, `docs/ARCHITECTURE_INVESTIGATION.md`, `docs/VERIFICATION_LOG.md` |
| **Verification Suite** | `swift test --package-path DoomKit -Xswiftc -warnings-as-errors` → **Exit 0**, **136 tests passed** in 20 suites, 0 failures, 0 warnings |
| **Diagnostic Script** | `scripts/scstream-capture-diagnostic.swift` → **Exit 0**, **5 directly measured tests passed** (actual `SCStream` frame delivery confirmed) |

---

## 1. Executive Summary

This audit rigorously evaluates all claims made across DOOM's screen-capture scripts and documentation. It classifies every major assertion according to the strict evidentiary hierarchy:
- **DIRECTLY TESTED**: Empirically measured via live system calls, process outputs, WindowServer inspections, or frame callbacks.
- **DOCUMENTED API BEHAVIOR**: Sourced from official Apple documentation (WWDC sessions, DTS advisories, framework headers) or browser documentation.
- **SIMULATED**: Approximated within a synthetic model or mock state variable (e.g., Swift string manipulation) rather than production code paths.
- **INFERRED**: Logically deduced from direct measurements and documented system mechanics (e.g., if `orderOut` removes a window from the WindowServer list, ScreenCaptureKit has no layer to composite).
- **NOT VERIFIED / NOT TESTED**: Claimed or printed in logs without direct runtime execution or measurement.

### Key Audit Findings
1. **No Live WebRTC Browser Stream Was Tested**:
   Neither DOOM's scripts nor previous investigations automated a browser (Chrome, Safari, Firefox), called `navigator.mediaDevices.getDisplayMedia()`, or received remote WebRTC RTP video packets. Previous logs that claimed `"Remote WebRTC Display Capture: Compositor includes panel on-screen"` were hardcoded string literals printed unconditionally in `webrtc-capture-investigation.swift`.
2. **Distinction Between Window Enumeration and Active Capture**:
   Previous tests (`webrtc-capture-investigation.swift` V-1) only queried `SCShareableContent` and constructed an `SCContentFilter(desktopIndependentWindow:)` object. They did not launch an `SCStream` to verify frame delivery. To resolve this gap, we constructed and executed `scripts/scstream-capture-diagnostic.swift`, which started real `SCStream` sessions and confirmed frame delivery.
3. **Interpreter vs. GUI Execution Context**:
   Scripts invoked via `swift <script>.swift` run as CLI tools without an active WindowServer GUI application connection. In `scripts/architecture-evaluation.swift`, `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` returned empty results (`before=false, after=false`) for script-created windows, yet the summary table previously hardcoded `PASS`. That script has now been corrected to report `NOT_MEASURED` for that test and to bind its summary table and exit status to runtime results.
4. **Production Code and In-Flight Request Preservation**:
   In `webrtc-capture-investigation.swift` V-5, in-flight request preservation was evaluated using a Swift string variable (`simulatedState = "succeeded(...)"`), rather than testing `PanelController` or `GeminiClient`. True production in-flight request preservation is tested and confirmed by `PanelControllerTests.swift` in the unit test suite.
5. **No Feasible "Capture-Exclusion" API for Visible Windows**:
   Empirical testing confirmed that `NSWindow.sharingType = .none` does not prevent a visible window from appearing in ScreenCaptureKit queries. As confirmed by Apple Developer Technical Support (DTS), macOS provides no public API allowing a visible window to unilaterally opt out of display capture. The supported, reliable privacy mechanisms remain:
   - User selecting single "Window" or "Tab" capture in the browser/meeting picker.
   - DOOM's `Control + Shift + H` shortcut, which orders out the window from the WindowServer compositor hierarchy.

---

## 2. Verification Suite & Diagnostic Results

### 2.1 Production Test Suite Execution
```
$ swift test --package-path DoomKit -Xswiftc -warnings-as-errors
Exit Code: 0
Execution Time: ~3.1 seconds
Warnings: 0
Failures: 0

Results by Package:
  ✔ DoomServices: 68 tests in 8 suites
  ✔ DoomFeatures: 32 tests in 6 suites
  ✔ DoomCore:     36 tests in 6 suites
  Total: 136 tests passed across 20 suites
```

### 2.2 Diagnostic Scripts Execution Summary
| Script | Command | Exit Code | Measurable Status |
|---|---|---|---|
| Harmless SCStream Diagnostic | `swift scripts/scstream-capture-diagnostic.swift` | **0** | **PASS** (5/5 direct tests passed; display & window streams delivered frames) |
| Screen Capture Basic Test | `swift scripts/screen-capture-test.swift` | **0** | **PASS** (WindowServer show/hide & screencapture verified) |
| WebRTC Investigation Script | `swift scripts/webrtc-capture-investigation.swift` | **0** | **PASS** (Corrected: labels clarify direct vs inferred vs simulated) |
| Architecture Evaluation | `swift scripts/architecture-evaluation.swift` | **0** | **PASS** (Corrected: summary table derives from variables; non-GUI context documented) |

---

## 3. Harmless Capture Diagnostic (`scstream-capture-diagnostic.swift`)

### 3.1 Objective & Methodology
To satisfy Requirement B without altering DOOM's production code or touching sensitive data, we developed `scripts/scstream-capture-diagnostic.swift`:
- **Distinctive Harmless Test Window**: Created an `NSPanel` at floating window level (`.floating`, Level 3), titled `"DOOM-SCStream-Diagnostic-Test-Window"`, with a bright yellow background (`NSColor.systemYellow`) and explanatory labels.
- **Enumeration vs. Stream Capture**: Specifically distinguished querying shareable content (`SCShareableContent`) from establishing an active frame-delivering capture pipeline (`SCStream` with `SCStreamOutput`).
- **Display Stream Capture (D-2)**: Configured an `SCStream` with `SCContentFilter(display:excludingWindows:)` targeting the primary display.
- **Window-Specific Stream Capture (D-3)**: Configured an `SCStream` with `SCContentFilter(desktopIndependentWindow:)` targeting the test window.
- **Hide & Inspect Lifecycle (D-4, D-5)**: Called `orderOut(nil)` on the test window, then queried `SCShareableContent` and `CGWindowListCopyWindowInfo` to verify removal from the capture pool. Restored the window via `orderFrontRegardless()`.
- **Measurement Metrics**: Tracked sample buffer callbacks (`CMSampleBuffer`), frame arrival timestamps, frame counts, and API error codes.

### 3.2 Actual Diagnostic Execution Output
```
============================================================
DOOM — SCStream Capture Diagnostic
macOS: Version 27.0.1 (Build 26A434)
============================================================
  [NOTE]  Test window created: 'DOOM-SCStream-Diagnostic-Test-Window' (windowNumber: 3483)
  [NOTE]  Window level: 3 (floating = 3)

============================================================
D-1: SCShareableContent Permission & Window Enumeration
------------------------------------------------------------
  [DIRECTLY TESTED]   SCShareableContent.excludingDesktopWindows succeeded — Screen Recording permission GRANTED
  [PASS]  Screen Recording permission: GRANTED
  [DIRECTLY TESTED]   Test window found in SCShareableContent on-screen list
  [DIRECTLY TESTED]     Window title: 'DOOM-SCStream-Diagnostic-Test-Window' windowID: 3483
  [DIRECTLY TESTED]     isOnScreen: true  layer: 3
  [PASS]  D-1: Test window visible in SCShareableContent

============================================================
D-2: Display-Capture SCStream — Actual Frame Delivery
------------------------------------------------------------
  [NOT TESTED]        Remote browser WebRTC stream — not tested here
  [NOTE]  Testing: SCStream with SCContentFilter(display:) delivers ≥1 video frame
  [DIRECTLY TESTED]   SCStream(display:) startCapture() succeeded — no error thrown
  [DIRECTLY TESTED]   SCStream(display:) delivered 1 video frame(s) within 3 seconds
  [DIRECTLY TESTED]     First frame received at: 2026-10-26 10:18:35 +0000
  [PASS]  D-2: Display SCStream delivered 1 frame(s) — stream is functional
  [INFERRED]          Display capture stream would include floating panel at Layer 3
  [NOT TESTED]        Pixel content of frames was not inspected to verify panel presence in pixels

============================================================
D-3: Window-Specific SCStream — Actual Frame Delivery
------------------------------------------------------------
  [NOTE]  Testing: SCStream with SCContentFilter(desktopIndependentWindow:) delivers ≥1 frame
  [NOTE]  The window targeted is the test window itself (harmless; no production DOOM panel)
  [DIRECTLY TESTED]   SCStream(desktopIndependentWindow:) startCapture() succeeded — no error thrown
  [DIRECTLY TESTED]   Filter targets: 'DOOM-SCStream-Diagnostic-Test-Window' (windowID: 3483)
  [DIRECTLY TESTED]   SCStream(desktopIndependentWindow:) delivered 1 video frame(s) within 3 seconds
  [PASS]  D-3: Window SCStream delivered 1 frame(s) — filter is functional
  [INFERRED]          desktopIndependentWindow filter isolates only the target window hierarchy
  [INFERRED]          A DOOM floating panel (Layer 3) on top of this window would NOT appear in this stream
  [NOT TESTED]        Pixel inspection to confirm panel absence was not performed

============================================================
D-4: orderOut Removes Window from SCShareableContent
------------------------------------------------------------
  [NOTE]  Hiding test window via orderOut(nil)...
  [DIRECTLY TESTED]   SCShareableContent re-queried after orderOut
  [DIRECTLY TESTED]   Test window NO LONGER in SCShareableContent.onScreenWindowsOnly after orderOut(nil)
  [PASS]  D-4: orderOut removes window from SCShareableContent — window is capture-invisible
  [INFERRED]          Any SCStream currently capturing the display would stop compositing this window
  [INFERRED]          A new SCContentFilter(display:) would not include this window
  [NOT TESTED]        An in-progress SCStream was not checked for frame-level absence of the hidden window

============================================================
D-5: CGWindowListCopyWindowInfo Confirms orderOut
------------------------------------------------------------
  [DIRECTLY TESTED]   Window absent from CGWindowListCopyWindowInfo(.optionOnScreenOnly) after orderOut
  [PASS]  D-5: CGWindowList confirms window is off-screen after orderOut
  [DIRECTLY TESTED]   Window returns to CGWindowList after orderFrontRegardless()
  [PASS]  D-5: orderFrontRegardless restores window to CGWindowList

============================================================
SUMMARY
------------------------------------------------------------
EVIDENCE CLASSIFICATION
------------------------------------------------------------
D-1  SCShareableContent permission & enumeration        DIRECTLY TESTED
D-2  Display SCStream starts & delivers frames          DIRECTLY TESTED
D-3  Window SCStream starts & delivers frames           DIRECTLY TESTED
D-4  orderOut removes window from SCShareableContent    DIRECTLY TESTED
D-5  CGWindowList confirms orderOut visibility          DIRECTLY TESTED
------------------------------------------------------------
NOT TESTED IN THIS SCRIPT
- Real browser WebRTC getDisplayMedia() stream
- Pixel content of captured frames (frame delivery confirmed, not pixel analysis)
- Third-party app capture (Zoom, Google Meet, etc.)
- In-progress SCStream frame-level response to mid-stream orderOut
------------------------------------------------------------
INFERRED (from D-2, D-3, D-4 combined + Apple SCKit documentation)
- Display SCStream would include a floating DOOM panel (Layer 3) that is on-screen
- Window SCStream (desktopIndependentWindow) would exclude floating panels
- orderOut makes the window invisible to new SCContentFilter queries
------------------------------------------------------------
[RESULT] PASS — All directly-measured tests passed
============================================================
Exit code: 0
```

---

## 4. Comprehensive Claim-by-Claim Audit

### 4.1 `scripts/screen-capture-test.swift`
| Claim / Assertion | Code Reference | Evidence Classification | Audit Finding & Verdict |
|---|---|---|---|
| Window created and ordered front | Lines 38–39 | **DIRECTLY TESTED** | `NSPanel` instantiated and `orderFrontRegardless()` called. |
| Test A: Window present in `CGWindowListCopyWindowInfo` | Lines 44–53 | **DIRECTLY TESTED** | Verified `on-screen: true` via WindowServer API. |
| Test B: `/usr/sbin/screencapture -l <id>` produces capture | Lines 56–70 | **DIRECTLY TESTED** | Verified `screencapture` process exits with code 0 and file exists on disk. |
| Test C: Window absent from `CGWindowListCopyWindowInfo` after `orderOut` | Lines 72–85 | **DIRECTLY TESTED** | Verified `on-screen: false` immediately following `orderOut(nil)`. |
| Test D: Area capture produces file of underlying desktop | Lines 87–101 | **DIRECTLY TESTED** (file) / **INFERRED** (content) | File creation tested; desktop pixel contents not inspected programmatically. |
| "Zoom, Google Meet cannot capture hidden window" | Lines 110–111 | **INFERRED** | Legitimate inference from WindowServer omission, but third-party applications were **NOT TESTED**. |
| "Apple DTS states macOS offers no public API" | Lines 114–118 | **DOCUMENTED API BEHAVIOR** | Accurately quotes published Apple developer guidance; verified that `sharingType.none` is ineffective. |

---

### 4.2 `scripts/webrtc-capture-investigation.swift`
| Claim / Assertion | Code Reference | Evidence Classification | Audit Finding & Verdict |
|---|---|---|---|
| V-1.1: Panel present in `SCShareableContent` on-screen list (Layer 3) | Lines 57–68 | **DIRECTLY TESTED** | Measured via async `SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)`. Confirmed `isOnScreen == true`, `windowLayer == 3`. |
| V-1.2: `SCContentFilter(desktopIndependentWindow:)` created | Lines 71–77 | **DIRECTLY TESTED** (API call) / **DOCUMENTED API BEHAVIOR** (Exclusion) | Filter object instantiated successfully; pixel exclusion is documented behavior; no stream was started in this script. |
| V-2: Local screenshot captures panel | Lines 84–92 | **DIRECTLY TESTED** | `/usr/sbin/screencapture -l <id>` produced file on disk. |
| V-2: "Remote WebRTC Display Capture: Compositor includes panel" | Line 93 (original) | **NOT TESTED / INFERRED** | Formerly printed as an unconditional hardcoded string. Corrected to explicitly state that no remote stream was captured. |
| V-2: "Remote WebRTC Window Capture: desktopIndependentWindow excludes panel" | Line 94 (original) | **NOT TESTED / DOCUMENTED API BEHAVIOR** | Formerly printed as an unconditional hardcoded string. Corrected to cite Apple SCKit documentation. |
| V-3: `NSWindow.sharingType = .none` does not remove panel from SCKit | Lines 102–115 | **DIRECTLY TESTED** | Set `sharingType = .none`, re-queried `SCShareableContent`; panel remained in list with `isOnScreen == true`. |
| V-4: 6-cycle show/hide toggle consistency | Lines 119–138 | **DIRECTLY TESTED** | WindowServer state strictly matched `[false, true, false, true, false, true]`. |
| V-5: "In-flight request completed while hidden, response preserved" | Lines 142–167 | **SIMULATED** | The "in-flight request" was a Swift string variable (`"requesting(...)"` -> `"succeeded(...)"`). It did not exercise `PanelController` or `GeminiClient`. Real logic is tested in `PanelControllerTests.swift`. |

---

### 4.3 `scripts/architecture-evaluation.swift`
| Claim / Assertion | Code Reference | Evidence Classification | Audit Finding & Verdict |
|---|---|---|---|
| Architecture A: `CGWindowList` on-screen check | Lines 109–166 | **NOT VERIFIED** (In script execution) | Ran in Swift CLI interpreter without a GUI session; returned `before=false, after=false`. Corrected script to mark as `NOT_MEASURED (interpreter context)`. |
| Architecture A summary table: `PASS` | Line 389 (original) | **INCORRECT / OVERSTATED** | Summary table originally hardcoded `PASS` regardless of the variable value. Fixed to use runtime status variables. |
| Architecture B: `NSXPCConnection` availability | Lines 198–199 | **DIRECTLY TESTED** | Evaluated runtime class availability via `NSClassFromString`. |
| Architecture B: Helper process window in same compositor layer | Lines 186–192 | **DOCUMENTED API BEHAVIOR** | Derived from macOS WindowServer architecture documentation; processes share the compositor layer space based on window level. |
| Architecture C: `NSStatusItem` available | Line 251 | **DIRECTLY TESTED** | `NSStatusBar.system` inspected. |
| Architecture C: `NSMenu` renders at Layer 5 (.popUpMenu) | Line 232 | **DOCUMENTED API BEHAVIOR** | Derived from AppKit documentation; menu was not popped up during CLI execution. |
| Architecture D: Single display hardware check | Lines 265–267 | **DIRECTLY TESTED** | `CGGetActiveDisplayList` returned 1 active display. |
| Architecture D: Multi-display exclusion behavior | Lines 269–278 | **DOCUMENTED API BEHAVIOR** | SCKit documentation confirms `SCContentFilter(display:)` binds to a specific display. Untested on this Mac (only 1 display exists). |
| Architecture E: `orderOut` and VSync timing | Lines 333–338 | **DOCUMENTED API BEHAVIOR** | Standard 60 Hz display refresh (~16.6ms) physics. |
| Architecture E: Private SPI list audit | Lines 340–345 | **DOCUMENTED API BEHAVIOR** | Cataloged private SPIs (`CGSSetWindowTags`, `excludedwindowIDs`). Confirmed DOOM source code uses none of them. |

---

### 4.4 `docs/SCREEN_CAPTURE_INVESTIGATION.md`
| Document Claim | Section | Evidence Classification | Audit Finding & Verdict |
|---|---|---|---|
| "WebRTC in modern browsers delegates to ScreenCaptureKit" | §1.1 | **DOCUMENTED API BEHAVIOR** | Confirmed by Chromium open-source implementation and WebRTC macOS capture backend. Not directly measured from a browser process in this repo. |
| "Floating panel is rendered directly into the WebRTC stream" | §1.1 | **INFERRED** | Directly deduced from panel's Layer 3 presence in `SCShareableContent` during whole-display capture. Live stream frames now verified by `scstream-capture-diagnostic.swift`. |
| "In single-window capture mode, panel is completely excluded" | §1.2 | **DOCUMENTED API BEHAVIOR** | Follows from `SCContentFilter(desktopIndependentWindow:)` specifications. Window stream frame delivery verified in `scstream-capture-diagnostic.swift`. |
| "100% excluded from all captures... when hidden" | §1.3 | **DIRECTLY TESTED** (local screencapture) / **INFERRED** (WebRTC) | `screencapture` and `SCShareableContent` confirmed window omission. WebRTC exclusion follows logically. |
| "Remote WebRTC Display Capture: Compositor includes panel on-screen" | §2 Log excerpt | **NOT TESTED / OVERSTATED** | Log excerpt in document quoted the hardcoded print statement from the old script. Corrected in audit. |
| V-5 in-flight response preservation | §2 Log excerpt | **SIMULATED** | Reflected string simulation in diagnostic script; actual production code is tested in unit test suite. |

---

### 4.5 `docs/ARCHITECTURE_INVESTIGATION.md`
| Document Claim | Section | Evidence Classification | Audit Finding & Verdict |
|---|---|---|---|
| Whole-display capture composites floating panel | §5-A | **INFERRED** | Supported by Layer 3 measurement in `SCShareableContent`. |
| Single-window capture strictly excludes floating panel | §5-A | **DOCUMENTED API BEHAVIOR** | Supported by `SCContentFilter(desktopIndependentWindow:)` contract. |
| Arch-A implementation cost is zero | §5-A | **DIRECTLY TESTED** | Existing DOOM codebase already implements floating panel architecture. |
| Arch-B XPC process adds complexity with zero capture benefit | §5-B | **DOCUMENTED API BEHAVIOR** | WindowServer does not filter capture based on PID or process boundary. |
| Arch-C Menu-bar UI cannot support rich Markdown / scrolling | §5-C | **DOCUMENTED API BEHAVIOR** | AppKit `NSMenuItem` view hierarchy constraints. |
| Arch-D Second display requires hardware not present on this Mac | §5-D | **DIRECTLY TESTED** | `displayCount == 1` verified. |
| Summary Table Arch-A status: "PASS" | §7 | **INCORRECT / OVERSTATED** | Script originally gave `before=false, after=false`. The script has been updated to acknowledge interpreter context and derive status dynamically. |
| "No private SPI used or needed" | §8 | **DIRECTLY TESTED** | Static codebase audit confirms 0 references to private symbols. |

---

### 4.6 `docs/VERIFICATION_LOG.md`
| Entry | Section / Topic | Evidence Classification | Audit Finding & Verdict |
|---|---|---|---|
| 2026-10-26 14:45 Entry | Screen capture test on harmless window | **DIRECTLY TESTED** | Validated `scripts/screen-capture-test.swift` results. Correctly identified `orderOut` removal and `sharingType.none` ineffectiveness. |
| 2026-10-26 15:00 Entry | WebRTC screen-capture investigation | **MIXED** (Tested & Inferred) | V-1.1, V-2 local, V-3, V-4 directly tested. V-1.2 window exclusion and V-2 remote WebRTC are documented API inferences. V-5 in-flight preservation was a string simulation in the script (though verified in unit tests). |
| 2026-10-26 15:27 Entry | Architecture evaluation | **MIXED** (Tested & Documented) | Correctly identified display count (1), XPC availability, and lack of private SPI. Arch-A was impacted by interpreter non-GUI execution context. |

---

## 5. Corrective Actions Applied to Repository

### 5.1 Updates to `scripts/webrtc-capture-investigation.swift`
1. **Replaced Misleading Print Statements**:
   - Replaced unconditional `Remote WebRTC Display Capture: Compositor includes panel on-screen` with `[NOT TESTED] Remote WebRTC Display Capture: no live browser WebRTC stream was captured` and `[INFERRED] Remote WebRTC Display stream would include panel: follows from panel's Layer 3 presence in SCShareableContent`.
   - Replaced unconditional `Remote WebRTC Window Capture: ... excludes panel` with `[NOT TESTED] Remote WebRTC Window Capture: SCContentFilter(desktopIndependentWindow:) was constructed (V-1.2) but no SCStream was started` and `[INFERRED] Per Apple SCKit documentation, desktopIndependentWindow filter isolates target window hierarchy`.
2. **Clarified Verification Results**:
   - V-2 result text changed to: `"Local screencapture file produced (directly tested). Remote WebRTC behaviour inferred from SCShareableContent layer data; no live stream captured."`
   - V-5 explicitly documented as a **string simulation** for WindowServer orderOut/orderFrontRegardless, noting that the real `PanelController` state machine is tested in `PanelControllerTests.swift`.

### 5.2 Updates to `scripts/architecture-evaluation.swift`
1. **Interpreter Context Handling**:
   - Added explanatory banner when running under CLI interpreter noting that `CGWindowListCopyWindowInfo` cannot see interpreter-created windows without a GUI session.
   - Marked Arch-A check as `NOT_MEASURED (interpreter context — see screen-capture-test.swift)`.
2. **Dynamic Summary Table**:
   - Replaced hardcoded string `"PASS"` in the comparison table with actual runtime variables (`results[0].status`).
3. **Exit Status Affected by Failures**:
   - Configured exit code to terminate non-zero (`exit(1)`) if any unexpected `FAIL` or `PARTIAL` results occur.

### 5.3 Implementation of `scripts/scstream-capture-diagnostic.swift`
- Created a standalone, harmless ScreenCaptureKit diagnostic tool using documented public APIs.
- Employs a distinctive yellow test panel (`NSPanel`, level `.floating`, title `"DOOM-SCStream-Diagnostic-Test-Window"`).
- Establishes active `SCStream` pipelines for both display and window targets, confirming actual frame delivery via `CMSampleBuffer` callbacks.
- Measures `orderOut` effect on `SCShareableContent` and `CGWindowListCopyWindowInfo`.
- Strictly exits with code 0 on success, code 1 on failure, and code 2 on permission denial.

---

## 6. Test Limitations Honestly Stated

1. **No Third-Party Browser Automation**:
   No test automated Chrome, Safari, Firefox, Edge, or a WebRTC client. While Chromium's open-source codebase on macOS 12.3+ is documented to use ScreenCaptureKit's `SCStream`, browser-specific behavior (such as custom browser-side letterboxing, cropping, or tab isolation) was not directly captured from browser memory or RTP packets.
2. **No Video Frame Pixel Inspection**:
   In `scripts/scstream-capture-diagnostic.swift`, frame arrival and timestamp callbacks (`CMSampleBuffer`) were verified. Computer-vision pixel analysis (e.g. running Core Image to verify whether yellow pixels exist in the display frame vs. window frame) was not performed to keep the diagnostic lightweight and self-contained.
3. **No Third-Party Conferencing Application Testing**:
   Applications such as Zoom, Google Meet (web/app), Microsoft Teams, and Slack were not launched or monitored. Claims regarding their capture behavior rely strictly on macOS WindowServer compositor semantics: when a window is hidden via `orderOut(nil)`, it is absent from the WindowServer list, leaving no visual buffer for any capture mechanism to composite.
4. **Single Display Environment**:
   Hardware inspection confirmed 1 active display. Multi-display exclusion mechanisms under `SCContentFilter(display:)` could not be tested with physical multi-monitor hardware on this machine.

---

## 7. Recommended Next Steps

1. **Maintain Current Architecture (Architecture A + E)**:
   - Continue using the native floating panel (`NSPanel` at `.floating` level).
   - Educate users in documentation that visible floating panels appear in whole-screen shares across all platforms.
   - Rely on `Control + Shift + H` for instant, reliable hiding (atomic WindowServer compositor exclusion within ~16ms).
   - Advise users sharing via WebRTC / meeting software to select "Window" or "Tab" sharing rather than "Entire Screen" when privacy is required.
2. **Automated CI Integration**:
   - Keep `scripts/scstream-capture-diagnostic.swift` and `scripts/webrtc-capture-investigation.swift` as developer diagnostics. Note that in headless CI environments without a display or Screen Recording permission, these scripts will exit with permission code 2.
3. **Zero Private APIs**:
   - Reject any future proposals to introduce private WindowServer SPIs (e.g., `CGSSetWindowTags`), code injection into browsers, or custom display drivers. These violate App Store guidelines, break across macOS minor updates, and introduce significant system instability.
