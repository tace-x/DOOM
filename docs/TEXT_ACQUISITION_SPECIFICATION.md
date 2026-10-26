# DOOM — Text Acquisition Specification (Phase 02)

**Status:** Specification only. Nothing has been implemented or run.
**Phase 01 basis:** C-3 (Accessibility; non-sandboxed, D-17), C-4 (clipboard), DD-03, DD-04, ARCHITECTURE §6 (no unbounded blocking on the main actor) and §7.3 rule 3 (content in memory only).
**Decisions:**
- P2-04: selection strategy and threading.
- P2-05: clipboard fallback, opt-in and off by default *(approved, Phase 03 §D.1)*.
- P2-10: the 20,000-character limit.

**Evidence labels:** *[Documented]* · *[Reported]* · *[Assumed — verify]*

---

## 1. Goal and non-goals

- **Goal:** return the text the user has selected in the frontmost app at the moment of activation, or a precise reason why it can't.
- **Non-goals:**
  - OCR or screen reading.
  - Reading anything other than the selection (no full document, no window title, no URL).
  - Background or continuous observation.
  - **Clipboard polling of any kind outside a single, bounded, user-activated fallback** (§4).

---

## 2. Permissions

| Operation | Requirement |
|---|---|
| Accessibility reads (`AXUIElementCopyAttributeValue`, parameterised attributes) and the attribute writes in §3.3 | Process trusted for Accessibility (`AXIsProcessTrusted()`); non-sandboxed *[Documented: DTS]* |
| Posting synthetic ⌘C (fallback) | Accessibility (event posting) *[Reported]* |
| Reading `NSPasteboard.general` (fallback) | No TCC permission on macOS 14. macOS 15.4+ may show a system alert or deny access, depending on `NSPasteboard.accessBehavior` *[API documented; enforcement varies by version]* |

- `AXIsProcessTrusted()` is checked **before** any acquisition step. If it is false, the result is `TextAcquisitionError.accessibilityNotGranted` (E-ACC-01).

---

## 3. Accessibility path (always first)

### 3.1 Sequence

```
1  app = NSWorkspace.shared.frontmostApplication            [main actor, read once]
     nil                          → .noSourceApplication     (E-SEL-02 with "this app")
     app.bundleIdentifier == DOOM → .ownApplication          (E-SEL-09)
   capture SourceApplication(name: app.localizedName, bundleID, pid)   (the pid is not kept after the flow)
2  hop to the AX executor (§6.1); all steps below run there
3  appEl = AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(appEl, 1.0)
4  if bundleID ∈ ChromiumFamily: ensureWebAccessibility(appEl)   (§3.3)
5  focused = copy(appEl, kAXFocusedUIElementAttribute)
     error kAXErrorAPIDisabled               → .accessibilityNotGranted
     error kAXErrorCannotComplete (timeout)  → .timedOut
     no value / attributeUnsupported         → (if step 4 just enabled Chromium AX: poll, §3.3) else go to 10 with reason .noFocusedElement
   AXUIElementSetMessagingTimeout(focused, 1.0)
6  secure check: role == kAXTextFieldRole && subrole == kAXSecureTextFieldSubrole → .secureField (E-SEL-03); never read anything else from it
7  Strategy A: s = copy(focused, kAXSelectedTextAttribute) as String
     non-empty after trim → SUCCESS(method: .accessibility)
8  Strategy B: r = copy(focused, kAXSelectedTextRangeAttribute) as CFRange
     r.length > 0 → s = copyParameterized(focused, kAXStringForRangeParameterizedAttribute, r) → if non-empty: SUCCESS
     r.length == 0 → DEFINITIVE EMPTY (caret only) → .emptySelection (E-SEL-01); no fallback
9  Strategy C (web content): for el in [focused, nearest ancestor with role "AXWebArea" (≤ 8 parent hops)]:
     m = copy(el, "AXSelectedTextMarkerRange")
     m present → s = copyParameterized(el, "AXStringForTextMarkerRange", m)
       non-empty → SUCCESS;  empty/collapsed → DEFINITIVE EMPTY → .emptySelection
10 Accessibility exhausted:
     Copy Fallback enabled → §4
     otherwise → .unsupported(reason)  (E-SEL-02)   [reason ∈ noFocusedElement, attributesUnsupported, indeterminateEmpty]
```

**"Indeterminate empty"** means a strategy returned an empty string without a definitive range signal. It is treated as *unsupported*, not as *empty*, because some apps return `""` for `kAXSelectedTextAttribute` even when text is selected. This is why the fallback runs for it.

### 3.2 Notes on the strategies

- **Strategy A** covers native Cocoa text views and fields, and many apps *[Documented: attribute in AXAttributeConstants]*.
- **Strategy B** helps apps that implement range attributes but not `AXSelectedText`.
- **Strategy C** uses the text-marker attributes that WebKit and Chromium implement for VoiceOver. It is the expected path for **selections in non-editable web page content** in Chrome and Safari.
  - *[Reported for WebKit: `AXSelectedText` only covers text controls, and page text needs `AXSelectedTextMarkerRange` + `AXStringForTextMarkerRange`.]*
  - *[Assumed for Chrome; verify TEXT-RM-02.]*
- Each attribute read is a separate IPC round trip bounded by the 1.0 s per-element timeout. The total Accessibility budget, excluding Chromium warm-up, is **1.5 s**. When it is exceeded, the result is `.timedOut` (E-SEL-05).

### 3.3 Chromium-family web accessibility (`ensureWebAccessibility`)

- Chrome builds its web-content accessibility tree only when an assistive client asks for it. It reacts to **`AXEnhancedUserInterface = true`** on the application element. The tree becomes available about **2 s** later.
  - Electron apps use `AXManualAccessibility`. Chrome returns "attribute unsupported" for that attribute. *[Reported by multiple 2026 developer reports; Chromium design doc: Chrome enables accessibility when it sees AXEnhancedUserInterface.]*
- `ChromiumFamily` is a constant set of bundle IDs:
  - `com.google.Chrome`, `com.google.Chrome.beta`, `com.google.Chrome.dev`, `com.google.Chrome.canary`
  - `org.chromium.Chromium`
  - `com.microsoft.edgemac` (and its beta, dev and canary variants)
  - `com.brave.Browser`
  - `com.vivaldi.Vivaldi`
  - `com.operasoftware.Opera`
  - `company.thebrowser.Browser`
- **Google Chrome is the required target. The others are best-effort.**
- Behaviour:
  1. Read `AXEnhancedUserInterface` on `appEl`. If it is already `true`, there is no warm-up (it was set earlier, or by VoiceOver).
  2. Otherwise set it to `true`, then retry step 5 every **100 ms** for up to **2.5 s** until a focused element appears. Only the first activation per Chrome process pays this cost.
  3. DOOM does **not** reset the attribute afterwards:
     - resetting would make every activation pay the warm-up;
     - it could disturb VoiceOver if VoiceOver set it.
- **Side effect:** while the attribute is set, Chrome keeps its accessibility tree active. This may cost some CPU and memory in Chrome. The attribute also causes window-animation quirks in some *non-browser* apps, which is why it is never set outside `ChromiumFamily`.
- **Electron (best-effort, not required):** when step 5 finds no focused element in an app outside `ChromiumFamily`, set `AXManualAccessibility = true` once and retry step 5 for up to 1.0 s. Apps that don't support it return "unsupported", which is harmless. *[Reported; Electron documentation describes the attribute.]*
- Warm-up time counts toward the user-visible "Reading selection…" state. The panel is already showing, so this is acceptable.

### 3.4 Unsupported contexts (known or expected)

| Context | Expected result |
|---|---|
| Canvas-rendered editors (Google Docs body, Figma, some games) | No usable selection attributes → fallback, or E-SEL-02 *[Assumed; Docs verify TEXT-RM-05]* |
| PDF in Chrome's built-in viewer | Unknown → verify (TEXT-RM-04) |
| Terminal-style apps that expose `AXValue` but not the selection (for example Warp) | E-SEL-02 / fallback *[Reported]* |
| Password fields | E-SEL-03, never read |
| DOOM's own windows | E-SEL-09 |

---

## 4. Clipboard fallback (opt-in, off by default; *P2-05, approved*)

### 4.1 Policy (normative)

1. It runs **only** when the user has turned on **Copy Fallback** in Settings, and only after the Accessibility path ends in `.unsupported` (§3.1 step 10).
2. It never runs for definitive empty, secure field, timeout, own application, or not-trusted results.
3. Exactly **one** synthetic copy per activation. It is never repeated and never retried automatically.
4. **Bounded observation:** the pasteboard `changeCount` is read at about 20 ms intervals for at most **600 ms**, **only** inside this fallback. Nothing observes the pasteboard at any other time.
5. Pre-existing clipboard content is **never** used as the selection (stale data).
6. The original clipboard is restored **only if no one else changed it** after DOOM's copy.
7. Snapshot data lives **only in memory**. It is never written to disk and never logged.
8. The Settings toggle's description says plainly what happens. Exact text is in `UI_SPECIFICATION.md` §4.6, including the clipboard-manager, Universal Clipboard and crash-loss caveats.

### 4.2 Sequence

All steps run on the **main actor**. `NSPasteboard` is used on the main thread *[Assumed safe practice; one report says `accessBehavior` off the main thread aborts]*. Waits use `Task.sleep` and never block.

```
1  if #available(macOS 15.4): if pb.accessBehavior == .alwaysDeny → .clipboardAccessDenied (E-SEL-08)
2  SNAPSHOT
     c0 = pb.changeCount
     items = pb.pasteboardItems ?? []
     if any item has a type in {org.nspasteboard.ConcealedType, org.nspasteboard.TransientType} → .clipboardNotPreservable (E-SEL-06)
         (types are inspected by name only; concealed/transient data is never read)
     for each item, for each type: data = item.data(forType:)
         nil → .clipboardNotPreservable   (cannot guarantee a faithful restore)
         running total > 50 MB → .clipboardNotPreservable
     snapshot = [[(type, data)]]   (empty clipboard → empty snapshot)
3  if Task.isCancelled → .cancelled   (nothing changed yet)
4  POST COPY
     keyCode = resolve "c" in the ASCII-capable layout (same resolver as SHORTCUT_SPECIFICATION §4.1; fallback kVK_ANSI_C)
     post keyDown + keyUp with .maskCommand to pid of the source app (CGEvent.postToPid)
5  WAIT  every 20 ms up to 600 ms: if pb.changeCount != c0 → break
     timed out (unchanged) → nothing was copied → .clipboardCopyFailed (E-SEL-07) [no restore needed]
6  READ   c1 = pb.changeCount; s = pb.string(forType: .string)
     nil → result .notText (E-SEL-10)
7  RESTORE (always runs after step 4 changed the clipboard, even if cancelled or failing; non-cancellable)
     if pb.changeCount == c1:
         pb.clearContents(); pb.writeObjects(snapshot rebuilt as NSPasteboardItems with every (type, data))
         (empty snapshot → clearContents only)
     else: skip restore; log selection.restoreSkipped; show N-08 if the flow succeeds
8  zero the snapshot references; return s (→ validation §5) or the error
```

- **Total budget:** at most **1.0 s** of wall time.
- **Restore time** is not bounded by DOOM: `writeObjects` speed depends on the data. Snapshots are capped at 50 MB to keep it short.

### 4.3 What the fallback cannot guarantee (disclosed)

- **Not atomic.** Another app or the user can change the clipboard during the window. DOOM detects the change and then skips its restore, rather than clobbering someone else's data.
- **Clipboard managers** may record the copied selection, and the restored content as a new entry.
- **Universal Clipboard** may sync the copied selection to the user's other Apple devices during the window.
- **Privacy alerts:** on macOS 15.4+ with `accessBehavior == .ask`, reading the clipboard during the snapshot or the read may trigger a system alert *[Assumed; verify TEXT-RM-08]*.
- **Lazy (promised) data:** `data(forType:)` forces promised data to be produced. That can be slow, which is why large or failing items abort the fallback.
- **Crash during the window:** the original clipboard is lost (`PRODUCT_BEHAVIOR.md` S-17).
- **Fidelity:** items are restored with the same types and bytes. Pasteboard *owner* identity and file-promise semantics may not survive *[Assumed]*.

### 4.4 Cancellation during the fallback

- Before step 4: return `.cancelled`; nothing has changed.
- After step 4: finish steps 5–7 (≤ 600 ms wait plus the restore), then return `.cancelled`. The read text is discarded.

### 4.5 Quit during the fallback

- `applicationShouldTerminate` returns `.terminateLater` until step 7 completes (`PRODUCT_BEHAVIOR.md` S-19).

### 4.6 Restoration rules summary

| Situation | Restore? |
|---|---|
| Copy produced a change; clipboard unchanged since | **Yes**, full snapshot |
| Copy produced no change | No (nothing to restore) |
| Clipboard changed again after DOOM's copy | **No**; N-08 is shown |
| Snapshot impossible (concealed/transient, unreadable, too large) | Fallback not attempted |

---

## 5. Validation (pure, `DoomCore.SelectionValidator`)

| Rule | Result |
|---|---|
| Remove U+0000 (NUL) characters | — |
| Trim leading and trailing whitespace and newlines (`.whitespacesAndNewlines`) | The trimmed text is what gets sent |
| Empty after trim | `.emptySelection` (E-SEL-01) |
| `count` (Swift `Character`s, grapheme clusters) > **20,000** | `.tooLong(count:limit:)` (E-SEL-04). **Never truncated** |
| Otherwise | `SelectedText(value, characterCount, source, method)` |

- **Why 20,000 characters:** roughly 5,000–10,000 tokens. That bounds cost, latency and accidental mass disclosure (for example a select-all on a long document), while comfortably covering paragraphs, emails, error logs and code snippets.
- The limit is a constant in Core and is tested on both sides of the boundary.
- Internal line breaks and spacing are preserved.

---

## 6. Concurrency, timeouts and cancellation

### 6.1 The Accessibility executor (justified exception, P2-04)

- Accessibility calls are **synchronous cross-process IPC**. They can block for up to the messaging timeout.
- They run on **one dedicated serial `DispatchQueue`** owned by `AccessibilitySelectionReader`, and are bridged with `withCheckedThrowingContinuation`.
- **Why a queue rather than the cooperative pool:** blocking a Swift-concurrency cooperative thread with IPC is discouraged. A dedicated queue isolates the blocking. This is the documented exception to ARCHITECTURE §6's GCD rule, and it is limited to this one type.
- The Accessibility element references never leave the reader. The reader returns only `Sendable` values (String, enums).

### 6.2 Timeouts

| Item | Value |
|---|---|
| Per-element messaging timeout | 1.0 s, set **per element** on `appEl` and `focused` (and on any ancestor that is read). It is **never** set on the system-wide element, because that changes the process-wide default *[Documented: AXUIElement.h]*. |
| Accessibility path total | 1.5 s (excluding the Chromium warm-up) |
| Chromium warm-up | ≤ 2.5 s, first activation per process |
| Electron retry | ≤ 1.0 s |
| Clipboard wait | ≤ 600 ms |
| Hard cap for the whole acquisition | 5.0 s → `.timedOut` |

### 6.3 Cancellation checkpoints

- **Accessibility path:** checkpoints between every step of §3.1.
- **Fallback:** §4.4.
- A cancelled acquisition never proceeds to a request.

### 6.4 Main-actor rule

- The main actor is never blocked by Accessibility IPC.
- The pasteboard steps are short operations on the main actor. The waits use `Task.sleep`.

---

## 7. Errors (`DoomCore.TextAcquisitionError`)

| Case | User message | Logged as (public) |
|---|---|---|
| `.accessibilityNotGranted` | E-ACC-01 | `notTrusted` |
| `.noSourceApplication` | E-SEL-02 ("this app") | `noSourceApp` |
| `.ownApplication` | E-SEL-09 | `ownApp` |
| `.secureField` | E-SEL-03 | `secureField` |
| `.emptySelection` | E-SEL-01 | `empty` |
| `.unsupported(reason)` | E-SEL-02 | `unsupported.<reason>` |
| `.tooLong(count:limit:)` | E-SEL-04 | `tooLong` + count |
| `.timedOut` | E-SEL-05 | `timedOut` + elapsed ms |
| `.clipboardAccessDenied` | E-SEL-08 | `pbDenied` |
| `.clipboardNotPreservable` | E-SEL-06 | `pbNotPreservable` |
| `.clipboardCopyFailed` | E-SEL-07 | `pbCopyNoChange` |
| `.notText` | E-SEL-10 | `pbNotText` |
| `.cancelled` | (none) | `cancelled` |

- Associated values are limited to counts, limits, reason enums, and the `SourceApplication` name, which is used for **UI only** and is never logged.

---

## 8. Privacy and logging

- **Never logged** at any level:
  - selected text;
  - clipboard contents or types;
  - app name or bundle ID;
  - window titles;
  - URLs;
  - element roles of the user's documents.
- **Logged** (category `selection`, all public):
  - method;
  - outcome case;
  - duration in ms;
  - character count;
  - whether a Chromium warm-up happened;
  - whether the restore was skipped.
- Selected text and snapshot data are discarded at flow end (INV-4).

---

## 9. Testing

### 9.1 Automated (none executed yet)

| ID | Test |
|---|---|
| TEXT-T-01…06 | `SelectionValidator`: NUL removal, trimming, empty, 20,000 accepted, 20,001 rejected, multi-scalar graphemes (emoji, combining marks) counted as one character. |
| TEXT-T-07 | Strategy-decision logic (pure function over a fake attribute provider): A succeeds → no B or C; A empty with range length 0 → definitive empty; A empty with no range → C; all fail → unsupported or fallback by flag. |
| TEXT-T-08 | Fallback state logic against an in-memory `PasteboardAccess` fake: unchanged `changeCount` → `.clipboardCopyFailed` and no restore; changed then stable → restore performed with all types; changed again → restore skipped; a concealed type → aborted before copy; cancellation after copy → restore still performed. |
| TEXT-T-09 | Timeout mapping: a fake provider returning `cannotComplete` → `.timedOut`. |
| TEXT-T-10 | Review grep: `NSPasteboard` appears only in the fallback type, **plus the single write-only [Copy] call site in `AssistantController.copyResponse()` (P3-15)**, which may call only `clearContents()` and `setString(_:forType: .string)` and never reads. There is no `Timer` or repeating loop on the pasteboard anywhere. |

### 9.2 Real Mac (human required; Accessibility granted; stable-signed build)

| ID | Procedure | Pass |
|---|---|---|
| TEXT-RM-01 | TextEdit: select a word, a paragraph, then emoji and RTL text; activate | Exact text captured (debug build shows the count; the user compares the response) |
| TEXT-RM-02 | Chrome: select text in a normal web page (non-editable) on the **first** activation after launching Chrome, then again | Captured on both, after ≤ 2.5 s warm-up the first time |
| TEXT-RM-03 | Chrome: selection inside a `<textarea>` and an `<input>` | Captured |
| TEXT-RM-04 | Chrome: PDF viewer selection | Result recorded |
| TEXT-RM-05 | Google Docs in Chrome (Copy Fallback off, then on) | Off → E-SEL-02; on → captured, clipboard restored |
| TEXT-RM-06 | Selection, then menu **Ask DOOM About Selection** | Selection captured, proving the menu interaction doesn't clear it |
| TEXT-RM-07 | Fallback restore fidelity: copy rich text with an image in Pages/TextEdit, then activate in an unsupported app with the fallback on, then paste | The original rich content is restored |
| TEXT-RM-08 | macOS 15.4+: fallback with the default access behaviour | Record whether a system alert appears |
| TEXT-RM-09 | Password field in Safari | E-SEL-03; nothing read |
| TEXT-RM-10 | An unresponsive app (a debugger-paused process) | E-SEL-05 within ≤ 1.5 s; DOOM stays responsive |
| TEXT-RM-11 | Revoke Accessibility mid-session; activate via the menu | E-ACC-01 |

---

## Sources (consulted 2026-10-24)

- `AXUIElementSetMessagingTimeout` (system-wide element sets the process-global timeout; per-element otherwise). The header text is in Apple's SDK `AXUIElement.h`, mirrored at https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.6.sdk/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Headers/AXUIElement.h. The `kAXErrorCannotComplete` definition is at https://developer.apple.com/documentation/applicationservices/axerror/kaxerrorcannotcomplete.
- Chromium accessibility design (Chrome enables accessibility when it sees `AXEnhancedUserInterface`): https://www.chromium.org/developers/design-documents/accessibility/
- Electron accessibility (`AXManualAccessibility`): https://www.electronjs.org/docs/latest/tutorial/accessibility
- Developer reports (2026) that Chrome ignores `AXManualAccessibility`, builds its tree about 2 s after `AXEnhancedUserInterface`, and that the attribute has side effects in non-browser apps: for example https://github.com/PaRaD1SE98/aoide/pull/6 and https://github.com/Beingpax/VoiceInk/issues/1000 *(community sources; verified only by TEXT-RM-02)*
- App Sandbox incompatibility, pasteboard `accessBehavior`, concealed/transient types: Phase 01 research (`ARCHITECTURE.md` Sources)
