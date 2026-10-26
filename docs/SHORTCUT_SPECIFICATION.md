# DOOM — Shortcut Specification (Phase 02)

**Status:** Specification only. Nothing has been implemented or run.
**Phase 01 basis:** C-1, C-2 (`ARCHITECTURE.md` §7.2), DD-02, D-17 (non-sandboxed), D-19 (stable signing).
**Decisions:** P2-02 (activation-detection mechanism) and P2-03 (Control+Shift+H mechanism), recorded in `TECHNICAL_DECISIONS.md` §C.

**Evidence labels:**
- ***[Documented]*** means Apple documentation or an Apple engineer's statement.
- ***[Reported]*** means credible developer reports.
- ***[Assumed]*** means it is believed but unverified, and must be verified on the user's Mac.

---

## 1. The two shortcuts

| Shortcut | Purpose | Kind | Mechanism | Permission |
|---|---|---|---|---|
| **Fn + Control + Option** | Activation (read selection → ask Gemini) | *Modifier-only chord* (no character key) | `NSEvent` global + local monitors for `.flagsChanged` and `.keyDown`, feeding a pure chord recogniser (P2-02) | **Accessibility** (already required for reading the selection) |
| **Control + Shift + H** | Hide/show the panel | Key + modifiers | Carbon `RegisterEventHotKey` (P2-03) | None *[Reported; assumed for current macOS, verify, SHORTCUT-RM-07]* |

---

## 2. Documented behaviour vs assumptions

| # | Statement | Label |
|---|---|---|
| F-1 | `RegisterEventHotKey` needs a non-modifier virtual key code. It has no Fn modifier, so it **cannot** express Fn+Control+Option. | Documented (Carbon API surface) |
| F-2 | Global `NSEvent` monitors can only observe events. They cannot modify or swallow them. "Key-related events may only be monitored if accessibility is enabled or if your application is trusted for accessibility access." Handlers are not called for events sent to DOOM itself, which is why a local monitor is also needed. | Documented (NSEvent reference) |
| F-3 | A listen-only `CGEventTap` requires Input Monitoring (`CGPreflightListenEventAccess` / `CGRequestListenEventAccess`). An active tap requires Accessibility. | Documented / DTS |
| F-4 | Fn changes arrive as `flagsChanged` with key code 63, setting `NSEvent.ModifierFlags.function` (`CGEventFlags.maskSecondaryFn`). | Reported |
| F-5 | macOS also sets the Function flag on arrow, F-key and navigation key events without Fn being pressed. | Reported |
| F-6 | A *lone* Fn/Globe press-and-release can trigger the Globe action (emoji picker, input-source switch, dictation), depending on System Settings › Keyboard › "Press 🌐 key to". Whether it triggers when Fn is released *together with* Control+Option is unknown. | Reported / **Assumed** |
| F-7 | Many external keyboards handle Fn in firmware and never send it to macOS. | Reported |
| F-8 | One report says a macOS 27 beta stopped delivering bare Fn `flagsChanged` events to event taps. The effect on `NSEvent` monitors is unknown. | Reported, **unverified** |
| F-9 | Secure Event Input (password fields, some terminals) prevents global monitors and taps from seeing key events. | Reported |
| F-10 | Control + Option is the VoiceOver modifier. | Documented (VoiceOver guide) |
| F-11 | macOS 15.0–15.1 rejected `RegisterEventHotKey` registrations whose *only* modifiers were Option and/or Shift, with error −9868. Apple reverted this in 15.2. Control+Shift+H includes Control, so it is unaffected either way. | Documented (Apple Frameworks Engineer, forum thread 763878) + reported |
| F-12 | Carbon hotkeys still fire while Secure Event Input is active. | **Assumed** (verify, SHORTCUT-RM-08) |
| F-13 | An existing global monitor starts receiving key events once Accessibility is granted, without being reinstalled. | **Assumed false for safety.** Monitors are reinstalled on a grant change (§3.4). |

**Feasibility conclusion:** Fn+Control+Option is **plausible but unproven**. The spec therefore requires a feasibility spike on the user's MacBook Air (§9) before the activation feature is declared working. There is no silent substitution (§10).

---

## 3. Activation chord — Fn + Control + Option

### 3.1 Why `NSEvent` monitors and not a `CGEventTap` (P2-02)

| | `NSEvent` global + local monitors | Listen-only `CGEventTap` |
|---|---|---|
| Permission | **Accessibility only**, which DOOM needs anyway for the selection | **Input Monitoring**, a second TCC prompt, plus Accessibility for the selection |
| Can swallow events | No (not needed) | No (listen-only) |
| Disabled by timeouts | No (asynchronous delivery) | Yes (`tapDisabledByTimeout`; must be re-enabled) |
| Threading | Main thread | Run-loop source (main) |
| Fn visibility | **Assumed** same as a tap (F-4); must be verified | Reported |

**Decision:** monitors are primary. A listen-only tap is a **conditional alternative**, used only if the spike shows Fn arrives at a tap but not at monitors. Adopting it adds an Input Monitoring prompt, so it needs the user's acknowledgement (P2-02 note).

### 3.2 Recognition rules (normative)

Let `F = {function, control, option}` (the chord set) and `X = {command, shift}` (the excluded set). Caps Lock is ignored. Only `.flagsChanged` and `.keyDown` events matter.

```
IDLE
  on flags: if F ⊆ flags and flags ∩ X = ∅  → ARMED(t0 = event.timestamp)
            (keys may be pressed in any order; arming happens when the last of the three goes down)
ARMED
  on keyDown (any key, including repeats)    → CANCELLED
  on flags: if flags ∩ X ≠ ∅                 → CANCELLED
  on flags: if flags ∩ F = ∅ (all three released):
            if (event.timestamp − t0) ≤ 2.0 s → emit .activate, → IDLE
            else                               → IDLE (no emit)
  on flags: partial release (some of F still down) → stay ARMED (waiting for full release)
  on flags: a released F key is pressed again while others still down → stay ARMED (t0 unchanged)
CANCELLED
  on flags: if flags ∩ (F ∪ X) = ∅           → IDLE
  (keyDown ignored)
```

- **Fire on full release.** This avoids conflicts with chords that *start* with Fn+Control+Option plus a key, such as VoiceOver commands or Fn+arrows. It also guarantees no physical modifiers are held when the clipboard fallback posts ⌘C.
- **Hold limit:** 2.0 s, a constant. Holding longer, for example while resting on the keys, does nothing.
- **Mouse events** are not observed and don't affect the recogniser. This is a documented limitation: a Control-Option-click is indistinguishable.
- **Both local and global monitors** feed the same recogniser. That covers DOOM's own windows being key (local) and every other app (global). Each event is delivered to exactly one of them.

### 3.3 Repeated activation

- A second recognised activation while the flow is `acquiring` or `requesting` is **ignored**. The panel is shown if hidden (`PRODUCT_BEHAVIOR.md` S-04).
- An activation while the flow is `succeeded` or `failed` starts a new flow.
- There is no extra debounce, because the full-release requirement already makes two activations at least one press-release cycle apart.

### 3.4 Registration lifecycle

| Moment | Action |
|---|---|
| App launch (after the composition root) | Install the local monitor and the global monitor (`.flagsChanged`, `.keyDown`). Record `AXIsProcessTrusted()` as `lastTrusted`. Status is **Active** if trusted, otherwise **Needs Accessibility** (E-SC-02 in Settings). |
| App becomes active, main window becomes key, or the user returns from System Settings | Re-check `AXIsProcessTrusted()`. On a change from false to true: **remove and reinstall the global monitor** (F-13), and set status to Active. On a change from true to false: set status to Needs Accessibility, and leave the monitors installed (harmless). |
| Quit | Remove both monitors. |

- No polling timers.
- The monitors never prompt for anything.

### 3.5 Privacy of key observation

- The handler reads **only** `event.type`, `event.modifierFlags` and `event.timestamp`.
- It **MUST NOT** read `characters`, `charactersIgnoringModifiers` or `keyCode`. The exception is `keyCode` on `.flagsChanged`, and only for diagnostics in debug builds.
- It must not store events, buffer them, or log them.
- A `.keyDown` received while the recogniser is IDLE is dropped immediately.
- A code-review grep checks that `characters` does not appear in the monitor file (`ENGINEERING_STANDARDS.md` §8 addition, P2-02).
- The settings and privacy text state plainly: "To detect Fn ⌃ ⌥, macOS lets DOOM observe keyboard events. DOOM only looks at the modifier keys and never records what you type."

### 3.6 Focus and panel visibility

- Activation never changes the frontmost app and never makes the panel key (`UI_SPECIFICATION.md` §3.4). The source app keeps keyboard focus and its selection.
- An activation always ensures the panel is visible, including the busy case.

### 3.7 Cancellation

- The chord itself never cancels anything. Cancellation uses [Cancel], Escape or × in the panel, or Quit (`PRODUCT_BEHAVIOR.md` S-07).
- Pressing the chord again while busy does **not** cancel, because a stray press must not destroy an in-flight answer.

---

## 4. Panel shortcut — Control + Shift + H

### 4.1 Registration

| Item | Specification |
|---|---|
| API | `InstallEventHandler(GetEventDispatcherTarget(), …, kEventClassKeyboard / kEventHotKeyPressed)` once, then `RegisterEventHotKey(keyCode, controlKey \| shiftKey, EventHotKeyID(signature: 'DOOM', id: 1), GetEventDispatcherTarget(), 0, &ref)` |
| Key code | Resolved for the character **"h"** in the **current ASCII-capable keyboard layout** (`TISCopyCurrentASCIICapableKeyboardLayoutInputSource` + `UCKeyTranslate` over the key codes). If resolution fails, fall back to `kVK_ANSI_H` and log `shortcut.layoutFallback`. |
| Layout changes | Observe `kTISNotifySelectedKeyboardInputSourceChanged` (distributed notification). Re-resolve the key code. If it changed, unregister and re-register. |
| Delivery | The Carbon handler runs on the main thread and forwards `.togglePanel` into the same `ShortcutEvent` stream as activation (`MODULE_CONTRACTS.md` §4.1). |
| Behaviour | Panel hidden → show it, with current content or the empty state N-07 (or E-ACC-01 if Accessibility is missing). Panel visible → hide it. **Never cancels** the flow (INV-5). |
| Unregistration | `UnregisterEventHotKey` at quit. |

### 4.2 Conflicts and registration failure

- A non-`noErr` return from `RegisterEventHotKey` means status **Unavailable**. Known values include `eventHotKeyExistsErr` (−9878) and `eventHotKeyInvalidErr` (−9879).
  - The Settings row shows E-SC-01.
  - The menu item **Show/Hide Panel** still works.
  - The failure is logged with the numeric `OSStatus` (public).
  - DOOM retries registration once on the next app activation. There is no loop.
- **Undetectable conflicts:** macOS doesn't report conflicts with non-exclusive registrations by other apps, or with app-local menu shortcuts. When DOOM's registration succeeds, it takes Control+Shift+H **away from the frontmost app** while DOOM runs. This is a documented trade-off, shown in Settings under the shortcut: "While DOOM is running, Control-Shift-H is reserved for DOOM."
- System Settings › Keyboard Shortcuts entries may also conflict. That has to be checked on the device (SHORTCUT-RM-09).

---

## 5. Permissions summary

| Capability | Permission | Prompt trigger |
|---|---|---|
| Activation chord (monitors) | Accessibility | Only [Grant Access…] in the main window |
| Activation chord (alternative tap, if adopted) | Input Monitoring **plus** Accessibility | Explicit button, after the user approves P2-02's alternative |
| Control+Shift+H | None *[Assumed]* | — |

- Grants are tied to the code signature, so ad-hoc rebuilds lose them. Stable Apple Development signing is a precondition for any real-Mac shortcut test (D-19).

---

## 6. Keyboard configurations

| Configuration | Expected | Status |
|---|---|---|
| MacBook Air built-in keyboard (Fn/Globe key) | Chord works | **Must verify** (SHORTCUT-RM-01) |
| "Press 🌐 key to" = Show Emoji & Symbols / Change Input Source / Start Dictation / Do Nothing | The chord should work with each. The Globe action might also fire (F-6) | **Must verify** each setting (SHORTCUT-RM-03) |
| "Use F1, F2, etc. keys as standard function keys" on/off | No effect expected (no F-keys involved) | Verify (SHORTCUT-RM-04) |
| External Apple Magic Keyboard with Touch ID | Fn is expected to be reported | Verify if the user owns one |
| External third-party keyboard | Fn is **often not sent**. The chord will not work, and there is no workaround with monitors | Document as a limitation |
| Modifier keys remapped in System Settings (for example Caps Lock → Control) | Flags reflect the *remapped* modifier; this should work | Verify if used |
| Sticky Keys (Accessibility) | Undefined. Modifiers latch, and the recogniser may never see a "full release" | Document as a limitation; verify optional |
| VoiceOver running | Control+Option chords with keys cancel the recogniser through keyDown. A pure Fn+Control+Option release may activate DOOM while the user meant a VoiceOver gesture | Verify (SHORTCUT-RM-06) |
| Non-QWERTY layouts (AZERTY, QWERTZ, Dvorak, Colemak, non-Latin) | Chord: layout-independent (modifiers only). Control+Shift+H: resolved by character (§4.1) | Verify one non-QWERTY layout (SHORTCUT-RM-10) |
| Secure Event Input active | The chord is not seen (F-9). Control+Shift+H is assumed to still work (F-12) | Verify (SHORTCUT-RM-08) |

---

## 7. Errors and statuses surfaced to the user

| Status | Where | Text |
|---|---|---|
| Activation: Active | Settings › Shortcuts | "Fn ⌃ ⌥ — press and release together" + "Active" |
| Activation: Needs Accessibility | Settings + menu status line | E-SC-02 |
| Activation: Unverified on this Mac | Settings (until the spike passes; a build flag removed after verification) | "Not yet verified on this Mac" |
| Panel shortcut: Active / Unavailable | Settings › Shortcuts | "⌃⇧H — show or hide the panel" / E-SC-01 |

---

## 8. Automated tests (run on macOS with Xcode; none executed yet)

| ID | Target | Test |
|---|---|---|
| SHORTCUT-T-01 | Chord recogniser (pure, `DoomServicesTests`) | Press F in every one of the 6 orderings, then release all within 2.0 s → exactly one `.activate`. |
| SHORTCUT-T-02 | same | Any keyDown while ARMED → no activate. The next clean chord still activates. |
| SHORTCUT-T-03 | same | Command or Shift added at any point → no activate until everything is released. |
| SHORTCUT-T-04 | same | Hold of 2.01 s → no activate. Hold of exactly 2.0 s → activate. |
| SHORTCUT-T-05 | same | Partial release followed by re-press → one activate on final release. |
| SHORTCUT-T-06 | same | Function flag arriving with a keyDown (an arrow key, F-5) never arms on its own. |
| SHORTCUT-T-07 | same | Fn+Control only, or Control+Option only → no activate. |
| SHORTCUT-T-08 | Key-code resolver (pure function over an injected layout table) | "h" resolves to 4 on a US table, and to the correct code on a Dvorak table. A missing character → fallback flag. |
| SHORTCUT-T-09 | `AssistantController` with a fake monitor stream | Activation while `requesting` → no second request (the fake AI responder counts calls == 1). |
| SHORTCUT-T-10 | Monitor adapter | Compile-time and grep check: no `characters` access (review gate). |

Real OS event delivery cannot be unit-tested. It is covered in §9.

---

## 9. Real-device tests (human required, on the user's MacBook Air, stable-signed build)

| ID | Procedure | Pass condition |
|---|---|---|
| SHORTCUT-RM-01 | **Feasibility spike.** A debug build logs the recogniser transitions (flags only). Press Fn+Control+Option 20 times in TextEdit and 20 times in Chrome. | ≥ 20/20 activations in each, 0 spurious. |
| SHORTCUT-RM-02 | Type normally for 2 minutes in Chrome and TextEdit, using Control/Option shortcuts and Fn+arrows. | 0 activations. |
| SHORTCUT-RM-03 | Repeat RM-01 (5 presses) under each "Press 🌐 key to" setting. | Record whether the Globe action fires. Pass = no Globe side effect, **or** the user accepts the documented workaround ("Do Nothing"). |
| SHORTCUT-RM-04 | Toggle the standard function keys setting; repeat 5 presses. | Same result. |
| SHORTCUT-RM-05 | Grant Accessibility while DOOM is running, then press the chord without relaunching. | Activation works; otherwise the restart prompt is shown (PERM-05). |
| SHORTCUT-RM-06 | Turn on VoiceOver; perform common VO commands; press the chord. | VO commands produce no activation. Chord behaviour is recorded. |
| SHORTCUT-RM-07 | Control+Shift+H with Accessibility **not** granted. | The panel toggles, proving no permission is needed. |
| SHORTCUT-RM-08 | Focus a password field in Safari; press the chord and Control+Shift+H. | Record both. Expected: chord not seen; ⌃⇧H works. |
| SHORTCUT-RM-09 | Check System Settings › Keyboard Shortcuts and common apps (Chrome, VS Code) for ⌃⇧H use. | Conflicts are documented. |
| SHORTCUT-RM-10 | Switch to a non-QWERTY layout; press ⌃⇧H. | The key labelled H toggles the panel. |
| SHORTCUT-RM-11 | Panel visible, Chrome focused: press the chord. | Chrome keeps focus (typing still goes to Chrome) and the selection is unchanged. |

---

## 10. If the chord is infeasible (proposal for the user's approval only)

If SHORTCUT-RM-01 or RM-02 fails, the implementation phase **stops the activation feature**, reports the measured results, and asks the user to choose. **Nothing is substituted automatically.**

| Option | Shortcut | Mechanism | Trade-offs |
|---|---|---|---|
| **A (alternative mechanism, same chord)** | Fn + Control + Option | Listen-only `CGEventTap` | Only helps if Fn reaches taps but not monitors. Adds an Input Monitoring permission. |
| **B (closest chord)** | Control + Option + Command (modifier-only) | Same monitors and recogniser, with `F = {control, option, command}` and `X = {shift, function}` | No Fn dependency. Still a VoiceOver-modifier overlap. |
| **C (conventional hotkey)** | Control + Shift + Space | Carbon `RegisterEventHotKey` | Most reliable, and needs no permission for detection. Takes the combination away from other apps. Accessibility is still needed to read the selection. |

The menu item **Ask DOOM About Selection** works regardless of the shortcut outcome. It is subject to TEXT-RM-06, which verifies that the selection survives opening the menu.

---

## Sources (consulted 2026-10-24)

- Apple Developer Forums 763878 (Apple Frameworks Engineer on Option/Shift-only hotkeys in macOS Sequoia): https://developer.apple.com/forums/thread/763878
- Report of the macOS 15.2 reversal: https://blog.eternalstorms.at/2024/09/23/keyboard-shortcuts-using-option-and-or-shift-modifiers-only-no-longer-allowed-on-macos-sequoia/
- `NSEvent.addGlobalMonitorForEvents` (key events require Accessibility trust; own-app events excluded). The NSEvent.h and reference text is quoted at https://stackoverflow.com/questions/34244865/swift-nsevent-not-working. Apple's page was not fetched directly; re-check it in the implementation phase.
- Apple Developer Forums 722622 (`CGPreflightListenEventAccess` / `CGRequestListenEventAccess`): https://developer.apple.com/forums/thread/722622
- Fn key code 63, Globe behaviour, external keyboards, the macOS 27 report, TCC requirements for taps: Phase 01 research (`ARCHITECTURE.md` Sources)
