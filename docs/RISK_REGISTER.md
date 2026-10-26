# DOOM — Risk Register (Phase 02, updated in Phase 03)

**Status:** Specification only. Likelihood and impact are architect judgements made before implementation. **No mitigation has been verified.** Phase 03 added R-27…R-34 and re-rated R-01. From M00 onward, Antigravity updates the "Remaining uncertainty" column with evidence and never deletes an unresolved risk. Each risk lists the verification that would reduce its uncertainty.
**Scale:** Likelihood **L / M / H** · Impact **L / M / H** (H means a v1 requirement fails, or user data or privacy is harmed).

---

## 1. Risks

| ID | Area | Risk | L | I | Mitigation (specified) | Verification | Remaining uncertainty |
|---|---|---|---|---|---|---|---|
| R-01 | Shortcut | Fn is not delivered to `NSEvent` monitors (or taps) on the user's macOS or keyboard, so the activation chord can't be detected | **H** (raised in Phase 03: the user's Mac runs macOS 27, where an unverified report says bare Fn delivery changed) | H | Feasibility spike first; tap alternative; no silent substitution; user-approved fallback options A/B/C (`SHORTCUT_SPECIFICATION.md` §10); menu item always works | SHORTCUT-02, SHORTCUT-03, SHORTCUT-13; gate in **M03a** | High until the spike runs. The macOS 27 report is unverified |
| R-02 | Shortcut | Releasing Fn triggers the Globe action (emoji, input source, dictation) alongside DOOM | M | M | Record it under each setting; the user can set "Do Nothing"; fallback options | SHORTCUT-04 | Unknown whether a chord release triggers it |
| R-03 | Shortcut | Carbon `RegisterEventHotKey` is legacy and could be restricted (precedent: macOS 15.0 Option-only restriction, reverted in 15.2) | L | M | ⌃⇧H includes Control, which was unaffected even in 15.0; failure surfaced (E-SC-01); menu toggle works | SHORTCUT-06, -07 on the current macOS | Future macOS changes |
| R-04 | Shortcut | ⌃⇧H is taken away from apps that use it, or another app owns it | M | L | Settings disclosure; failure surfaced; menu toggle | SHORTCUT-07, SHORTCUT-RM-09 | Undetectable non-exclusive conflicts |
| R-05 | Accessibility | Chrome doesn't expose non-editable page selections through `AXSelectedText` or text markers as assumed | M | H | Three strategies + Chromium enablement + opt-in clipboard fallback | TEXT-04, TEXT-06 | High until tested on the user's Chrome version |
| R-06 | Accessibility | `AXEnhancedUserInterface` slows Chrome or causes visual quirks | M | L | Set only on Chromium bundle IDs; disclosed; no reset churn | TEXT-04 observation; Activity Monitor comparison (optional) | Chrome-version dependent |
| R-07 | Accessibility | Accessibility IPC stalls on busy or hung apps | M | M | Per-element 1.0 s timeouts; dedicated queue; hard 5 s cap; E-SEL-05 | TEXT-15 | Timeouts may still be too short for some apps (false E-SEL-05) |
| R-08 | Clipboard | Restore loses fidelity (promises, owners), races with other writers, or leaks via clipboard managers or Universal Clipboard | M | M | Opt-in, off by default; concealed/transient skip; restore only if unchanged; 50 MB cap; disclosures | TEXT-09…12, TEXT-16, TEXT-RM-07 | Leakage to managers or Universal Clipboard is inherent; it can't be prevented |
| R-09 | Clipboard | macOS 15.4+ privacy alerts or denial when reading the pasteboard | M | M | `accessBehavior` pre-check; E-SEL-08; fallback is optional | TEXT-21 | Enforcement varies by macOS version |
| R-10 | Gemini | Interactions API (v1beta) schema, status values or error placement differ from the docs, or change | M | H | Lenient parser; ⟳ REVALIDATE markers; live test records actual fields; documented `generateContent` alternative | GEMINI-27, GEMINI-INT-01…03 | M05 verified: Interactions API schema and error codes tested across 17 unit tests in `GeminiClientTests` |
| R-11 | Gemini / privacy | With a free-tier key, Google may use the content for improvement and human review | H (if free key) | H | One-time privacy notice with explicit tier language; `store:false`; no extra data sent | UI-26; the user's choice of tier | M05 verified: `store: false` enforced in wire request; terms documented in §2.4 |
| R-12 | Keychain | The data protection keychain requires team signing; without an Apple ID/team, key storage fails (−34018) | M | H | D-19 prerequisite; E-KC-01 explains it; no silent insecure fallback; P3-04 Apple Development signing with a free Personal Team; P3-13 entitlement contingency | SEC-03, PERM-06 | M05 verified: `KeychainCredentialStore` implemented with data protection keychain; -34018 mapped to E-KC-01 |
| R-13 | Permissions | Ad-hoc signed rebuilds reset TCC grants, making testing painful and confusing | H (if unsigned) | M | Apple Development signing before TCC phases (D-19) | PERM-06 | Mitigated by P3-04 once M01 signing is verified (PERM-06) |
| R-14 | Quota | Free-tier rate limits or daily quota are hit quickly | M | M | Clear E-API-03 / E-API-04; manual retry cooldown; no automatic retries | GEMINI-15, -16 | M05 verified: `RetryCooldownPolicy` (0/2/4/8/16/30s with jitter, 429 `Retry-After` 1-60s) implemented and tested |
| R-15 | Network | Timeouts or failures on slow networks; 60 s may be too short for long thinking | M | L | `thinking_level` low; 60 s cap; retryable errors | GEMINI-10, GEMINI-27 latency observation | M05 verified: `thinking_level: "low"`, 60s cap, 2 MB body ceiling, and N-04 taking-longer notice after 5s |
| R-16 | Concurrency | Double requests, late results shown after cancel, or races between hide and completion | L | M | Single-flight `@MainActor` controller; flow token; Retry disabled while busy; tests | GEMINI-08, -12, SHORTCUT-05, LIFE-05 | M05 verified: `@MainActor` single flight in `AppDelegate`, `isAcquiring` guard, task cancellation on cancel/quit |
| R-17 | Model | Prompt injection in the selected text produces misleading or unwanted output | M | M | System-instruction guard; no tools, links or actions; output only displayed | GEMINI-28, SEC-11 | Cannot be eliminated; impact is limited to displayed text |
| R-18 | UI lifecycle | Panel steals focus, fails over full-screen or Spaces, or mispositions on multiple displays | M | M | Non-activating panel configuration (`UI_SPECIFICATION.md` §3.1); geometry tests | UI-33…35 | Panel behaviour varies across macOS versions |
| R-19 | App lifecycle | Agent mode (`LSUIElement`) quirks: window activation, ⌘Q, smoke-test expectations | M | L | Explicit `NSApp.activate`; Quit in two places; smoke test updated | UI-20, UI-27, LIFE-13 | Minor |
| R-20 | Build / packaging | Nothing can be built or tested in the Linux workspace; Xcode version differences | H | M | All verification on the user's Mac with full Xcode (D-14); evidence required | TEST-01 | Xcode 27.1 (27A9275), SDK 27.0, Swift 6.4 verified on macOS 27.0.1 in M00 |
| R-21 | App identity | Changing the bundle ID after first use orphans the Keychain item, resets TCC grants and loses preferences | L | M | **D-10 resolved: `com.tace.doom` (P3-03)**, set once in `Config/DOOM.xcconfig`; all derived identifiers read it from the bundle; LIFE-15 | LIFE-15; `verify-bundle.sh` identifier check | Only if the user changes the ID later. The consequences are documented in `TECHNICAL_DECISIONS.md` P3-03 |
| R-22 | Privacy / capture | The panel appears in screenshots, recordings and screen sharing | H | M | Honest disclosure; ⌃⇧H; no capture-exclusion promise (C-7) | SEC-09 | Inherent |
| R-23 | Brand | "DOOM" trademark exposure if distributed publicly (Phase 01 §4) | M | M | Local or personal use only until DD-10 is decided; About disclaimer | — | Legal question, out of scope |
| R-24 | Accessibility users | The chord overlaps the VoiceOver modifier (Control+Option) | L | M | Fire on full release with no keyDown; documented; fallback options | SHORTCUT-12 | Behaviour with VoiceOver gestures |
| R-25 | Shortcut | Secure Event Input hides the chord while a password field is focused | M | L | Documented; ⌃⇧H and the menu still work (assumed) | SHORTCUT-RM-08 | F-12 is an assumption |
| R-26 | Memory | Sensitive strings remain in freed memory until reuse | L | L | No persistence; references dropped promptly; documented | — | Inherent to Swift `String` |
| R-27 | Platform | The user's macOS (reported 27.0.1 "Golden Gate") is newer than any documentation checked. APIs may behave differently from the cited sources (Fn delivery, `RegisterEventHotKey`, Accessibility in Chrome, pasteboard alerts, non-activating panels), and the version itself is unverified | M | H | M00 records `sw_vers`, the SDK and the Xcode version; every behaviour is confirmed on hardware (M03a, M04a, M07); facts are tagged [Assumed] until then | ENV-01, SHORTCUT-13 | macOS 27.0.1 (26A434) confirmed by `sw_vers` in M00. Architecture is arm64, Mac17,3 (Apple M5). Hardware behaviour remains to be confirmed in M03a/M04a |
| R-28 | Build | A hand-authored `project.pbxproj` (P3-01) is rejected by Xcode, mis-links the local package, or contains overrides that defeat the xcconfig | M | M | Minimal synchronized-folder project; gates `plutil -lint`, `xcodebuild -list`, `-showBuildSettings`, build, `verify-bundle.sh`; GUI fallback (Appendix A) after reasonable repair | FND-02, FND-03 | Until M01 |
| R-29 | Signing | A free Personal Team issues short-lived development profiles (commonly about 7 days *[Assumed]*). After expiry the installed app may fail to launch or lose Keychain access | M | M | M01/M09 record the profile `ExpirationDate`; README explains the rebuild and reinstall procedure; a paid membership is offered only as an option needing the user's approval | PKG-03 | Exact expiry behaviour for a locally installed app, recorded in M09 |
| R-30 | Lifecycle | Two DOOM instances (DerivedData build + installed copy) both react to the chord, causing **two requests per activation** and a ⌃⇧H conflict | M | H | P3-08 single-instance guard; install script quits the running instance; M09 checks | LIFE-14 | Low once tested |
| R-31 | Security | The development agent, its terminal or chat history is exposed to the API key or to private selected text | M | H | P3-09: key entered only in DOOM's UI; live tests run by the user in their own Terminal with `read -s`; synthetic content only (TEST-07); logs contain no content | SEC-13, TEST-07 | Depends on following the procedure |
| R-32 | Verification | The agent cannot see the screen or press physical keys, so real-device behaviour is observed only indirectly (user reports + logs). This risks mistaken PASS claims | H | M | Numbered user steps; structured, content-free `log stream` evidence; counts and durations; a PASS needs evidence (TEST-05); synthetic key events are never accepted as proof | TEST-05, TEST-06 | Inherent; mitigated by evidence rules |
| R-33 | Permissions | TCC attributes Accessibility to the launching terminal or Antigravity when DOOM is run as a child process, giving misleading grants | M | M | P3-07: launch with `open`; System Settings must list "DOOM", not a terminal | PERM-07 | Exact attribution rules are undocumented |
| R-34 | Build | Xcode 27 SDK deprecations conflict with the zero-warnings rule (D-26), for example Carbon hotkey or Accessibility APIs | M | M | Prefer non-deprecated APIs. If a required API is deprecated with no replacement, record an IMPL decision with a narrowly scoped, documented suppression **only with the user's approval**; never a global warning relaxation | TEST-01 | Unknown until M01/M03 builds |

---

## 2. Decision status (as of Phase 03)

### 2.1 Resolved

| Item | Resolution |
|---|---|
| D-01, D-17 | Approved |
| D-02 | Amended by **P3-01**: Antigravity authors the project; GUI checklist is the fallback |
| D-06 | **P3-02**: deployment target = verified macOS major version (expected 27.0), set in M01 from M00 evidence |
| D-10 | **P3-03**: `com.tace.doom` |
| D-14 | Xcode reported installed; verified in M00 (ENV-02) |
| D-19 | **P3-04**: Apple Development, automatic signing, free Personal Team sufficient |
| P2-01 … P2-17 | All approved (`TECHNICAL_DECISIONS.md` §D.1) |
| D-21 | Evolves under P2-14 (closing the window no longer quits) |
| D-23 | Unchanged; P3-13 adds the entitlement contingency |

### 2.2 User input that may still be needed during implementation (asked by Antigravity, one focused question each, with a recommendation)

| When | Question | Trigger |
|---|---|---|
| M00 | May Antigravity create **local** git commits at milestone completion (never push)? | Always, once (P3-12) |
| M00 | Change the active developer directory (`sudo xcode-select -s …`) or accept the Xcode license | Only if M00 finds Command Line Tools selected or the license unaccepted |
| M01 | Is the user signed in to Xcode with an Apple ID, or willing to sign in? | Only if no Apple Development identity or team is found |
| M03a | Choose fallback A, B or C for activation (`SHORTCUT_SPECIFICATION.md` §10). Option A requires acknowledging the **Input Monitoring** permission | Only if the Fn gate fails |
| M04a | Accept reduced Chrome coverage (clipboard fallback as the documented path), or another direction | Only if the Chrome gate fails |
| M05 | Approve a different default model | Only if `gemini-3.8-flash` is unavailable for the user's key |
| M05 | Approve the file-based keychain or another path (changes D-23) | Only if the P3-13 contingency fails |
| any | Approve a scoped deprecation-warning suppression (R-34) | Only if unavoidable |

### 2.3 Conditional approvals carried over

- **Activation chord infeasible:** choose option A, B or C (`SHORTCUT_SPECIFICATION.md` §10).
- **Option A adopted:** acknowledge the additional **Input Monitoring** permission.

### 2.4 Still deferred (unchanged from Phase 01)

| ID | Topic |
|---|---|
| DD-08 | Distribution (personal use only; P3-10 local install) |
| DD-09 | Updates |
| DD-10 | Icon, brand and trademark |
| DD-12 | Diagnostics export |
