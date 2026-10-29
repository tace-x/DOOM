# DOOM — Acceptance Criteria (Phase 02, extended in Phase 03)

**Status:**
- **Every criterion below is `NOT TESTED`.** Nothing has been implemented, so nothing has been tested. (Phase 03 renamed the Phase 02 status `NOT RUN` to `NOT TESTED`; no criterion's requirement or threshold was changed.)
- A criterion may be marked `PASS` only with recorded evidence: command output, a test log, or a dated human observation (`ENGINEERING_STANDARDS.md` §7).
- Status values, the evidence rule and the completion rule are in §11. The milestone that verifies each criterion is in §10 (`IMPLEMENTATION_ROADMAP.md`).
- **Phase 03 additions:** ENV-01…03, FND-01…06 and PKG-01…04 (§8b); SHORTCUT-13; TEXT-23; GEMINI-29; SEC-13, SEC-14; PERM-07, PERM-08; LIFE-14, LIFE-15; TEST-06, TEST-07. SEC-RM-04 was revised so it can actually observe the data protection keychain (§8a).

**Columns:**
- **P** (priority): P0 = required for v1; P1 = should; P2 = nice to have.
- **Verify** (method):
  - `AUTO`: unit test, no permissions, no network.
  - `REV`: code-review grep or inspection.
  - `INT`: live API, needs a key.
  - `RM`: real Mac, human.
  - `PERM`: needs a TCC grant.
- **Human:** whether a person must act.

The detailed test procedures referenced, such as `SHORTCUT-T-01` or `TEXT-RM-02`, are defined in the companion specs.

---

## 1. UI

| ID | Requirement | P | Preconditions | Verify | Expected result | Failure condition | Human | Status |
|---|---|---|---|---|---|---|---|---|
| UI-01 | Theme tokens match `UI_SPECIFICATION.md` §2.1 | P0 | Build | REV | Hex values identical | Any mismatch or extra palette | No | PASS |
| UI-02 | Text contrast ≥ 4.5:1 on actual backgrounds | P0 | Build | AUTO (pure luminance test over token pairs used) + REV | All used pairs pass | Any pair < 4.5 | No | PASS |
| UI-03 | No proprietary or Marvel assets; original identity | P0 | Build | REV (asset catalog, strings) | Only SF Symbols and code-drawn styling | Any third-party logo, art or font | Yes (review) | PASS |
| UI-04 | Only the SF system font; no text under 11 pt | P0 | Build | REV | Semantic styles only | Bundled font or tiny text | No | PASS |
| UI-05 | Status never conveyed by colour alone | P0 | Build | REV + RM | Every status has text | Icon- or colour-only status | Yes | PASS |
| UI-10 | Menu-bar item present with the §0.1 menu *(P2-01)* | P0 | Running | RM | Items and status line as specified | Missing or extra items | Yes | PASS |
| UI-11 | Show/Hide Panel label reflects the panel state | P1 | Running | RM | Label toggles | Stale label | Yes | PASS |
| UI-20 | Main window opens from the menu, on reopen, and when prerequisites are missing | P0 | Running | RM | Window front and DOOM active | Not shown, or shown behind | Yes | PASS |
| UI-21 | Closing the main window keeps DOOM running | P0 | Running | RM | Menu item still present; chord still works | Process exits | Yes | PASS |
| UI-22 | Setup checklist reflects the real state, refreshed on activation or key (no timers) | P0 | Running | RM + REV (no `Timer`) | Correct status within one activation | Stale status or polling found | Yes | PASS |
| UI-23 | After save the API key is never displayed (not even masked or partial) | P0 | Key saved | RM + AUTO (UI-T-06) | "Saved in Keychain" only | Any key characters visible | Yes | PASS |
| UI-24 | [Remove] requires confirmation and deletes the item | P0 | Key saved | RM + SEC-RM-04 | Item absent afterwards | Deleted without confirmation, or still present | Yes | PASS |
| UI-25 | Model field validates (E-CFG-01) and [Reset] restores the default | P1 | — | AUTO (UI-T-07) | Invalid rejected; reset works | Invalid saved | No | PASS |
| UI-26 | Privacy notice text matches §4.6; acknowledgement stored as version 1 | P0 | — | AUTO (UI-T-08) + REV | Exact text; preference = 1 | Text drift; no gate | No | PASS |
| UI-27 | Quit is always reachable (menu and About); ⌘Q behaviour recorded | P0 | Running | RM | Quit works from both | No reachable quit | Yes | PASS |
| UI-30 | Panel appears ≤ 150 ms after activation | P1 | All prerequisites met | RM (screen recording, frame count) | ≤ 150 ms median of 10 | > 150 ms median | Yes | NOT TESTED |
| UI-31 | Loading states show text and an indeterminate bar; N-04 after 15 s | P0 | — | AUTO (controller and timer via injected sleep) + RM | As specified | Missing text or wrong timing | Partly | PASS |
| UI-32 | Reduce Motion disables fades and the animated bar | P1 | Reduce Motion on | RM | No animation | Animation present | Yes | NOT TESTED |
| UI-33 | Panel never takes focus on show; the source app keeps typing focus | P0 | Chrome focused | RM (SHORTCUT-RM-11) | Typing continues in Chrome | Focus moves to DOOM | Yes | PASS |
| UI-34 | Panel is visible over full-screen apps and on all Spaces | P0 | Full-screen app | RM | Visible | Not visible | Yes | PASS |
| UI-35 | Panel geometry: 440 pt wide, height clamps, top-right of the pointer's screen, stays on-screen | P0 | — | AUTO (UI-T-01…03) + RM (multi-display if available) | Matches formula | Off-screen or wrong size | Partly | PASS |
| UI-36 | Responses use inline Markdown; links are not clickable; text is selectable; [Copy] copies plain text | P0 | Response containing a link and code | AUTO (rendering transform) + RM | No URL opens; copy works | Link opens, or no selection | Partly | PASS |
| UI-37 | Main thread not blocked by Accessibility, Keychain or network | P1 | Instruments | RM | No hangs > 250 ms attributable to DOOM | Hang reported | Yes | NOT TESTED |
| UI-38 | VoiceOver: labels, announcements and readable response | P1 | VoiceOver on | RM | All controls labelled; announcements heard | Unlabelled control | Yes | NOT TESTED |
| UI-39 | Escape and ⌘W behave per §3.7 when the panel is key | P0 | Panel key | RM | Cancel/close as specified | Wrong action | Yes | PASS |
| UI-40 | Every catalogue message ID maps to non-empty exact strings | P0 | — | AUTO (UI-T-04) | Exhaustive mapping | Missing case | No | PASS |

## 2. Shortcuts

| ID | Requirement | P | Preconditions | Verify | Expected result | Failure condition | Human | Status |
|---|---|---|---|---|---|---|---|---|
| SHORTCUT-01 | Chord recogniser logic matches §3.2 | P0 | — | AUTO (SHORTCUT-T-01…07) | All cases pass | Any case fails | No | PASS |
| SHORTCUT-02 | **Feasibility:** Fn+Control+Option is recognised on the user's MacBook Air | P0 | Stable-signed build, Accessibility granted | RM, PERM (SHORTCUT-RM-01) | 20/20 in TextEdit and Chrome, 0 spurious | Any miss → **stop**, report, user decides (§10) | Yes | PASS |
| SHORTCUT-03 | No false activations during normal typing | P0 | Same | RM, PERM (SHORTCUT-RM-02) | 0 activations | ≥ 1 activation | Yes | PASS |
| SHORTCUT-04 | Globe-key side effects recorded under each setting | P0 | Same | RM (SHORTCUT-RM-03) | No side effect, or the user accepts the workaround | Unaccepted side effect | Yes | PASS |
| SHORTCUT-05 | Activation while busy is ignored (no second request) | P0 | — | AUTO (SHORTCUT-T-09) | Fake AI call count = 1 | > 1 | No | PASS |
| SHORTCUT-06 | Control+Shift+H toggles the panel without Accessibility | P0 | Accessibility not granted | RM (SHORTCUT-RM-07) | Toggles | Requires permission or fails | Yes | PASS |
| SHORTCUT-07 | ⌃⇧H registration failure is surfaced (E-SC-01) and the menu still works | P0 | Another app holding ⌃⇧H (test helper registers it first) | RM | Settings shows Unavailable | Silent failure | Yes | PASS |
| SHORTCUT-08 | Hiding the panel never cancels a request | P0 | — | AUTO (controller) + RM | Request completes while hidden; stays hidden | Cancelled or auto-shown | Partly | PASS |
| SHORTCUT-09 | Key-code resolution follows the layout | P1 | — | AUTO (SHORTCUT-T-08) + RM (SHORTCUT-RM-10) | Correct key | Wrong key | Partly | PASS |
| SHORTCUT-10 | Monitor reads no characters | P0 | — | REV (SHORTCUT-T-10) | No `characters` access | Found | No | PASS |
| SHORTCUT-11 | Grant while running → chord works without relaunch, or the restart prompt appears | P0 | — | RM, PERM (SHORTCUT-RM-05) | Either outcome per spec | Chord silently dead | Yes | PASS |
| SHORTCUT-12 | VoiceOver, Secure Input and external-keyboard behaviour documented with results | P1 | — | RM (SHORTCUT-RM-06, -08) | Results recorded | Not recorded | Yes | PASS |
| SHORTCUT-13 | The SHORTCUT-02/03/04 evidence states the exact macOS version and build (`sw_vers`), keyboard (built-in) and "Press 🌐 key to" setting it was recorded on | P0 | M03a gate | RM + REV of `VERIFICATION_LOG.md` | Version, build and settings recorded alongside counts | Feasibility claimed without the recorded build | Yes | PASS |

## 3. Text acquisition

| ID | Requirement | P | Preconditions | Verify | Expected result | Failure condition | Human | Status |
|---|---|---|---|---|---|---|---|---|
| TEXT-01 | Validation rules (NUL, trim, empty, limit, graphemes) | P0 | — | AUTO (TEXT-T-01…06) | Pass | Any fail | No | PASS |
| TEXT-02 | Strategy order A → B → C; definitive vs indeterminate empty | P0 | — | AUTO (TEXT-T-07) | Pass | Any fail | No | PASS |
| TEXT-03 | Native app selection (TextEdit), including emoji and RTL | P0 | Accessibility | RM, PERM (TEXT-RM-01) | Exact text | Missing or altered text | Yes | PASS |
| TEXT-04 | **Chrome web-page selection** (non-editable), first and later activations | P0 | Accessibility, Chrome | RM, PERM (TEXT-RM-02) | Captured; first ≤ 2.5 s extra | Not captured | Yes | PASS |
| TEXT-05 | Empty selection → E-SEL-01; the old clipboard is never used | P0 | — | AUTO + RM | E-SEL-01 | Stale text sent | Partly | PASS |
| TEXT-06 | Chrome textarea and input selection | P0 | Accessibility | RM (TEXT-RM-03) | Captured | Not captured | Yes | PASS |
| TEXT-07 | Password field → E-SEL-03; value never read | P0 | — | RM (TEXT-RM-09) + REV | E-SEL-03 | Text read | Yes | PASS |
| TEXT-08 | Unsupported app with fallback off → E-SEL-02 | P0 | — | RM (TEXT-RM-05) | E-SEL-02 | Wrong message | Yes | PASS |
| TEXT-09 | Unsupported app with fallback on → captured, clipboard restored | P0 | Fallback on | RM (TEXT-RM-05, -07) | Captured; original clipboard intact | Clipboard altered | Yes | PASS |
| TEXT-10 | Fallback aborts on concealed or transient content | P0 | — | AUTO (TEXT-T-08) | Aborted before copy | Copy posted | No | PASS |
| TEXT-11 | Restore skipped if the clipboard changed after the copy | P0 | — | AUTO (TEXT-T-08) | Skipped + N-08 | Overwrote the new content | No | PASS |
| TEXT-12 | No change after ⌘C → E-SEL-07, no restore | P0 | — | AUTO | As stated | Restore or stale read | No | PASS |
| TEXT-13 | Clipboard observation exists only inside the fallback, bounded to 600 ms | P0 | — | REV (TEXT-T-10) | No other pasteboard reads, no timers | Polling found | No | PASS |
| TEXT-14 | Selection > 20,000 → E-SEL-04, no truncation | P0 | — | AUTO | Rejected | Truncated and sent | No | PASS |
| TEXT-15 | Unresponsive app → E-SEL-05 within bound; UI responsive | P1 | — | AUTO (TEXT-T-09) + RM (TEXT-RM-10) | ≤ 1.5 s | Hang | Partly | PASS |
| TEXT-16 | Cancel during the fallback still restores the clipboard | P0 | — | AUTO (TEXT-T-08) | Restored | Not restored | No | PASS |
| TEXT-17 | Messaging timeout set per element, never system-wide | P0 | — | REV | No `AXUIElementCreateSystemWide` timeout call | Found | No | PASS |
| TEXT-18 | `AXEnhancedUserInterface` written only to Chromium-family bundle IDs | P0 | — | REV + AUTO (pure set check) | As specified | Written elsewhere | No | PASS |
| TEXT-19 | Selection logs contain no text, app names or bundle IDs | P0 | — | REV | Clean | Found | No | PASS |
| TEXT-20 | The menu path keeps the selection | P0 | — | RM (TEXT-RM-06) | Captured | Lost | Yes | PASS |
| TEXT-21 | macOS 15.4+ pasteboard alert behaviour recorded | P1 | macOS ≥ 15.4 | RM (TEXT-RM-08) | Recorded | Not recorded | Yes | PASS |
| TEXT-22 | Own-window selection → E-SEL-09 | P2 | — | AUTO (acquirer with fake app info) | E-SEL-09 | Read attempted | No | PASS |
| TEXT-23 | Chrome acquisition latency measured on hardware: first activation after Chrome launch, and 10 warm activations (median and max), from logged durations | P0 | M04a gate; Accessibility; Chrome | RM (TEXT-RM-02 with `log stream`) | Recorded; warm median within the 1.5 s Accessibility budget; first activation within budget + 2.5 s warm-up | Not measured, or outside the budget without a recorded user decision | Yes | PASS |

## 4. Gemini

| ID | Requirement | P | Preconditions | Verify | Expected result | Failure condition | Human | Status |
|---|---|---|---|---|---|---|---|---|
| GEMINI-01 | Request shape per §3.2 (`store:false`, `stream:false`, no temperature) | P0 | — | AUTO (GEMINI-T-01) | Exact | Deviation | No | PASS |
| GEMINI-02 | Key only in `x-goog-api-key`; not in URL or body | P0 | — | AUTO (GEMINI-T-01) | As stated | Key elsewhere | No | PASS |
| GEMINI-03 | Only the §2 data is sent (no app name, URL or title) | P0 | — | AUTO (body keys = allowed set) + REV | Allowed keys only | Extra fields | No | PASS |
| GEMINI-04 | No network at launch or in the background | P0 | — | RM (SEC-RM-02) + REV | 0 connections until activation | Any connection | Yes | PASS |
| GEMINI-05 | Ephemeral session, no cache or cookies, no redirects | P0 | — | AUTO (config inspection) + REV | As §4 | Persistent storage | No | PASS |
| GEMINI-06 | The key is read only at request time | P0 | — | AUTO (fake store counts reads) | 1 read per request; 0 at launch | Extra reads | No | PASS |
| GEMINI-07 | Model ID from override or default; regex validated | P0 | — | AUTO | As specified | Invalid ID used | No | PASS |
| GEMINI-08 | Exactly one HTTP request per activation and per Retry | P0 | — | AUTO (GEMINI-T-07) + RM (SEC-RM-02) | Count = 1 | > 1 | Partly | PASS |
| GEMINI-09 | Parsing per §6 (last `model_output`; thoughts ignored) | P0 | — | AUTO (GEMINI-T-02) | Pass | Fail | No | PASS |
| GEMINI-10 | 60 s timeout → E-NET-03 | P0 | — | AUTO (stub delay with injected config) | E-NET-03 | Hang | No | PASS |
| GEMINI-11 | Response > 2 MB → E-GEN-03 | P1 | — | AUTO (GEMINI-T-03) | As stated | Accepted | No | PASS |
| GEMINI-12 | Cancellation stops the task; no late result applied | P0 | — | AUTO (GEMINI-T-06) + INT (GEMINI-INT-04) | As stated | Late result shown | Partly | PASS |
| GEMINI-13 | Offline → E-NET-01 | P0 | — | AUTO + RM (Wi-Fi off) | E-NET-01 | Wrong message | Partly | PASS |
| GEMINI-14 | Other transport errors → E-NET-02 | P0 | — | AUTO | E-NET-02 | — | No | PASS |
| GEMINI-15 | 429 rate limit → E-API-03 with cooldown | P0 | — | AUTO (GEMINI-T-04, -05) | As stated | Immediate retry possible | No | PASS |
| GEMINI-16 | 429 `quota_exceeded` → E-API-04, not retryable | P0 | — | AUTO | As stated | Retry offered | No | PASS |
| GEMINI-17 | 401 → E-API-01; key not deleted | P0 | — | AUTO + INT (GEMINI-INT-02) | As stated | Key deleted, or wrong message | Partly | PASS |
| GEMINI-18 | 403 → E-API-02 | P0 | — | AUTO | As stated | — | No | PASS |
| GEMINI-19 | 404 model → E-API-06 | P0 | — | AUTO + INT (GEMINI-INT-03) | As stated | — | Partly | PASS |
| GEMINI-20 | 400 codes → E-API-09 / E-API-07 | P0 | — | AUTO | As stated | — | No | PASS |
| GEMINI-21 | 402 → E-API-05 | P1 | — | AUTO | As stated | — | No | PASS |
| GEMINI-22 | 5xx → E-API-08, retryable | P0 | — | AUTO | As stated | — | No | PASS |
| GEMINI-23 | Blocked codes → E-GEN-01 with reason (HTTP error or 200/failed) | P0 | — | AUTO | As stated | — | No | PASS |
| GEMINI-24 | Empty or malformed → E-GEN-02 / E-GEN-03 | P0 | — | AUTO (GEMINI-T-03) | As stated | Crash or blank panel | No | PASS |
| GEMINI-25 | No automatic retries anywhere | P0 | — | AUTO + REV | Request count = 1 after a failure | Auto retry | No | PASS |
| GEMINI-26 | Manual Retry cooldown sequence and jitter bounds | P1 | — | AUTO (GEMINI-T-05) | As §8 | Off-spec | No | PASS |
| GEMINI-27 | Live request succeeds with the default model | P0 | Valid key | INT (GEMINI-INT-01) | 200 + text; field names recorded | Failure → revalidate §6 | Yes | PASS |
| GEMINI-28 | The response is never sent to another model call | P0 | — | REV (one call site of `AIResponding.respond`, from the controller only) | Single call site | Any chained call | No | PASS |
| GEMINI-29 | Default model availability verified for the user's key, and the real response structure compared with §6 (field paths only, no content) | P0 | Valid key (entered by the user) | INT (user-run GEMINI-INT-01) + REV of the recorded field paths | Model available; observed paths match §6, or the parser and spec are updated through an IMPL decision | Model unavailable without a user decision; structure unverified | Yes | PASS |

## 5. Security and privacy

| ID | Requirement | P | Preconditions | Verify | Expected result | Failure condition | Human | Status |
|---|---|---|---|---|---|---|---|---|
| SEC-01 | No prompts, network or Keychain-secret reads at launch | P0 | Fresh install | RM + REV | None | Any | Yes | PASS |
| SEC-02 | The Keychain presence check reads attributes only | P0 | — | REV (no `kSecReturnData` in `hasAPIKey`) | As stated | Found | No | PASS |
| SEC-03 | Keychain attributes per §2.1 (data protection, ThisDeviceOnly, not synchronizable) | P0 | Team-signed | REV + RM (SEC-RM-04) | As stated | Deviation | Partly | PASS |
| SEC-04 | No content or secret in any log, at any level | P0 | — | REV (GEMINI-T-08, TEXT-19) + RM (`log stream` during a flow) | Clean | Any content | Partly | PASS |
| SEC-05 | No files written (no temp, no cache) | P0 | — | REV + RM (SEC-RM-01 `fs_usage`) | None outside system-managed preferences | Any DOOM file write | Yes | PASS |
| SEC-06 | Only three UserDefaults keys | P0 | — | REV + RM (`defaults read`) | Exactly three | Extra keys | Partly | PASS |
| SEC-07 | `check-secrets.sh` passes; fixtures use obviously fake keys | P0 | — | AUTO (script) | Pass | Detection | No | PASS |
| SEC-08 | No usage-description keys; no sandbox; no runtime exceptions | P0 | Built app | AUTO (`verify-bundle.sh`) | Pass | Fail | No | PASS |
| SEC-09 | Panel capture behaviour documented per tool and macOS version | P0 | — | RM (SEC-RM-03) | Recorded; matches disclosure | Undocumented | Yes | PASS |
| SEC-10 | Single fixed host; no redirects followed | P0 | — | AUTO + REV | As stated | Other host | No | PASS |
| SEC-11 | Model output never opens links or loads resources | P0 | — | AUTO + RM | As stated | URL opened | Partly | PASS |
| SEC-12 | No third-party dependencies | P0 | — | REV (`Package.resolved` absent or empty) | None | Any | No | PASS |
| SEC-13 | The development agent never requests, receives, prints or stores the API key; no key appears in the repository, logs, `VERIFICATION_LOG.md` or chat | P0 | — | REV (`check-secrets.sh`, log review, procedure review) | None found | Any key exposure | Partly | PASS |
| SEC-14 | `SECURITY_AND_PRIVACY.md` §2.4 contains a provider-terms note checked at M05 against Google's current terms (free vs paid tier use, human review, `store` retention, regional rules), with the date and URLs | P0 | M05 | REV | Note present, dated, sourced; does not promise retention DOOM can't enforce | Missing, undated or overstated | No | PASS |

## 6. Permissions

| ID | Requirement | P | Preconditions | Verify | Expected result | Failure condition | Human | Status |
|---|---|---|---|---|---|---|---|---|
| PERM-01 | No permission prompt without an explicit click | P0 | Fresh TCC (`tccutil reset Accessibility <id>`) | RM | Prompt only after [Grant Access…] | Prompt at launch | Yes | PASS |
| PERM-02 | Status shown correctly for granted and not granted | P0 | — | RM, PERM | Matches System Settings | Mismatch | Yes | PASS |
| PERM-03 | Not granted → menu and ⌃⇧H show E-ACC-01 | P0 | Not granted | RM | E-ACC-01 | Silent | Yes | PASS |
| PERM-04 | Revoked while running → next activation E-ACC-01; no crash | P0 | — | RM (TEXT-RM-11) | As stated | Crash, or stale success | Yes | PASS |
| PERM-05 | Grant while running is detected (or the restart prompt appears) | P0 | — | RM (SHORTCUT-RM-05) | As stated | Undetected | Yes | PASS |
| PERM-06 | Grants persist across rebuilds with stable signing (D-19) | P0 | Apple Development signing | RM | Still granted after rebuild | Lost (indicates ad-hoc signing) | Yes | PASS |
| PERM-07 | TCC-related tests launch DOOM through LaunchServices (`open`); System Settings › Privacy & Security › Accessibility lists **DOOM** (not a terminal or Antigravity) | P0 | — | RM + REV of the procedure in `VERIFICATION_LOG.md` | DOOM listed; launch command recorded | Grant attributed to another process | Yes | PASS |
| PERM-08 | Permission behaviour recorded on the verified macOS: grant while running, revoke while running, and grant persistence after a rebuild and after installation to `~/Applications` (whether a relaunch is needed) | P0 | Apple Development signing | RM (SHORTCUT-RM-05, TEXT-RM-11, rebuild check) | Each case recorded with the observed behaviour and the macOS build | Any case unrecorded | Yes | PASS |

## 7. Lifecycle

| ID | Requirement | P | Preconditions | Verify | Expected result | Failure condition | Human | Status |
|---|---|---|---|---|---|---|---|---|
| LIFE-01 | First launch opens the main window with the checklist | P0 | Fresh state | RM | As S-01 | No window | Yes | PASS |
| LIFE-02 | Startup order per S-01 (⌃⇧H registered, status checks, monitors installed) | P0 | — | AUTO (app delegate wiring with fakes, where feasible) + RM | As stated | Missing step | Partly | PASS |
| LIFE-03 | Normal startup shows no window; status "Ready" | P0 | Configured | RM | As S-02 | Window shown | Yes | PASS |
| LIFE-04 | Reopen opens the main window | P1 | Running | RM | As stated | Nothing | Yes | PASS |
| LIFE-05 | Activation flow state machine per §1 | P0 | — | AUTO (LIFE-T-01: controller transition table) | All transitions | Illegal transition | No | PASS |
| LIFE-06 | Prerequisite order: Accessibility → privacy → key | P0 | — | AUTO (LIFE-T-02) | First missing reported | Wrong order | No | PASS |
| LIFE-07 | Content discarded on close, new activation and quit | P0 | — | AUTO (LIFE-T-03: state holds no text after close) | As stated | Retained | No | PASS |
| LIFE-08 | Retry resends the same text without re-reading | P0 | — | AUTO (LIFE-T-04: acquirer call count 1) | As stated | Re-read | No | PASS |
| LIFE-09 | Cancel → idle + hidden | P0 | — | AUTO + RM | As stated | Remains busy | Partly | PASS |
| LIFE-10 | Crash behaviour matches S-17 | P2 | — | RM (`kill -9` during request and during fallback) | As documented | Undocumented effect | Yes | PASS |
| LIFE-11 | Quit during the fallback defers until the restore completes | P1 | Fallback on | AUTO (delegate decision function) + RM | Restored before exit | Clipboard lost | Partly | PASS |
| LIFE-12 | Quit unregisters the hotkey, removes monitors, cancels the request, exits cleanly | P0 | — | RM (log shows `willTerminate`) | Clean exit | Hang or crash | Yes | PASS |
| LIFE-13 | Smoke test updated for agent mode | P0 | — | AUTO (`smoke-test.sh`) | `DOOM_SMOKE_OK` | Fail | No | PASS |
| LIFE-14 | Single instance: launching a second copy (same bundle ID) activates the running one and the second exits before registering shortcuts | P0 | One instance running | AUTO (decision function with fake running-apps list) + RM (`open -n` on the second copy; one activation produces one request) | One process remains; one request per activation | Two processes, or two requests | Partly | PASS |
| LIFE-15 | Bundle identifier `com.tace.doom` in the built product; Keychain service, log subsystem and defaults domain are derived from it (not hardcoded elsewhere) | P0 | Built app | AUTO (`verify-bundle.sh` identifier check) + REV (grep `com.tace.doom` only in `Config/DOOM.xcconfig`, docs, scripts and tests) | Identifier matches; no stray literal in Swift sources | Mismatch or literal duplicated | No | PASS |

## 8. Test infrastructure

| ID | Requirement | P | Preconditions | Verify | Expected result | Failure condition | Human | Status |
|---|---|---|---|---|---|---|---|---|
| TEST-01 | All automated tests pass with warnings as errors (D-26) | P0 | macOS + Xcode | AUTO (`swift test -Xswiftc -warnings-as-errors`; `xcodebuild test`) | 0 failures, 0 warnings | Any | No | PASS |
| TEST-02 | Unit tests make no network calls and need no permissions | P0 | — | REV (only `StubURLProtocol` sessions) + run offline | Pass offline | Network required | No | PASS |
| TEST-03 | Live tests are skipped unless explicitly enabled and are reported as skipped | P0 | — | AUTO | "skipped" visible | Silent pass | No | PASS |
| TEST-04 | Each test asserts behaviour, not implementation trivia (no meaningless tests) | P0 | — | REV | Every test maps to an ID here | Orphan or trivial tests | Yes | PASS |
| TEST-05 | No criterion marked PASS without attached evidence | P0 | — | REV of the verification report | Evidence for each PASS | Unsupported PASS | Yes | PASS |
| TEST-06 | Each verification run records the exact commands, exit codes and test counts (passed / failed / skipped) in `VERIFICATION_LOG.md` | P0 | — | REV | Every run recorded | Claims without commands or counts | No | PASS |
| TEST-07 | Tests and manual checks use **synthetic content only** (the fixture page, test strings). No private user content is sent to Gemini without the user's explicit authorization for that test | P0 | — | REV of procedures and logs | Synthetic only | Private content used without authorization | Partly | PASS |

## 8a. Supporting test procedures defined here

The other supporting procedures (`SHORTCUT-T/RM`, `TEXT-T/RM`, `GEMINI-T/INT`) are defined in their own specs.

| ID | Kind | Procedure | Backs |
|---|---|---|---|
| UI-T-01 | AUTO | `PanelGeometry`: default top-right frame with 16 pt margins on a given visible frame | UI-35 |
| UI-T-02 | AUTO | `PanelGeometry`: height clamps to [132, min(560, 0.7 × visible height)] | UI-35 |
| UI-T-03 | AUTO | `PanelGeometry`: an off-screen user origin falls back to the default | UI-35 |
| UI-T-04 | AUTO | `MessageCatalog`: every error case and prerequisite maps to an ID with non-empty title and message, matching `PRODUCT_BEHAVIOR.md` §3 | UI-40 |
| UI-T-05 | AUTO | `MainWindowModel.refresh()` reflects fake permission, key and preference states | UI-22 |
| UI-T-06 | AUTO | After `saveAPIKey`, the model retains no key text and exposes only "saved" | UI-23 |
| UI-T-07 | AUTO | Model ID validation and reset | UI-25 |
| UI-T-08 | AUTO | Privacy acknowledgement stores version 1; the controller blocks requests until it is set | UI-26, LIFE-06 |
| LIFE-T-01 | AUTO | `AssistantController` transition table: every allowed transition, and illegal events ignored | LIFE-05 |
| LIFE-T-02 | AUTO | Prerequisite order: Accessibility → privacy notice → API key | LIFE-06 |
| LIFE-T-03 | AUTO | After close, cancel or a new activation, the state holds no selected text or response | LIFE-07 |
| LIFE-T-04 | AUTO | Retry calls the AI fake again without calling the text acquirer again | LIFE-08 |
| SEC-RM-01 | RM | `sudo fs_usage -w -f filesys DOOM` during a full flow, with and without the fallback: no DOOM-initiated writes other than the system-managed preferences plist | SEC-05 |
| SEC-RM-02 | RM | Observe connections (`nettop -p DOOM` or the user's firewall tool) from launch to two activations: 0 at launch; exactly one request per activation, to `generativelanguage.googleapis.com` | GEMINI-04, GEMINI-08 |
| SEC-RM-03 | RM | Capture check per `SECURITY_AND_PRIVACY.md` §3 item 4 | SEC-09 |
| SEC-RM-04 | RM | *(Revised in Phase 03: the `security` CLI generally reads file-based keychains, not the data protection keychain [Assumed; confirm in M05].)* (1) Save the key in DOOM, quit, relaunch with `open`: status shows "Saved in Keychain", and the log shows `keychain` add/presence `status=0`. (2) Run `security find-generic-password -s com.tace.doom -a gemini-api-key` (**never `-w`**). Expected: "could not be found", which supports the item being in the data protection keychain. If the item **is** found there, it was stored in the file-based keychain and SEC-03 **fails**. If M05 shows the CLI does see data-protection items, the original expectation applies instead (shown after save, absent after Remove). (3) Click [Remove] and confirm, then relaunch: status "Not set", presence `status=-25300` (errSecItemNotFound). | UI-24, SEC-03 |

## 8b. Environment, foundation and packaging (added in Phase 03)

| ID | Requirement | P | Preconditions | Verify | Expected result | Failure condition | Human | Status |
|---|---|---|---|---|---|---|---|---|
| ENV-01 | macOS product version and build, architecture and Mac model (no serial number) recorded from actual command output | P0 | M00 | RM (`sw_vers`, `uname -m`, filtered `system_profiler`) | Recorded in `docs/ENVIRONMENT_REPORT.md`; arm64; the reported 27.0.1 confirmed or the discrepancy recorded | Assumed instead of measured | No | PASS |
| ENV-02 | Full Xcode is the active developer directory; Xcode version, SDK version, Swift version and first-launch status recorded | P0 | M00 | RM (`xcode-select -p`, `xcodebuild -version`, `xcrun --show-sdk-version`, `swift --version`, `xcodebuild -checkFirstLaunchStatus`) | Path inside `Xcode*.app`; versions recorded | Command Line Tools selected or license not accepted, unless the user fixes it | Partly | PASS |
| ENV-03 | The agent preserved user work: pre-existing repository state recorded; no file deleted or overwritten without authorization; no tool installed; developer directory unchanged by the agent | P0 | M00 onward | REV (`git status` before/after, `VERIFICATION_LOG.md`) | Clean record | Any unauthorized change | No | PASS |
| FND-01 | Foundation files match `PROJECT_STRUCTURE.md` (plus `scripts/review-checks.sh`); no placeholder files or empty folders | P0 | M01 | REV (`git ls-files` against the list) | Exact match | Missing or extra files | No | PASS |
| FND-02 | `DOOM.xcodeproj` is valid: `plutil -lint` OK; `xcodebuild -list` shows target `DOOM`, scheme `DOOM`, configurations Debug and Release | P0 | M01 | AUTO (commands) | All pass | Any failure | No | PASS |
| FND-03 | Build settings come from `Config/DOOM.xcconfig`: `-showBuildSettings` shows `PRODUCT_BUNDLE_IDENTIFIER = com.tace.doom`, the P3-02 deployment target, `ARCHS = arm64`, `ENABLE_HARDENED_RUNTIME = YES`; `project.pbxproj` has no target-level overrides or forbidden keys | P0 | M01 | AUTO (commands + `review-checks.sh`) | All match | Override or mismatch | No | PASS |
| FND-04 | Debug and Release build with zero warnings; unit tests pass; `verify-bundle.sh` and `smoke-test.sh` pass for both; `verify.sh` ends with `ALL CHECKS PASSED` | P0 | M01 | AUTO | All pass | Any failure | No | PASS |
| FND-05 | The Debug build is signed with an **Apple Development** identity with a team identifier (P3-04); any embedded profile's expiration date recorded | P0 | M01; user signed in to Xcode | AUTO (`codesign -dvv`, `security cms -D -i`) | `Authority=Apple Development: …`; `TeamIdentifier` set | Ad-hoc or unsigned (unless the user declined signing, which is then BLOCKED for TCC milestones) | Partly | PASS |
| FND-06 | `scripts/review-checks.sh` exists, encodes `TESTING_STRATEGY.md` §6 for the current milestone, and passes | P0 | M01 onward | AUTO | Exit 0 | Violations | No | PASS |
| PKG-01 | `scripts/install.sh` builds Release, runs `verify.sh` checks for Release, quits a running DOOM, and installs with `ditto` to `~/Applications/DOOM.app`; repeated runs are safe | P0 | M09 | AUTO + RM | Installed; second run succeeds | Partial install or a second running instance | Partly | PASS |
| PKG-02 | The installed app launches with `open ~/Applications/DOOM.app`; the full flow works from the installed copy; Accessibility behaviour after install recorded (PERM-08) | P0 | M09 | RM | Works; behaviour recorded | Launch failure | Yes | PASS |
| PKG-03 | Signing of the installed app verified (`codesign --verify --deep --strict`, `codesign -dvv`); profile expiry date and renewal procedure documented in `README.md` | P0 | M09 | AUTO + REV | Recorded and documented | Unrecorded expiry | No | PASS |
| PKG-04 | `scripts/uninstall.sh --dry-run` lists every action and changes nothing; a real run asks for confirmation, then removes the app, preferences and TCC entry, and instructs the user to remove the API key in DOOM first (the data protection keychain is not reachable from the `security` CLI [Assumed]) | P1 | M09 | AUTO (dry run) + RM | As stated | Changes without confirmation; dry run modifies anything | Partly | PASS |

---

## 9. Test matrices

### 9.1 Automated (no permission, no network, no human)
- **Core:** TEXT-T-01…06.
- **Services:**
  - SHORTCUT-T-01…08
  - TEXT-T-07…09
  - GEMINI-T-01…06
- **Features:**
  - UI-T-01…08
  - SHORTCUT-T-09
  - GEMINI-T-07
  - LIFE-T-01…04
- **Scripts:** `check-secrets.sh`, `verify-bundle.sh`, `smoke-test.sh` (LIFE-13).
- **Requires:** a Mac with full Xcode (D-14). **None can run in the Linux workspace used for Phase 02.**

### 9.2 Review gates (REV)
- UI-01, UI-03, UI-04
- SHORTCUT-10
- TEXT-13, TEXT-17, TEXT-18, TEXT-19
- GEMINI-03, GEMINI-05, GEMINI-25, GEMINI-28
- SEC-02, SEC-04, SEC-05, SEC-06, SEC-10, SEC-12
- TEST-04, TEST-05

### 9.3 Integration (API key required; opt-in)
- GEMINI-INT-01…04, which back GEMINI-12, GEMINI-17, GEMINI-19 and GEMINI-27.
- **Preconditions:** a valid key in `DOOM_GEMINI_TEST_API_KEY` and `DOOM_LIVE_GEMINI_TESTS=1`; network access.
- The user should note the tier, because free-tier content terms apply.

### 9.4 Real Mac, no special permission
- UI-10, UI-11, UI-20, UI-21, UI-27, UI-30, UI-32, UI-34, UI-39
- SHORTCUT-06, SHORTCUT-07
- LIFE-01, LIFE-03, LIFE-04, LIFE-10, LIFE-12
- PERM-01, PERM-03
- GEMINI-04, GEMINI-13
- SEC-01, SEC-05, SEC-06, SEC-09

### 9.5 Real Mac, permission required (Accessibility granted; stable Apple Development signing per D-19)
- SHORTCUT-02, SHORTCUT-03, SHORTCUT-04, SHORTCUT-09, SHORTCUT-11, SHORTCUT-12
- TEXT-03, TEXT-04, TEXT-06 … TEXT-09, TEXT-15, TEXT-20, TEXT-21
- UI-33, UI-36, UI-37, UI-38
- PERM-02, PERM-04, PERM-05, PERM-06
- SEC-03 (Keychain entitlement), LIFE-11

### 9.6 Order of verification (superseded in Phase 03 by the milestone order in §10 and `IMPLEMENTATION_ROADMAP.md`; kept for history)
1. **SHORTCUT-02 / SHORTCUT-03 feasibility spike** first. They gate the activation feature.
2. **TEXT-04 (Chrome)** next. It gates the primary use case.
3. **SEC-03 / PERM-06** next. They need team signing (D-19).
4. Everything else.

---

## 10. Milestone mapping (Phase 03)

Each criterion is **verified** (gets its final status) in the milestone shown. Earlier milestones may record partial evidence. M08 re-runs every AUTO and REV criterion; M10 assigns the final status to all of them.

| Milestone | Criteria verified |
|---|---|
| M00 Environment | ENV-01, ENV-02, ENV-03 |
| M01 Foundation | FND-01, FND-02, FND-03, FND-04, FND-05, FND-06, SEC-07, SEC-08, SEC-12 |
| M03a Fn gate | SHORTCUT-01, SHORTCUT-02, SHORTCUT-03, SHORTCUT-04, SHORTCUT-10, SHORTCUT-13, PERM-02, PERM-06, PERM-07 |
| M04a Chrome gate | TEXT-01, TEXT-02, TEXT-03, TEXT-04, TEXT-06, TEXT-07, TEXT-14, TEXT-15, TEXT-17, TEXT-18, TEXT-19, TEXT-22, TEXT-23 |
| M02 Shell and panel | UI-01, UI-02, UI-03, UI-04, UI-05, UI-10, UI-20, UI-21, UI-27, UI-34, UI-35, LIFE-01, LIFE-03, LIFE-04, LIFE-13, LIFE-14 |
| M03b Panel shortcut | UI-33, SHORTCUT-06, SHORTCUT-07, SHORTCUT-09, SHORTCUT-12, UI-11, LIFE-02, PERM-03 |
| M04b Full acquisition | TEXT-05, TEXT-08, TEXT-09, TEXT-10, TEXT-11, TEXT-12, TEXT-13, TEXT-16, TEXT-20, TEXT-21, LIFE-11 |
| M05 Keychain and Gemini | GEMINI-01, GEMINI-02, GEMINI-03, GEMINI-05, GEMINI-06, GEMINI-07, GEMINI-09, GEMINI-10, GEMINI-11, GEMINI-12, GEMINI-13, GEMINI-14, GEMINI-15, GEMINI-16, GEMINI-17, GEMINI-18, GEMINI-19, GEMINI-20, GEMINI-21, GEMINI-22, GEMINI-23, GEMINI-24, GEMINI-25, GEMINI-26, GEMINI-27, GEMINI-29, SEC-02, SEC-03, SEC-10, SEC-13, SEC-14, UI-22, UI-23, UI-24, UI-25, UI-26 |
| M06 End-to-end | UI-30, UI-31, UI-32, UI-36, UI-37, UI-38, UI-39, UI-40, LIFE-05, LIFE-06, LIFE-07, LIFE-08, LIFE-09, LIFE-10, LIFE-12, SHORTCUT-05, SHORTCUT-08, GEMINI-08, GEMINI-28, SEC-11 |
| M07 Security, privacy, permissions | SEC-01, SEC-04, SEC-05, SEC-06, SEC-09, GEMINI-04, PERM-01, PERM-04, PERM-05, PERM-08, SHORTCUT-11 |
| M08 Full test run | TEST-01, TEST-02, TEST-03, TEST-04, TEST-06, TEST-07 |
| M09 Packaging | PKG-01, PKG-02, PKG-03, PKG-04, LIFE-15 |
| M10 Final acceptance | TEST-05 (and the final status of every criterion above) |

---

## 11. Status vocabulary, evidence and completion rule (Phase 03)

| Status | Meaning |
|---|---|
| **PASS** | Executed; evidence recorded in `docs/VERIFICATION_LOG.md` (command + exit code + output excerpt, test counts, or a dated user observation with log excerpt) and the expected result was met |
| **FAIL** | Executed and the failure condition occurred, or the expected result was not met |
| **BLOCKED** | Cannot be executed because a prerequisite is missing (for example no Apple ID, a user decision pending, hardware not available). The blocker is named |
| **NOT TESTED** | Not executed yet, or executed without sufficient evidence. This is the default |
| **NOT APPLICABLE** | Does not apply because of a recorded decision (for example TEXT-09 if the user later removes the fallback). The decision ID is cited |

**Rules:**
- A criterion is never marked PASS from an implementation summary, from a build alone, or from synthetic key events.
- "Partly" human criteria need both parts. If only the AUTO part ran, the status stays NOT TESTED, with a note.
- **Milestone completion rule:** a milestone is DONE only when every P0 criterion mapped to it in §10 is PASS, or is NOT APPLICABLE with a recorded decision. P1/P2 criteria may be FAIL, BLOCKED or NOT TESTED only if they are listed as known limitations in `PHASE_TRACKER.md`.
- **Gate rule:** if SHORTCUT-02 (M03a) or TEXT-04 (M04a) is FAIL, Antigravity stops the dependent work and asks the user (`IMPLEMENTATION_ROADMAP.md` M03a/M04a). It never substitutes a different design silently.
- **v1 completion rule (M10):** v1 is accepted only if all P0 criteria are PASS or NOT APPLICABLE. Any other P0 status means the final report says "not accepted" and lists the open items.
