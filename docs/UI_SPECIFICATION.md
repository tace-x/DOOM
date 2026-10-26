# DOOM — UI Specification (Phase 02)

**Status:** Specification only. No UI has been implemented. Contrast ratios in §2.2 were **computed** with the WCAG 2.x relative-luminance formula; they were not measured on screen.
**Phase 01 basis:** D-21 (dark-only status window), D-22 (`DoomTheme` tokens, SF system font, no proprietary assets), C-7 (non-activating panel; no capture-exclusion promise).
**Decisions:** P2-01 (menu-bar agent, *approved*), P2-12 (panel behaviour, *approved*), P2-15 (rendering).

**Labels:**
- Requirements marked **[M]** are mandatory.
- Items in §10 are **suggestions** and are not required for acceptance.
- No Marvel names, logos, masks, character art, fonts or trade dress may be used. The identity is original: dark graphite, brushed-silver type, a restrained emerald accent.

---

## 1. Surfaces

| Surface | Kind | Purpose |
|---|---|---|
| Menu-bar item | `MenuBarExtra` (menu style), template image | Status line + actions (`PRODUCT_BEHAVIOR.md` §0.1) |
| **Panel** | `NSPanel` subclass hosting SwiftUI | Progress, response, errors |
| **Main window** | SwiftUI `Window` scene (id `main`) | Status, setup checklist, settings, privacy notice, about |
| Privacy notice sheet | Sheet on the main window | One-time acknowledgement (§4.6) |

- **[M]** No other windows, popovers, onboarding carousels, notifications or HUDs.

---

## 2. Visual system

### 2.1 Tokens (extends D-22; values in `DoomTheme`)

| Token | Value | Use |
|---|---|---|
| `bgDeep` → `bgHigh` | `#0B0D10` → `#1B2026` (vertical gradient) | Main window background (D-22) |
| `surface` → `surfaceHigh` | `#14171B` → `#1C2026` (vertical gradient) | Panel background |
| `control` | `#2A3038` | Secondary button fill, text field fill |
| `metalHigh` → `metalLow` | `#E6EAEE` → `#8A949E` | Silver gradient on the **wordmark only** (D-22) |
| `textPrimary` | `#E6EAEE` | Body and response text |
| `textSecondary` | `#9AA4AE` | Secondary labels |
| `textTertiary` | `#8A949E` | Hints, footnotes. **Replaces** the earlier idea of `#7D8790`, which fails on `bgHigh` (4.48:1) |
| `steel` | `#5C6670` | Hairline borders and dividers (decorative only) |
| `accent` | `#2FA36B` | Emerald: primary button fill, progress bar, focus ring (system accent via AccentColor), "Granted" pill |
| `accentText` | `#4CC38A` | Emerald **text** on dark surfaces (status words) |
| `warning` | `#D9A441` | Amber icon and title for user-fixable states (permissions, selection) |
| `error` | `#E5675F` | Red icon and title for service failures (network, API) |
| Spacing | 4 / 8 / 12 / 16 / 24 | D-22 scale; no other values |
| Radius | 10 (panel and window cards), 6 (buttons, fields, pills) | D-22 radius 10 plus a small radius for controls |

- **[M]** Emerald is restrained. It is used only for:
  - the primary action;
  - the progress indicator;
  - focus;
  - the "Granted/Active" status.

  It is never used for large fills or backgrounds.

### 2.2 Contrast (computed, WCAG 2.x)

| Foreground | on `bgDeep` | on `bgHigh` / `surfaceHigh` | on `control` |
|---|---|---|---|
| `textPrimary #E6EAEE` | 16.09 | 13.56 / 13.53 | 11.00 |
| `textSecondary #9AA4AE` | 7.69 | 6.47 / 6.46 | 5.26 |
| `textTertiary #8A949E` | 6.31 | 5.32 / 5.30 | 4.31 ✗ |
| `accentText #4CC38A` | 8.78 | 7.40 / 7.38 | 6.01 |
| `accent #2FA36B` (non-text, focus, progress) | 6.09 | 5.13 / 5.12 | 4.16 |
| `warning #D9A441` | 8.65 | 7.29 / 7.27 | 5.92 |
| `error #E5675F` | 5.96 | 5.02 / 5.01 | 4.08 ✗ |
| `steel #5C6670` (decorative borders) | 3.33 | 2.80 / 2.80 | 2.27 |
| Primary button: text `#0B0D10` on `accent` | — | 6.09 | — |

**[M] Contrast rules:**
- Text meets **≥ 4.5:1** against its actual background.
- `textTertiary` and `error` text are **never** placed on `control` fills.
- White text on `accent` (3.20:1) is prohibited. The primary button uses dark text `#0B0D10`.
- `steel` is decorative only. No meaning depends on it.
- With **Increase Contrast** on, borders switch to `textSecondary` and the silver gradient is replaced by solid `textPrimary`.

### 2.3 Typography (SF system font only; no bundled fonts)

| Role | Style | Notes |
|---|---|---|
| Main window wordmark "DOOM" | 28 pt, `.heavy`, tracking +6, silver gradient | Phase 01 D-22 |
| Panel wordmark | 12 pt, `.heavy`, tracking +3, silver gradient | Header only |
| Message title | `.headline` (13 pt semibold) | |
| Body, response text | `.body` (13 pt); response line spacing +2 | Selectable |
| Secondary | `.callout` / `.subheadline`, `textSecondary` | |
| Footnotes | `.footnote`, `textTertiary` | |
| Numbers (counts, version, cooldown) | `.monospacedDigit()` | |
| Inline code in responses | `.body.monospaced()` on a `control` background | |

- **[M]** Use semantic text styles so system text-size settings apply where macOS supports them.
- **[M]** No text smaller than 11 pt.

---

## 3. Panel

### 3.1 Window configuration [M]

| Property | Value |
|---|---|
| Class | `DoomPanel: NSPanel`, `canBecomeKey = true`, `canBecomeMain = false` |
| Style mask | `[.nonactivatingPanel, .titled, .fullSizeContentView]`; title hidden, titlebar transparent, standard window buttons hidden |
| Level | `.floating` |
| Collection behaviour | `[.canJoinAllSpaces, .fullScreenAuxiliary]` (shows over full-screen apps; follows Spaces) |
| `hidesOnDeactivate` | `false` |
| `becomesKeyOnlyIfNeeded` | `true` |
| `isMovableByWindowBackground` | `true` |
| `isReleasedWhenClosed` | `false` (created once, reused) |
| Sharing type | Default. **No capture-exclusion setting** (C-7; DD-07 → P2-12). |
| Content | `NSHostingView` with the SwiftUI `PanelView` |

### 3.2 Size and position [M]

- **Width** is fixed at **440 pt**.
- **Height** fits the content between a **minimum of 132 pt** and a **maximum of min(560 pt, 70 % of the screen's visible height)**. Response text scrolls inside.
- **First show of a session:** top-right of the `visibleFrame` of the screen that contains the mouse pointer, with 16 pt margins. As the height changes, the panel grows downward with its top edge anchored.
- **If the user drags the panel,** it keeps that position until DOOM quits. The position is kept in memory only. If the stored position is no longer on any screen (a display was unplugged), it reverts to the default.
- The panel never covers more than 70 % of the screen's height and never extends off-screen.

### 3.3 Layout

```
┌──────────────────────────────────────────────┐  16 pt padding
│ DOOM (wordmark)                          ×   │  header 32 pt; × = Close (cancels)
├──────────────────────────────────────────────┤  hairline (steel)
│ [state content: §3.5]                        │  scrolls if needed
│                                              │
├──────────────────────────────────────────────┤  (footer only when actions exist)
│ footnote / N-05 / N-08            [Sec] [Pri]│  buttons right-aligned, 8 pt gap
└──────────────────────────────────────────────┘
```

- Background: the `surface` gradient.
- Corner radius 10.
- Border: 1 pt `steel` at 60 % opacity, plus a 1 pt top inner highlight in white at 6 %. This is the "brushed metal" edge. It is subtle and has no texture images.
- System shadow.

### 3.4 Focus behaviour [M]

- Showing the panel uses `orderFrontRegardless()`. It **never** calls `makeKey`, and **never** activates DOOM. The source app keeps keyboard focus and its selection.
- The panel becomes key only when the user clicks inside it: to select text, click a button, or press Escape after clicking.
- After a button action that keeps the panel visible (Copy, Retry), the panel stays key until the user clicks elsewhere. This is standard behaviour.

### 3.5 State content [M]

| Flow state | Content |
|---|---|
| Empty (⌃⇧H while `idle`) | N-07, with key-cap glyphs `fn` `⌃` `⌥` (text keycaps, `control` fill). No buttons. |
| `acquiring` | Title N-01. A 2 pt indeterminate linear progress bar (`accent`) under the header. Footer: [Cancel] (secondary). |
| `requesting` | Title N-02, the secondary line N-03, and the progress bar. After 15 s, N-04 appears in `textSecondary`. Footer: [Cancel]. |
| `succeeded` | Response text (§3.6) in a scroll view. Footer: N-05 if truncated, N-08 if the restore was skipped; buttons [Copy] (secondary; label changes to N-06 for 1.5 s) and [Close] (primary). |
| `failed` | An SF Symbol icon (`exclamationmark.triangle.fill` in `warning` for permission/selection/setup errors; `xmark.octagon.fill` in `error` for network/API/generation errors), the title (`.headline`), and the message (`.body`, `textSecondary`). Footer: the catalogue actions (`PRODUCT_BEHAVIOR.md` §3). The first listed action is primary. During a cooldown, [Retry] is disabled and shows "Retry in {S} s" (monospaced digits, ticking each second). |

- **[M]** Every state has a **text** label. Icons and colour are never the only signal.

### 3.6 Response rendering [M] (P2-15)

- Inline Markdown only: `AttributedString(markdown:options:)` with `.inlineOnlyPreservingWhitespace`. That covers bold, italics, inline code and strikethrough. List markers and line breaks appear as typed.
- **Links are not interactive.** Link attributes are replaced with an underline in `accentText`. There is no click action, so no URL from model output is opened.
- If parsing fails, show plain text.
- Text is selectable (`.textSelection(.enabled)`). ⌘C copies the selected text when the panel is key.
- No images, HTML or remote content is ever loaded.

### 3.7 Keyboard (panel) [M]

| Key | When | Action |
|---|---|---|
| Escape | Panel key | `acquiring`/`requesting`: cancel + hide. Other states: close (discard) + hide |
| ⌘W | Panel key | Same as Escape |
| ⌘C | Panel key, text selected | Copy the selection |
| Tab / ⇧Tab | Full Keyboard Access on | Move between buttons |
| Space / Return | Button focused | Activate the button |
| ⌃⇧H | Global | Hide/show (never cancels) |

### 3.8 Animation

- Show and hide use a 120 ms opacity fade.
- With **Reduce Motion** on, there are no fades and the progress bar is static (the label still shows).
- No other animation.

---

## 4. Main window

### 4.1 Configuration [M]

- SwiftUI `Window("DOOM", id: "main")`, dark-only (D-21).
- Width fixed at **560 pt**. Height defaults to **640 pt** and can be resized from a minimum of 480 pt. Content scrolls.
- Opening it activates DOOM (`NSApp.activate`) and brings the window to the front.
- Closing it hides the window. DOOM keeps running (P2-14).

### 4.2 Structure (single scrolling column; sections separated by 24 pt; each section is a card with radius 10 and a `bgHigh` fill at 60 %)

1. **Header:** wordmark, version (monospaced) and the overall status line, one of:
   - "Ready" in `accentText`;
   - "Setup needed" in `warning`;
   - "Degraded configuration" (D-11).
2. **Setup checklist** (§4.3). Shown expanded while any prerequisite is missing, collapsed to a single line "Setup complete" once all are done.
3. **Gemini:** API key row, model row (§4.4).
4. **Shortcuts:** the two status rows (`SHORTCUT_SPECIFICATION.md` §7), plus the reservation note for ⌃⇧H.
5. **Privacy:** a summary, a [View Privacy Notice] button, and the Copy Fallback toggle (§4.6).
6. **About:** name, version and build; the statement "DOOM is an independent project and is not affiliated with or endorsed by Marvel, id Software, or Google."; [Quit DOOM].

### 4.3 Setup checklist rows [M]

| Row | States | Controls |
|---|---|---|
| Accessibility | Granted (emerald pill + text) / Not granted (amber) / Granted — restart needed | [Grant Access…] (prompts via `AXIsProcessTrustedWithOptions`), [Open System Settings] (opens Privacy & Security › Accessibility through its documented URL scheme, `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` *[Assumed stable; verify]*), [Restart DOOM] when needed |
| Gemini API key | Saved in Keychain / Not set / Keychain unavailable (E-KC-01) | See §4.4 |
| Privacy notice | Reviewed / Not reviewed | [Review…] opens the sheet (§4.6) |

- Each row has an icon, a title, a status word and controls.
- The status word is always present in text form.

### 4.4 Gemini section [M]

- **API key, not set:** a `SecureField` ("Paste your Gemini API key") with [Save]. Saving disables the field while it works, then shows "Saved in Keychain" or E-KC-02 inline.
- **API key, set:** the text "Saved in Keychain" (no characters, no masked preview) with [Replace…] and [Remove]. [Remove] asks for confirmation: "Remove the API key from this Mac?" with [Remove] (destructive) and [Cancel].
- Helper footnote: "Get a key from Google AI Studio. DOOM stores it only in your Mac's Keychain."
- **Model:** a `TextField` with the current model ID (placeholder: the default). [Reset] appears when the value differs from the default. Validation happens on commit (E-CFG-01 inline). Footnote: "Changing the model can change quality, speed and cost."

### 4.5 Status refresh [M]

- Permission and key status are refreshed when the window becomes key and when the app becomes active.
- There are **no timers**.

### 4.6 Privacy notice sheet and Copy Fallback toggle [M] *(P2-11 text approved)*

**Privacy notice (version 1), exact text:**

> **How DOOM handles your text**
> • When you press Fn ⌃ ⌥, DOOM reads the text you selected and sends it, with a fixed instruction, to Google's Gemini API using your API key. Nothing is sent at any other time.
> • DOOM doesn't send the app name, page address, window title or anything else from your screen.
> • DOOM asks Google not to store the request (store = false). Google's own terms still apply. With an unpaid (free-tier) key, Google may use what you send to improve its products and human reviewers may read it. Don't select sensitive or personal information when using a free-tier key. Paid-tier content isn't used to improve Google's products.
> • DOOM keeps your selection and the answer only in memory and discards them when you close the panel. DOOM doesn't keep history or logs of your text.
> • To detect Fn ⌃ ⌥, macOS lets DOOM observe keyboard events. DOOM only looks at the modifier keys and never records what you type.
> • Cancelling stops DOOM from waiting, but can't recall text that was already sent.
> [I Understand] [Not Now]

- [I Understand] stores `privacyNoticeAcknowledgedVersion = 1`.
- Raising the version (a material change) requires acknowledgement again.

**Copy Fallback toggle** (default **off**). Label: "Copy Fallback". Description:

> When an app doesn't share its selection with DOOM, DOOM can press ⌘C for you, read the copied text, and put your previous clipboard back. Clipboard managers and Universal Clipboard may still see the copied text. If DOOM quits unexpectedly during the copy, your previous clipboard contents can be lost. Protected clipboard content (for example from password managers) is never touched.

### 4.7 Keyboard (main window) [M]

- Standard SwiftUI focus order.
- ⌘W closes the window.
- Return activates the default button in sheets and confirmations; Escape cancels them.
- ⌘Q quits when the window is key, if the agent app's main menu processes key equivalents *[Assumed; verify UI-27]*. [Quit DOOM] in About and in the menu-bar item is always available.

---

## 5. Menu-bar item [M]

- A template image (monochrome; adapts to the menu bar). Placeholder SF Symbol: `hexagon`. The final icon is DD-10.
- The menu content follows `PRODUCT_BEHAVIOR.md` §0.1.
- The status line is the first, disabled item.
- When the response is ready and the panel is hidden, the status line reads "Response ready". The icon does not change (no badges).
- VoiceOver label: "DOOM".

---

## 6. Empty, loading and error states — summary

| Case | Surface | Spec |
|---|---|---|
| Nothing to show | Panel | §3.5 empty state (N-07) |
| Loading | Panel | §3.5 `acquiring` / `requesting`; §3.8 motion rules |
| Prerequisite missing | Panel + Settings row | E-ACC-01 / E-KEY-01 / E-PRIV-01 / E-KC-01 |
| Operational errors | Panel | §3.5 `failed` |
| Settings-field errors | Inline under the field, `error` colour + text | E-KC-02, E-CFG-01 |

---

## 7. Responsiveness [M]

- The panel appears ≤ 150 ms after activation.
- UI updates never wait on Accessibility IPC, the Keychain or the network. All of those are asynchronous off the main actor.
- The main actor never blocks longer than one frame for app logic (spot-checked with Instruments in UI-37).

---

## 8. Accessibility [M]

- Every control has an accessibility label. Icon-only buttons are labelled: × "Close" (or "Cancel" during work), Copy "Copy response".
- The panel's accessibility label is "DOOM response panel".
- The panel posts `NSAccessibility.Notification.announcementRequested` (priority high) on these transitions:
  - entry to `acquiring` ("Reading selection");
  - entry to `requesting` ("Asking Gemini");
  - success ("Response ready");
  - failure (the error title).

  It does not post on timer ticks.
- The response text is reachable with VoiceOver and is readable as a single static text element. Selection works with VoiceOver text commands *[verify UI-38]*.
- Full Keyboard Access works for all controls; the focus ring is the system ring.
- Reduce Motion, Increase Contrast and Reduce Transparency are respected. The panel is opaque, so Reduce Transparency needs no special handling.
- The minimum hit target is 24 × 24 pt.
- The VoiceOver modifier overlap with the activation chord is documented (`SHORTCUT_SPECIFICATION.md` §6).

---

## 9. Explicitly excluded (would need a new decision)

- capture-exclusion toggle;
- themes or light mode;
- custom fonts;
- background textures or images;
- particle or glow effects;
- sounds;
- notifications;
- history list;
- chat input field;
- resizable panel width;
- multiple panels;
- onboarding carousel;
- Dock badge.

---

## 10. Suggestions (optional, not required for acceptance)

- S-UI-1: A subtle 1-pixel "machined" top highlight on primary buttons.
- S-UI-2: Monospaced character count "N/20,000" in a debug build only.
- S-UI-3: Remember the dragged panel position across launches. This would need a preference and is not in v1.
- S-UI-4: An optional compact panel width (360 pt) for small screens.
