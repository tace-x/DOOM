# DOOM — Security and Privacy Specification (Phase 02)

**Status:** Specification only. Nothing has been implemented, signed or verified.
**Phase 01 basis:**
- ARCHITECTURE §7.3 (cross-cutting rules), §8 (logging), §9 (boundaries);
- D-13 (logging), D-17 (non-sandboxed), D-18 (hardened runtime), D-19 (signing), D-20 (no dependencies), D-23 (Keychain direction), D-24 (no telemetry);
- C-5 (tier terms), C-7 (capture).

**Rule for this document:** every retention or deletion statement says **who enforces it**. DOOM makes no promise it cannot enforce. Where Google or macOS controls behaviour, that is stated.

---

## 1. Threat model (summary)

| Asset | Threat | Primary control |
|---|---|---|
| Gemini API key | Disclosure via source, logs, files, screenshots, crash data; misuse by other local apps | Data protection keychain item, device-only, never displayed after save, header-only transmission |
| Selected text / responses | Persistence on disk, logging, unintended transmission, shoulder-surfing or screen capture | Memory-only handling, log ban, exactly one request to one endpoint, Control+Shift+H hide, honest capture disclosure |
| User's clipboard | Loss or corruption, leakage of protected items | Opt-in fallback, concealed/transient skip, conditional restore |
| Keystrokes | DOOM acting as a keylogger | The recogniser reads modifier flags and event types only, with no storage (`SHORTCUT_SPECIFICATION.md` §3.5) |
| Privileged position (Accessibility) | Misuse of the granted privilege | Least privilege; reads occur only on activation; no Apple Events; no extra entitlements; hardened runtime |
| Supply chain | Malicious dependency | Zero third-party dependencies (D-20) |

**Out of scope:** a compromised macOS, or malware running as the same user with Accessibility rights. Such malware can read the screen and the Keychain prompts regardless of what DOOM does.

---

## 2. Data categories

Each category has seven fields:
- **Why** — why DOOM needs it
- **Stored** — where it is stored
- **Retention** — how long it is kept
- **Leaves Mac?** — whether it leaves the Mac
- **Access** — who can access it
- **Loggable?** — whether it can be logged
- **Deletion** — how it is deleted

### 2.1 Keychain data (Gemini API key)
- **Why:** to authenticate the single request to the Gemini API.
- **Stored:**
  - **Location:** the data protection keychain, as a generic password (service = bundle ID, account = `gemini-api-key`).
  - **Protection:** `WhenUnlockedThisDeviceOnly`, not synchronizable.
  - It is never in source, `Info.plist`, xcconfig, UserDefaults, files, environment variables (app target) or logs (D-23).
  - In memory, the key exists only while one request is being built and sent. It is not cached between requests.
- **Retention:** until the user removes it ([Remove]), or deletes the app's Keychain data. **Deleting the app does not delete Keychain items** (macOS behaviour). This is disclosed in the About section footnote.
- **Leaves Mac?** Yes, only in the `x-goog-api-key` HTTPS header to `generativelanguage.googleapis.com`. It is never sent to another host, and redirects are not followed (`GEMINI_INTEGRATION_SPECIFICATION.md` §4).
  - **Not in backups as a usable item:** `ThisDeviceOnly` items do not migrate to other devices *[Documented behaviour of the attribute]*.
- **Access:**
  - DOOM, when it is signed with the same team and app identifier (keychain access group); and the user, through Keychain-aware tools.
  - Other apps cannot read it without sharing the access group.
  - Root or malware running as the user is out of scope.
- **Loggable?** **Never**, including any prefix, suffix, length or hash.
- **Deletion:**
  - Settings › [Remove] → `SecItemDelete`.
  - **Uninstall:** the user must remove the item manually, or press [Remove] before deleting the app. The uninstall instructions in the README say so.
- **Dependency:** this requires an Apple Development team-signed build (C-6, D-19). An unsigned or ad-hoc build gets −34018 → E-KC-01.
  - **No silent fallback** to the file-based keychain or to files. If the user cannot use team signing, a separate decision is needed (`RISK_REGISTER.md` R-12).

### 2.2 Accessibility data
- **Why:** to read the current selection in the frontmost app (`TEXT_ACQUISITION_SPECIFICATION.md` §3).
- **Stored:**
  - Only transient attribute values in memory on the Accessibility executor.
  - DOOM writes two attributes into *other* apps:
    - `AXEnhancedUserInterface = true` on Chromium-family browsers;
    - `AXManualAccessibility = true` (best-effort) on apps without a focused element.

    These change accessibility behaviour in those apps until they quit.
- **Retention:**
  - Values are discarded when the acquisition step ends.
  - The attribute writes persist **in the target app's process** until it quits. This is disclosed in Settings under Accessibility: "To read web pages, DOOM turns on Chrome's accessibility support, which stays on until Chrome quits."
- **Leaves Mac?** Only the selected text, as part of §2.5. Element roles, app identity and window data never leave the Mac.
- **Access:** DOOM's process.
  - The TCC grant itself is stored by macOS. DOOM can't read it beyond `AXIsProcessTrusted()`.
- **Loggable?**
  - Only outcome enums, durations and counts (`TEXT_ACQUISITION_SPECIFICATION.md` §8).
  - Never text, app names, bundle IDs, titles, URLs or roles.
- **Deletion:**
  - In-memory data is released at step end.
  - The TCC grant is revoked by the user in System Settings › Privacy & Security › Accessibility (DOOM gives the path), or with `tccutil reset Accessibility <bundle ID>`, which is documented for developers.

### 2.3 Clipboard data (Copy Fallback only; off by default)
- **Why:** to obtain the selection from apps that don't expose it through Accessibility. The user opts in explicitly.
- **Stored:**
  - **Memory only:** the snapshot of the previous clipboard contents (all items and types, ≤ 50 MB) and the copied string.
  - Never written to disk.
- **Retention:** ≤ 1 s for the snapshot. It is released right after restoring, or after skipping the restore.
- **Leaves Mac?**
  - The **copied selection** is sent to Gemini (it is the selected text, §2.5).
  - The **snapshot** never leaves the Mac.
  - **Caveats outside DOOM's control:** clipboard managers may record the copied selection, and Universal Clipboard may sync it to the user's devices.
- **Access:**
  - DOOM's process.
  - While the copy sits on the pasteboard, any app that can read the general pasteboard.
- **Loggable?**
  - Never contents or types.
  - Only `changeCount`-derived outcomes ("no change", "restore skipped") and durations.
- **Deletion:**
  - The snapshot is released after use.
  - A crash during the window loses the original clipboard (disclosed, `PRODUCT_BEHAVIOR.md` S-17).
  - The fallback is disabled with the Settings toggle.

### 2.4 Network requests
- **Why:** one request per activation or Retry, to obtain the answer.
- **Provider Terms Verification (M05 Checked: October 25, 2026):**
  - **Sources Reviewed:**
    - Google Generative AI API Terms of Service: `https://ai.google.dev/terms`
    - Google Gemini API Data Handling & Privacy Documentation: `https://ai.google.dev/gemini-api/docs/data-handling`
    - Interactions API Reference: `https://ai.google.dev/api/interactions`
  - **Data-Use Terms (Free vs. Paid Tiers):**
    - Under Google's **Unpaid Tier (Free of Charge)**, prompts and generated content may be processed and retained by Google, may be reviewed by trained human reviewers, and may be used by Google to develop and improve Google products, services, and machine learning technologies.
    - Under Google's **Paid Tier (Pay-As-You-Go)**, Google does not use customer input or output data to train Google models, and inputs/outputs are not accessible to human reviewers.
  - **Storage Behavior (`store: false`):**
    - The Interactions API supports `store: false`, opting into stateless Zero Data Retention mode where Google does not persist conversation turns, interaction IDs, or chat history on its servers for subsequent API retrieval.
    - *Crucial Distinction:* Setting `store: false` disables server-side conversation history for the application, but does **not** override Google's overarching data-use terms (free tier training/human review) or temporary system abuse-monitoring retention. DOOM cannot enforce or verify provider-side retention beyond what Google's terms define.
  - **Regional Availability:**
    - Specific regional rules require a billing-enabled account in the EEA, Switzerland, and the UK. Free-tier access varies by geographic region.
- **Stored:**
  - DOOM: no disk cache, cookies or credential storage (ephemeral session, `GEMINI_INTEGRATION_SPECIFICATION.md` §4).
  - Google:
    - With `store: false`, the Interactions API does not store the interaction for later retrieval (per Google's documentation).
    - Google's data-use terms still apply as documented above.
    - Google's abuse-monitoring retention is governed by Google's terms. **DOOM cannot enforce or verify any provider retention.**
- **Retention:**
  - DOOM: none beyond the in-flight request.
  - Provider: governed by Google's terms and the account's tier. API request logging is opt-in and only for billing-enabled projects; it is configured by the user in AI Studio, not by DOOM.
- **Leaves Mac?** Yes: exactly the fields in `GEMINI_INTEGRATION_SPECIFICATION.md` §2, plus transport metadata (IP address, TLS, User-Agent).
- **Access:** Google, and network intermediaries see only TLS-encrypted traffic and the destination host.
- **Loggable?** The model ID, HTTP status, error code, duration and token counts. Never bodies, headers or keys.
- **Deletion:**
  - DOOM keeps nothing.
  - For provider-side data, the user follows Google's processes. DOOM's notice says DOOM can't recall sent text.
- **Regional note:** Google requires paid services for users in the EEA, Switzerland and the UK *[documented in the Gemini API terms, Phase 01 research]*. The user in India is not affected, but the README states this.

### 2.5 Selected text
- **Why:** it is the subject of the request.
- **Stored:** in memory only, in the flow state (`AssistantController`). Never on disk, in logs, in UserDefaults or in crash annotations.
- **Retention:**
  - Until the panel is closed, a new activation starts, or DOOM quits.
  - For failed-retryable states, it is kept so Retry can resend it, until one of those same events.
- **Leaves Mac?** Yes: once per request, to Gemini. See §2.4 for the provider terms.
- **Access:** DOOM's process.
  - It is also visible to anyone viewing the screen or recording it, because the selection is visible in the source app. DOOM does not display the selected text.
- **Loggable?** **Never.** Only its character count may be logged.
- **Deletion:** dropped references at the end of the flow.
  - Swift strings can't be securely zeroed. Memory may persist until it is reused. This is a documented limitation.

### 2.6 AI responses
- **Why:** to show the answer.
- **Stored:** in memory only (flow state, SwiftUI view).
- **Retention:** until close, a new activation, or quit. There is no history.
- **Leaves Mac?**
  - No. It is never sent to another model or service.
  - [Copy] puts it on the pasteboard only when the user clicks.
- **Access:** DOOM's process and anyone who can see the screen (§3).
- **Loggable?** **Never.** Only its character count and token usage may be logged.
- **Deletion:** dropped at the end of the flow. The same memory caveat as §2.5 applies.

### 2.7 Logs
- **Why:** diagnosing lifecycle, permission, shortcut and request outcomes.
- **Stored:**
  - macOS unified logging (`os.Logger`): the subsystem is the bundle ID, with these categories:
    - `lifecycle`
    - `configuration`
    - `shortcut`
    - `selection`
    - `gemini`
    - `keychain`
    - `permissions`
    - `panel`
  - No custom files (D-13).
- **Retention:** managed by macOS. `debug` is not persisted by default; `info`/`notice` are kept per system policy.
- **Leaves Mac?**
  - DOOM never uploads logs.
  - macOS can include logs in sysdiagnose files that the user chooses to share.
- **Access:** the user and administrators, through Console or `log`.
- **Loggable?** Only allowlisted values marked `.public`:
  - enum names
  - counts
  - durations
  - HTTP status codes
  - provider error codes
  - `OSStatus` numbers
  - model ID
  - config key names

  Everything forbidden by ARCHITECTURE §8 stays forbidden, plus app names and bundle IDs of source apps.
- **Deletion:** handled by macOS log rotation. DOOM cannot delete unified-log entries.

### 2.8 Local configuration (non-secret preferences)
- **Why:** to remember user choices.
- **Stored:** `UserDefaults` in DOOM's standard domain (P2-13, resolves DD-11). Exactly three keys:

  | Key | Type | Default |
  |---|---|---|
  | `privacyNoticeAcknowledgedVersion` | Int | 0 |
  | `copyFallbackEnabled` | Bool | false |
  | `modelIDOverride` | String? | nil (use default) |

- **Retention:** until changed or deleted.
- **Leaves Mac?** No. The model ID is sent as part of the request, as a configuration value.
- **Access:** DOOM, and any process running as the user (UserDefaults is not secret storage), which is why no secret is ever stored there.
- **Loggable?** Key names and the Bool and Int values: yes. The model ID: yes. These are not sensitive.
- **Deletion:** `defaults delete <bundle ID>` (documented). Settings resets the model with [Reset].

### 2.9 Temporary data
- **Why:** none needed.
- **Stored:** **DOOM writes no temporary files.** The ephemeral URLSession keeps nothing on disk.
- **Retention:** — (none).
- **Leaves Mac?** —
- **Access:** —
- **Loggable?** —
- **Deletion:** —
- A review grep for `FileManager`, `write(to:` and `temporaryDirectory` must find no use outside tests.

### 2.10 Crash diagnostics
- **Why:** DOOM collects none (D-24).
- **Stored:**
  - macOS may write crash reports to `~/Library/Logs/DiagnosticReports`.
  - If the user enabled "Share with app developers" or Apple analytics, macOS may send reports to Apple. Developers see those only for App Store or TestFlight apps; DOOM is neither.
  - Crash reports contain thread backtraces and register state, not general memory contents *[Assumed; Apple's crash report format]*. DOOM adds no custom crash annotations.
- **Retention:** macOS policy.
- **Leaves Mac?** Only through the user's macOS sharing choice, to Apple.
- **Access:** the user, and Apple if shared.
- **Loggable?** n/a.
- **Deletion:** the user deletes the files, or disables sharing in System Settings › Privacy & Security › Analytics & Improvements.

### 2.11 User consent
- **Why:** to make the data flow explicit before the first transmission.
- **Stored:** `privacyNoticeAcknowledgedVersion` (UserDefaults).
- **Retention:** until reset. A notice version bump requires acknowledgement again.
- **Leaves Mac?** No.
- **Access:** DOOM, and local processes running as the user.
- **Loggable?** The version number only.
- **Deletion:** `defaults delete`, after which the notice is shown again before the next request.
- **Consent points:**

  | Consent | Mechanism | Revocation |
  |---|---|---|
  | Accessibility | macOS TCC prompt after [Grant Access…] | System Settings |
  | Privacy notice | [I Understand] before the first request (E-PRIV-01) | `defaults delete` |
  | Copy Fallback | Off by default; explicit toggle with disclosure | Toggle |
  | Input Monitoring (only if `SHORTCUT_SPECIFICATION.md` §10 Option A is adopted) | macOS TCC prompt after an explicit button | System Settings |

### 2.12 Third-party dependencies
- **Why:** none are used (D-20). Apple SDK frameworks only:
  - Foundation, OSLog, SwiftUI, AppKit
  - ApplicationServices (Accessibility), Carbon (HotKey and TIS)
  - Security (Keychain)
- **Stored:** —
- **Retention:** —
- **Leaves Mac?** —
- **Access:** —
- **Loggable?** —
- **Deletion:** —
- **Rule:** any future dependency requires a recorded decision and user approval (D-20).
  - Carbon's HotKey APIs are legacy but available. Their use is justified because no modern public API registers a global hotkey without TCC (`RISK_REGISTER.md` R-03).

### 2.13 Code signing and identity
- **Why:**
  - TCC grants and Keychain access are bound to the code signature and app identifier.
  - The hardened runtime (D-18) protects DOOM's process from code injection.
- **Stored:**
  - Signing settings come from `Local.xcconfig` (gitignored) for the team ID.
  - No certificates, profiles or team IDs are in git (D-19, `check-secrets.sh`).
- **Retention:** —
- **Leaves Mac?** No (local builds). Distribution is DD-08.
- **Access:** the developer's Keychain holds the signing identity.
- **Loggable?** The team ID is not logged. Signing verification output (`codesign -dv`) may appear in human-run verification notes; it contains no secrets.
- **Deletion:** —
- **Entitlements:**
  - none beyond what Xcode automatic signing adds (application identifier, team identifier);
  - no sandbox (D-17);
  - no hardened-runtime exceptions (D-18);
  - no Apple Events;
  - no `*UsageDescription` keys. Accessibility and Input Monitoring prompts don't use usage strings, so `verify-bundle.sh` remains valid.

---

## 3. Screen capture and screen sharing (honest limits)

**Facts (Phase 01 research, C-7):**
- Apple's documentation describes `NSWindow.SharingType.none` as a legacy constant that macOS no longer honours.
- Apple DTS has stated there is **no public API to prevent screen capture**.
- Behaviour varies across ScreenCaptureKit, `screencapture`, and video-conferencing apps.

**Specification:**
1. **DOOM v1 offers no capture-exclusion feature** and makes no claim that the panel is hidden from screenshots, recordings or screen sharing (P2-12, resolving DD-07).
2. The mitigation is user-controlled: **Control+Shift+H hides the panel instantly**. A response that arrives while the panel is hidden stays hidden (`PRODUCT_BEHAVIOR.md` S-09).
3. The privacy notice and README state: "The DOOM panel can appear in screenshots, recordings and screen sharing. Hide it with Control-Shift-H."
4. **Verification required (SEC-RM-03):**
   - Record what macOS 14+/15+/26+ capture tools show with the panel visible and hidden. Use `screencapture`, the screenshot UI, a QuickTime recording, and one conferencing app if available.
   - The expected and required result is that the panel is visible when shown and absent when hidden.
5. **Any future "hide from capture" option** needs a new decision and per-version verification, and must be labelled "best effort; not guaranteed".

---

## 4. Additional security requirements [M]

- **SEC-R1:** reads of selection, clipboard and Keychain-secret data happen only during an activation, a Retry, or an explicit Settings action (INV-6).
- **SEC-R2:** the request goes to a single fixed HTTPS host. The URL is a constant, and the model ID is validated by regex (no path injection).
- **SEC-R3:** model output is rendered without opening links, loading images or executing anything (`UI_SPECIFICATION.md` §3.6).
- **SEC-R4:** no `Process`/shell execution, no AppleScript, and no dynamic code loading.
- **SEC-R5:** `scripts/check-secrets.sh` (Phase 01) continues to run. Test fixtures must not contain real-looking keys; use an obviously fake value of the right shape, for example `TEST-KEY-NOT-REAL-0000000000`.
- **SEC-R6:** the live-test API key exists only in the test-runner environment, never in files inside the repository (`GEMINI_INTEGRATION_SPECIFICATION.md` §11.3).
- **SEC-R7:** debug builds follow the same content-logging ban. There is no "verbose content logging" flag.

---

## 5. Verification (summary)

These are detailed in `ACCEPTANCE_CRITERIA.md` (SEC-, PERM-):
- unit and grep checks for logging and storage;
- a real-Mac check that nothing is written to disk (file-system activity with `fs_usage` filtered to DOOM, during a full flow, SEC-RM-01);
- a network check that only one host and one request occur per activation (Little Snitch or `nettop`, the user's choice, SEC-RM-02);
- the capture check (SEC-RM-03);
- a Keychain storage check (SEC-RM-04 as revised in Phase 03: DOOM's own status across relaunch, logged `OSStatus` values, and a `security find-generic-password` query **without `-w`**, used to confirm the item is **not** in the file-based login keychain).
