# macOS & WebRTC Screen-Capture Behavior Investigation & Evidence

| Metadata | |
|---|---|
| **Author** | Antigravity |
| **Date** | 2026-10-26 |
| **Target macOS** | macOS 14+ / 15+ / 27+ |
| **Test Host** | MacBook Air (Mac17,3, Apple M5, 16 GB), macOS 27.0.1 (Build 26A434) |
| **Chrome Version** | Google Chrome 156.0.8078.47 |
| **Investigation Scripts** | `scripts/scstream-capture-diagnostic.swift`, `scripts/test-cross-process-capture.swift` |

---

## 1. Executive Summary & Problem Statements

### Problem A: Overlay Visible in Google Meet Full-Screen Share
- **Observed Defect**: With Privacy Mode ON, DOOM sets the overlay's `NSWindow.sharingType = .none`. An earlier native test reported exclusion, but when sharing the entire screen in **Google Meet in Google Chrome**, the overlay still appears in the shared screen.
- **Root Cause Established with Evidence**:
  - **DOCUMENTED**: Apple developer documentation and DTS records confirm `NSWindow.SharingType.none` is a legacy 10.5 flag that controls window read-access for inter-process image extraction. Under modern ScreenCaptureKit whole-display capture (`SCContentFilter(display:)`), macOS WindowServer composites all visible on-screen windows directly into the display framebuffer. macOS provides **NO public API** for an on-screen window to opt out of full-display capture by external applications.
  - **OBSERVED (Problem A Root Cause)**: The earlier experiment was conducted *intra-process* (the test process created the test window and captured it itself). In cross-process capture—as performed by Google Chrome's WebRTC implementation (`ScreenCaptureKitDeviceMac`)—WindowServer composites the entire display framebuffer, bypassing `NSWindowSharingNone`.
  - **Ruled-Out Alternatives**:
    - Ruled out child/auxiliary windows: Inspection of the DOOM window hierarchy confirms `DoomPanel` has 0 child windows, 0 siblings, and 0 auxiliary hosting windows.
    - Ruled out recreation defect: `sharingType` was centralized and reapplied on all creation/recreation paths.
    - Ruled out stale build: The installed binary was verified via codesign and MD5 (`74b0a80c73ea3a3f55f4294f1b8be30c`).
  - **IMPOSSIBLE REQUIREMENT**: Keeping an overlay visible on-screen locally while excluding it from an external whole-display capture in Google Meet is **not achievable with documented public Apple APIs on macOS 27.0.1**.

### Problem B: Overlay Disappeared Locally and DOOM Looked Closed
- **Observed Defect**: With Privacy Mode ON, the overlay disappeared locally and DOOM looked inactive or closed.
- **Root Cause Established with Evidence**:
  - **OBSERVED (Problem B Root Cause 1)**: `handleClose()` in `PanelController.swift` previously called `assistant?.close()`, which invoked `cancel()`, resetting `assistant.phase` to `.idle` and destroying completed responses and in-flight requests when dismissed via `Escape` or `⌘W`.
  - **OBSERVED (Problem B Root Cause 2)**: `bindToAssistant` did not auto-show the overlay when `.succeeded` arrived if `isVisible == false`.
  - **OBSERVED (Problem B Root Cause 3)**: When `hideLocallyFallbackEnabled` was true, `toggle()` returned early without showing the panel, preventing `Control + Shift + H` from deliberately revealing the panel.
  - **OBSERVED (Problem B Root Cause 4)**: DOOM is configured as an accessory application (`LSUIElement = 1` in `Config/DOOM.xcconfig`) with no persistent Dock icon, so dismissing the panel left no persistent on-screen surface, creating the illusion that the application had terminated.
  - **Fix Implemented**:
    - Dismiss (`Escape`, `⌘W`, or close button) calls `hide()` and preserves the completed response in `assistant.phase` and `state`.
    - Auto-show presents completed responses when `!hideLocallyFallbackEnabled`.
    - `Control + Shift + H` (`toggle()`) deliberately reveals the panel on explicit user action even when local-hide fallback is active.
    - The menu-bar item continuously displays live, content-free status ("Working...", "Response ready", "Privacy Mode: Response ready") so DOOM is clearly active.

---

## 2. Empirical Cross-Process & ScreenCaptureKit Evidence

### Diagnostic Results Matrix (macOS 27.0.1 Build 26A434, Apple M5)

| ID | Test Action | Method / API | Observed Result | Evidence Classification |
|---|---|---|---|---|
| **E-1** | Intra-Process Display Capture | Standalone test window + `SCStream(display:)` in same process | Window omitted from intra-process stream frames | **OBSERVED (Intra-process only; invalid for Meet)** |
| **E-2** | Cross-Process Display Capture | External process capturing display containing `sharingType = .none` window | Window IS COMPOSITED into display framebuffer | **OBSERVED (Cross-process / WebRTC path)** |
| **E-3** | Single-Window Sharing | External process using `SCContentFilter(desktopIndependentWindow:)` | Target window isolated; DOOM panel 100% excluded | **OBSERVED & DOCUMENTED** |
| **E-4** | Local Hide (`orderOut`) | Window dismissed via `orderOut(nil)` | Window removed from WindowServer compositor; 100% excluded | **OBSERVED & DOCUMENTED** |
| **E-5** | Response Preservation | Dismiss via Escape, reopen via `Control + Shift + H` | Response content retained in memory and displayed | **OBSERVED** |

---

## 3. Retraction of Contradicted Claims

1. **RETRACTED**: Any claim that `NSWindow.sharingType = .none` universally excludes a visible floating window from third-party WebRTC entire-display capture on macOS 27+ is **RETRACTED**. That claim was an extrapolation from flawed intra-process experiments and is directly contradicted by real-world Google Meet testing in Google Chrome.
2. **CORRECTED**: Privacy Mode status is now governed by an evidence-based state model:
   - Entire screen on macOS 27 with Chrome/Meet = `knownNotEffective`.
   - Single window sharing = compositor-level isolation (recommended alternative).
   - "Not sure" = `requestedUnverified`.
   - Never states "Protected" without matching evidence.
