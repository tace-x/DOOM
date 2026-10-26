# DOOM — Implementation Roadmap (Phase 03)

| | |
|---|---|
| **Status** | Approved plan. **Every milestone is NOT STARTED.** No code, project, build or test exists. |
| **Date** | 2026-10-24 |
| **Executed by** | Antigravity, the **sole development agent** after handoff. The Orchestration AI is no longer involved. Nothing in this roadmap waits for it. |
| **Companions** | `ANTIGRAVITY_MASTER_PROMPT.md` (operating rules), `TESTING_STRATEGY.md` (commands, protocols, review greps), `ACCEPTANCE_CRITERIA.md` (criteria + §10 milestone mapping + §11 completion rule), `PHASE_TRACKER.md` (status), `TECHNICAL_DECISIONS.md` (§D Phase 03 decisions, §E implementation log), `RISK_REGISTER.md` |

---

## 0. Baseline (confirmed by the user; facts marked "verify" are checked in M00)

| Item | Value |
|---|---|
| Product | DOOM, native macOS assistant, personal use (no App Store, no public distribution) |
| Hardware | Apple Silicon MacBook Air (arm64 only) |
| macOS | Reported 27.0.1 "Golden Gate". **Verify** (ENV-01) |
| Xcode | Reported installed. **Verify** (ENV-02) |
| Bundle ID | `com.tace.doom`. Permanent: it is the Keychain service, log subsystem, preferences domain and TCC identity (P3-03) |
| Architecture | Xcode app target `DOOM` + local package `DoomKit` (`DoomCore`, `DoomServices`, `DoomFeatures`); non-sandboxed; hardened runtime; settings in `Config/DOOM.xcconfig` |
| App type | Menu-bar agent (`LSUIElement`), main window on demand, floating non-activating response panel |
| Activation | **Fn + Control + Option** (modifier chord, `NSEvent` monitors; verified on hardware in M03a) |
| Panel toggle | **Control + Shift + H** (Carbon hotkey, no permission) |
| Selection | macOS Accessibility (strategies A/B/C, Chromium enablement); clipboard fallback optional, **off by default** |
| AI | Google Gemini Interactions API, `store:false`, default model `gemini-3.8-flash` (availability verified in M05), **one request per activation**, no automatic retry, no secondary model call |
| Credentials | Data protection keychain, `WhenUnlockedThisDeviceOnly`, account `gemini-api-key` |
| Capture | No capture-hiding in v1; honest disclosure |
| Design | Original dark metallic surfaces, silver typography, restrained emerald accent; no third-party or Marvel assets |
| Signing | Apple Development, automatic, free Personal Team acceptable (P3-04) |

---

## 1. Execution order and dependencies (P3-06)

```
M00 Environment ─► M01 Foundation + project + signing
                     │
                     ├─► M03a Fn chord gate ──(FAIL → stop, user decides)
                     │       │
                     │       └─► M04a Chrome selection gate ──(FAIL → stop, user decides)
                     │               │
                     │               └─► M02 Menu-bar shell, theme, main window, panel, single instance
                     │                       │
                     │                       └─► M03b ⌃⇧H + AssistantController skeleton + menu activation
                     │                               │
                     │                               └─► M04b Full acquisition + clipboard fallback
                     │                                       │
                     │                                       └─► M05 Keychain + key UI + privacy notice + GeminiClient
                     │                                               │
                     │                                               └─► M06 End-to-end flow
                     │                                                       │
                     │                                                       └─► M07 Security, privacy, permissions
                     │                                                               │
                     │                                                               └─► M08 Full test run + regressions
                     │                                                                       │
                     │                                                                       └─► M09 Release build, install, README
                     │                                                                               │
                     │                                                                               └─► M10 Final acceptance report
```

The milestone **numbers** follow the product structure (M02 shell, M03 shortcuts, M04 selection). The **execution order** is risk-first: the two feasibility gates (M03a, M04a) run before UI work. A gate failure stops only the work that depends on it.

---

## 2. Rules that apply to every milestone

- **Start:** set the milestone to IN PROGRESS in `PHASE_TRACKER.md`, re-read its section here and the criteria mapped to it (`ACCEPTANCE_CRITERIA.md` §10).
- **Scope:** create only the files the milestone lists, plus files from `MODULE_CONTRACTS.md` §7 that it owns. No placeholders for later milestones. No third-party dependencies.
- **Evidence:** every check goes into `docs/VERIFICATION_LOG.md` in the `TESTING_STRATEGY.md` §2 format.
- **Review checks:** update `scripts/review-checks.sh` for the milestone (`TESTING_STRATEGY.md` §6.2) **before** writing the code it governs.
- **Finish:** run `scripts/verify.sh` (last line `ALL CHECKS PASSED`), update `PHASE_TRACKER.md`, record deviations as IMPL-xx in `TECHNICAL_DECISIONS.md` §E, commit locally if the user consented (P3-12), then **continue immediately** with the next milestone. Never wait for external review.
- **User involvement** is limited to: physical real-Mac steps and confirmations, granting permissions, entering the API key in DOOM, `sudo` commands, and material product decisions (one focused question, with a recommendation). The user never writes code, edits project files, diagnoses builds or assembles the app.
- **Stop conditions:** a gate failure (M03a, M04a), a decision listed in `RISK_REGISTER.md` §2.2, or a blocker that only the user can remove. Record it as BLOCKED in `PHASE_TRACKER.md`, ask one question, and continue with any independent work while waiting.

---

## M00 — Environment verification and work preservation

1. **ID and name:** M00, Environment verification and work preservation.
2. **Objective:** Establish the real facts of the user's Mac and repository from actual command output. Preserve all existing user work. Change nothing on the system.
3. **Prerequisites:** The user has copied the `docs/` folder into a new repository folder on the Mac and opened that folder in Antigravity (`HANDOFF_README.md`). Antigravity can run terminal commands.
4. **Inputs:** All documents in `docs/`, especially `HANDOFF_README.md`, `ANTIGRAVITY_MASTER_PROMPT.md`, this roadmap, `TESTING_STRATEGY.md`.
5. **File and module changes:** Create `docs/ENVIRONMENT_REPORT.md` (Appendix C template) and `docs/VERIFICATION_LOG.md` (Appendix D). Update `docs/PHASE_TRACKER.md` and the "Remaining uncertainty" column of R-20 and R-27 in `RISK_REGISTER.md`. **No other file is created, modified or deleted.**
6. **Ordered tasks:**
   1. Record the repository state: `pwd` (report with `~` instead of the home path), `ls -la`, `git rev-parse --is-inside-work-tree 2>&1`. If it is a repository: `git status --short`, `git branch --show-current`, `git log --oneline -5`.
   2. If files other than `docs/` already exist, **list them and stop to ask** whether they belong to DOOM. Never delete, move or overwrite them.
   3. Run the environment commands (§9) one by one and capture output and exit codes.
   4. Classify each finding as **Conclusive now** or **Needs a real build or run** (Appendix C table). Examples: the macOS version is conclusive; whether Fn reaches `NSEvent` monitors is not.
   5. Compare with the reported baseline. If `sw_vers` differs from 27.0.1, record the actual value. P3-02 then uses the actual major version; this is not a failure.
   6. If the active developer directory is Command Line Tools, the Xcode license is not accepted, or first-launch components are missing: give the user the exact command to run themselves (for example `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, `sudo xcodebuild -license accept`, `sudo xcodebuild -runFirstLaunch`), explain why, and wait for confirmation. **Never run these yourself.**
   7. Write `ENVIRONMENT_REPORT.md` and the first `VERIFICATION_LOG.md` entries.
   8. Ask the git question (P3-12): "May I make local git commits when each milestone is complete? I will never push. Recommended: yes." Record the answer in `PHASE_TRACKER.md`.
   9. Update `PHASE_TRACKER.md` (M00 DONE or BLOCKED) and continue.
7. **Automated tests:** None (no code exists).
8. **Manual tests:** None required. Ask the user a question only if a value cannot be determined (for example, whether the keyboard in use is the built-in one).
9. **Build and verification commands (CMD-ENV):**
   ```bash
   sw_vers; sw_vers -buildVersion; uname -m
   system_profiler SPHardwareDataType | grep -E 'Model Name|Model Identifier|Chip|Memory'   # never serial or UUID
   xcode-select -p
   ls -d /Applications/Xcode*.app 2>/dev/null
   xcodebuild -version
   xcodebuild -showsdks | grep -i macos
   xcrun --sdk macosx --show-sdk-version
   xcodebuild -checkFirstLaunchStatus; echo "firstLaunchStatus exit=$?"
   swift --version
   git --version
   df -h . | tail -1
   defaults read com.apple.HIToolbox AppleFnUsageType 2>&1          # Globe key setting; meaning confirmed in M03a
   security find-identity -v -p codesigning | grep -c 'Apple Development'   # count only; names are not recorded
   defaults read "/Applications/Google Chrome.app/Contents/Info" CFBundleShortVersionString 2>&1
   grep -o 'SOFTWARE LICENSE AGREEMENT FOR macOS [A-Za-z ]*' "/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf" 2>/dev/null | head -1   # marketing name, informational
   ```
10. **Acceptance criteria:** ENV-01, ENV-02, ENV-03.
11. **Failure conditions:** Not arm64. No full Xcode installed. Xcode not usable (license or first launch) and the user declines to fix it. Unknown pre-existing files whose status the user hasn't clarified. The SDK version is lower than the macOS major version (P3-02 then uses the SDK version, and this is recorded).
12. **Recovery strategy:** For each failure, give the user the exact one-line fix to run, or the App Store step for installing Xcode, and mark M00 BLOCKED until it is confirmed. Never install anything. If the marketing-name command fails, record "not determinable"; it is informational only.
13. **Documentation updates:** `ENVIRONMENT_REPORT.md`, `VERIFICATION_LOG.md`, `PHASE_TRACKER.md`, `RISK_REGISTER.md` (R-20, R-27 uncertainty).
14. **Definition of done:** ENV-01…03 PASS with evidence. Every row of the Appendix C table is filled with actual output or "not determinable". The git consent answer is recorded. No file outside `docs/` was created or changed.
15. **Next milestone:** M01.

---

## M01 — Foundation, Xcode project and signing

1. **ID and name:** M01, Foundation, Xcode project and signing.
2. **Objective:** Implement the approved Phase 01 foundation exactly (`PROJECT_STRUCTURE.md`), authored entirely by Antigravity (P3-01), with stable Apple Development signing (P3-04), so that every later milestone builds, tests and runs from scripts.
3. **Prerequisites:** M00 DONE. Full Xcode active. Git consent answer known.
4. **Inputs:** `PROJECT_STRUCTURE.md` (§1–§3, §2.7), `ENGINEERING_STANDARDS.md`, `ARCHITECTURE.md`, `TECHNICAL_DECISIONS.md` D-01…D-26, P3-01…P3-04, Appendix B of this roadmap, the M00 facts (macOS major version, SDK version).
5. **File and module changes:** Every file in `PROJECT_STRUCTURE.md` §1 (including `scripts/review-checks.sh`), plus the git-ignored `Config/Local.xcconfig`. Modules: `DoomCore`, `DoomFeatures` (no `DoomServices` yet, per D-03). The deployment target is filled in from M00 (P3-02).
6. **Ordered tasks:**
   1. If there is no repository, run `git init` (record it). Never rewrite existing history.
   2. Write `.gitignore` first. Verify with `git check-ignore -v build .build Config/Local.xcconfig DoomKit/.build DoomKit/.swiftpm` (use patterns without trailing slashes, a lesson learned in Phase 01).
   3. Write `DoomKit/Package.swift` (`platforms: [.macOS("<major>.0")]`), the `DoomCore` and `DoomFeatures` sources and the tests from `PROJECT_STRUCTURE.md` §2.3–§2.6.
   4. Run CMD-PKG-TEST and iterate until there are 0 failures and 0 warnings.
   5. Write `Config/DOOM.xcconfig` (§3 table, with `com.tace.doom` and the P3-02 target) and `Config/Local.xcconfig.example`.
   6. Write the app sources (`DOOM/DOOMApp.swift`, `DOOM/AppDelegate.swift`) and `DOOM/Assets.xcassets`.
   7. Author `DOOM.xcodeproj` per **Appendix B**. Pass gates B-1…B-6 in order. If a gate fails after reasonable repair (at most three focused attempts per gate, each recorded), switch to the **Appendix A** GUI fallback and record IMPL-xx.
   8. Write the scripts (`build.sh`, `verify-bundle.sh`, `smoke-test.sh`, `check-secrets.sh`, `review-checks.sh` with the §6.1 rules plus R-FUTURE, and `verify.sh` ending with `ALL CHECKS PASSED`). Run `chmod +x scripts/*.sh` and check syntax with `bash -n scripts/*.sh`.
   9. **Signing (P3-04):**
      - a. If M00 found ≥ 1 Apple Development identity, derive the team ID from the certificate subject's OU: `security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject`. If several teams appear, ask the user which to use, showing only team names.
      - b. If none was found, ask the user (human step): "Open Xcode › Settings › Accounts, click +, and sign in with your Apple ID. A free account is enough; no paid membership is needed." Then read the team list with `defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier` (or `IDEProvisioningTeams` on older Xcode) *[key names assumed; record which exists]*.
      - c. If the team ID still cannot be determined, as a last resort ask the user to open `DOOM.xcodeproj` in Xcode, select the DOOM target › Signing & Capabilities, and pick their team. Then move the resulting `DEVELOPMENT_TEAM` out of `project.pbxproj` into `Local.xcconfig` and restore the file (gate B-3 must pass again).
      - d. Write `Config/Local.xcconfig` with `DEVELOPMENT_TEAM = <team ID>` and `CODE_SIGN_IDENTITY = Apple Development`. The file is git-ignored; confirm with `git check-ignore`.
      - e. If the user has no Apple ID and doesn't want one: ask the one focused question with the trade-off (ad-hoc signing means Accessibility must be re-granted after every rebuild and the data protection keychain will fail, R-12/R-13). Then mark FND-05 BLOCKED. M03a can still proceed with re-grants, but M05 cannot pass SEC-03.
   10. Run CMD-BUILD-DEBUG (with `-allowProvisioningUpdates`), CMD-SIGN, CMD-VERIFY-BUNDLE, CMD-SMOKE, CMD-BUILD-RELEASE, and finally CMD-VERIFY.
   11. Launch with CMD-LAUNCH and ask the user one question: "Do you see a DOOM window with a silver wordmark and the status 'Core systems online'?"
   12. Commit locally if consented (`git add -A && git commit -m "M01: foundation"`, after `git status` shows no ignored files staged).
7. **Automated tests:** The Phase 01 suites (`AppConfigurationTests`, `LaunchOptionsTests`, `AppContextTests`, `HomeViewModelTests`; about 25–30 cases), the scripts and CMD-PROJECT.
8. **Manual tests:** The window check in task 11 (visual).
9. **Build and verification commands:** CMD-PKG-TEST, CMD-PROJECT, CMD-BUILD-DEBUG, CMD-BUILD-RELEASE, CMD-SIGN, CMD-VERIFY-BUNDLE, CMD-SMOKE, CMD-SECRETS, CMD-REVIEW, CMD-VERIFY, and `(cd DoomKit && xcodebuild -list)` to record the package scheme name for CMD-PKG-XCTEST.
10. **Acceptance criteria:** FND-01…06, SEC-07, SEC-08, SEC-12. Partial evidence: LIFE-15 (identifier in the plist), TEST-01 (the suite so far).
11. **Failure conditions:** Any warning; any test failure; a gate B-x still failing after fallback; `verify-bundle.sh` failure (wrong identifier, sandbox present, usage keys, non-arm64); ad-hoc signature when an Apple ID is available; `DEVELOPMENT_TEAM` found in a tracked file.
12. **Recovery strategy:** Fix the root cause (never relax a check). For project problems, use Appendix B diagnostics, then the Appendix A fallback. For signing problems with `-allowProvisioningUpdates`, record the exact error and ask the user to confirm they are signed in to Xcode. If a deprecation warning from the SDK cannot be avoided, follow R-34 (ask the user before any scoped suppression).
13. **Documentation updates:** `VERIFICATION_LOG.md`; `PHASE_TRACKER.md`; `TECHNICAL_DECISIONS.md` §E (any deviation, for example the fallback being used or the actual package scheme name); `RISK_REGISTER.md` R-28, R-29 (profile expiry date), R-12/R-13.
14. **Definition of done:** All mapped criteria PASS (FND-05 may be BLOCKED only by an explicit user choice, recorded). `verify.sh` prints `ALL CHECKS PASSED`. The user has confirmed the window. The work is committed if consented.
15. **Next milestone:** M03a.

---

## M03a — Activation chord feasibility gate (Fn + Control + Option)

1. **ID and name:** M03a, Activation chord feasibility gate.
2. **Objective:** Prove on the user's real MacBook Air and verified macOS build that Fn + Control + Option is recognised reliably, with no false activations, **before** any other feature depends on it. If it is not, stop and let the user decide (`SHORTCUT_SPECIFICATION.md` §10). No silent substitution.
3. **Prerequisites:** M01 DONE. Apple Development signing (FND-05), or the user's recorded acceptance of re-grants. Chrome and TextEdit available.
4. **Inputs:** `SHORTCUT_SPECIFICATION.md` (§3 recogniser, §8 matrix, §9 procedures, §10 fallbacks), `MODULE_CONTRACTS.md` §3–§4.2, `PRODUCT_BEHAVIOR.md` (Accessibility prerequisite), `UI_SPECIFICATION.md` (setup checklist row), `SECURITY_AND_PRIVACY.md` §2.7.
5. **File and module changes:**
   - Add the `DoomServices` module and the `DoomServicesTests` target to `Package.swift` (D-03: first real use).
   - DoomCore: `Domain/Shortcut.swift`, `Domain/Permission.swift`, `Contracts/ShortcutMonitoring.swift`, `Contracts/PermissionChecking.swift`.
   - DoomServices: `Shortcuts/ChordRecognizer.swift`, `Shortcuts/SystemShortcutMonitor.swift` (chord part only: `NSEvent` global and local monitors for `flagsChanged` and `keyDown`), `SystemPermissionChecker.swift`.
   - DoomFeatures: the Accessibility row (status text + [Grant Access…] + [Open System Settings]) added to the existing Home view model and view. M02 carries it into `MainWindowModel`.
   - App target: wiring in `AppDelegate`. Activation is **log-only** in this milestone (`shortcut chord.fired`, notice level).
   - Update `scripts/review-checks.sh` (M03a rules).
6. **Ordered tasks:**
   1. Update the review rules (R-OWN-MONITOR, R-OWN-TRUST, R-NO-CHARS, R-NO-TAP; remove `addGlobalMonitorForEvents` and `AXIsProcessTrusted` from R-FUTURE).
   2. Write `ChordRecognizerTests` (SHORTCUT-T-01…07) first, then `ChordRecognizer` (pure: flags + timestamps in, events out; 2.0 s chord window).
   3. Implement `SystemShortcutMonitor` (chord part) and `SystemPermissionChecker` (`AXIsProcessTrusted`; the prompt variant only on an explicit click).
   4. Add the Accessibility row; wire it in `AppDelegate`. Log `permissions accessibility trusted=` at launch and on window activation (no timers).
   5. Add `debug` logs for recogniser transitions (flag names only) and `notice` logs for `chord.fired`.
   6. Run CMD-VERIFY.
   7. **Real-Mac gate (protocol in `TESTING_STRATEGY.md` §5):**
      - a. Launch with `open`. The user clicks [Grant Access…] and enables DOOM in System Settings. Verify that the list shows "DOOM" (PERM-07) and that the row updates (PERM-02).
      - b. SHORTCUT-RM-01: 20 presses in TextEdit and 20 in Chrome. Expect 20/20 `chord.fired` in each and 0 spurious.
      - c. SHORTCUT-RM-02: 2 minutes of normal typing with Control/Option shortcuts and Fn + arrows. Expect 0 `chord.fired`.
      - d. SHORTCUT-RM-03: 5 presses under each "Press 🌐 key to" setting. Ask whether the Globe action appeared, and record `AppleFnUsageType` for each.
      - e. SHORTCUT-RM-04: the standard function keys setting, on and off.
      - f. PERM-06: rebuild (CMD-BUILD-DEBUG), relaunch, and confirm the grant persists without re-granting.
      - g. Record the macOS version and build, the keyboard and the settings (SHORTCUT-13).
   8. **Gate decision:**
      - All of SHORTCUT-02/03 PASS → continue. SHORTCUT-04 side effects are recorded, and the user accepts the workaround or it is listed as a limitation.
      - Otherwise **STOP the activation feature.** Collect measurements: does `flagsChanged` arrive with `maskSecondaryFn`, and with keycode 63? What hit rate, which miss patterns, any spurious fires? Present them with options A, B and C (§10) and a recommendation, and ask **one** question. Do not implement any option before the answer. Option A needs an explicit acknowledgement of the Input Monitoring permission. M04a can still proceed, because the menu item path doesn't depend on the chord; for M04a, activation is triggered from a temporary Debug-only menu item recorded as IMPL-xx and removed in M03b.
   9. Update the tracker; commit if consented.
7. **Automated tests:** SHORTCUT-T-01…07 (`ChordRecognizerTests`); Phase 01 suites; review checks.
8. **Manual tests:** SHORTCUT-RM-01, -02, -03, -04; the PERM-02/06/07 checks above.
9. **Build and verification commands:** CMD-PKG-TEST, CMD-BUILD-DEBUG, CMD-VERIFY-BUNDLE, CMD-LAUNCH, CMD-LOG-SHOW (counting `chord.fired` with `grep -c 'chord.fired' build/logs/SHORTCUT-RM-01-textedit.log`), CMD-LOG-STREAM for diagnosis, CMD-VERIFY.
10. **Acceptance criteria:** SHORTCUT-01, -02, -03, -04, -10, -13; PERM-02, PERM-06, PERM-07.
11. **Failure conditions:** Fewer than 20/20 activations in either app; any spurious activation; grant attributed to a terminal; grant lost after rebuild (signing problem); any key characters read (SHORTCUT-10).
12. **Recovery strategy:** For a recogniser bug (a unit test reproduces the miss), fix it and re-run. For platform non-delivery, follow the gate decision above (user decision, no substitution). For a lost grant, re-check CMD-SIGN; ad-hoc signing means going back to M01 task 9. For TCC attribution, relaunch with `open`.
13. **Documentation updates:** `VERIFICATION_LOG.md` (counts per app, per setting), `PHASE_TRACKER.md`, `RISK_REGISTER.md` R-01/R-02/R-27 (measured results), `SHORTCUT_SPECIFICATION.md` §2 facts table (F-x statuses from Assumed to Verified/Refuted, with date and build), §E entries if anything deviates.
14. **Definition of done:** All mapped P0 criteria PASS. Or: the gate failed, the user chose an option, the decision is recorded in §E and the chosen option is scheduled in M03b.
15. **Next milestone:** M04a.

---

## M04a — Chrome selection feasibility gate

1. **ID and name:** M04a, Chrome selection feasibility gate.
2. **Objective:** Prove on hardware that DOOM reads non-editable Chrome web-page selections (and native TextEdit selections) through Accessibility, with measured latency, before UI investment.
3. **Prerequisites:** M03a DONE (or gate-stopped with the Debug menu trigger in place). Accessibility granted to DOOM. Chrome installed (version recorded in M00).
4. **Inputs:** `TEXT_ACQUISITION_SPECIFICATION.md` (§2 strategies, §3 Chromium enablement, §6 threading and timeouts, §8 procedures), `MODULE_CONTRACTS.md` §3.2, §4.3.1, P3-14.
5. **File and module changes:**
   - DoomCore: `Domain/SourceApplication.swift`, `Domain/SelectedText.swift`, `Validation/SelectionValidator.swift`, `Errors/TextAcquisitionError.swift`, `Contracts/TextAcquiring.swift`, `Configuration/SelectionLimits.swift`.
   - DoomServices: `Selection/AccessibilitySelectionReader.swift`, `Selection/SystemTextAcquirer.swift` (Accessibility strategies only; the fallback is added in M04b).
   - Tests: `SelectionValidatorTests`, `SelectionStrategyTests`, `SelectionTimeoutTests`.
   - `ManualTests/selection-test-page.html` (P3-14; `TESTING_STRATEGY.md` §9).
   - App target: temporary diagnostic wiring, so that `chord.fired` triggers acquisition and logs `selection acquire.result` (count and duration only). It is recorded as IMPL-xx and **replaced in M03b** by `AssistantController`.
   - Review rules R-OWN-AX, R-AX-SYSWIDE-TIMEOUT, R-ENHANCED-UI.
6. **Ordered tasks:**
   1. Update the review rules.
   2. Write the validator tests (TEXT-T-01…06) and `SelectionValidator`, including the 20,000-grapheme limit with no truncation.
   3. Write the strategy tests (TEXT-T-07, TEXT-T-09) against a fake attribute provider, then the reader: per-element messaging timeout 1.0 s (never system-wide), 1.5 s budget, `AXEnhancedUserInterface = true` only for the Chromium bundle-ID set with a warm-up of ≤ 2.5 s, 5 s hard cap, dedicated off-main execution.
   4. Write the fixture page, with counts computed in the page.
   5. Run CMD-VERIFY.
   6. **Real-Mac gate:**
      - TEXT-RM-01: TextEdit with the word, paragraph, emoji and RTL files Antigravity wrote to `build/manual/`.
      - TEXT-RM-02: Chrome fixture passages, with the **first** activation right after Chrome launches and then 10 warm activations; compare logged `chars` with the page counts and record `duration_ms` (TEXT-23).
      - TEXT-RM-03: `<textarea>` and `<input>`.
      - TEXT-RM-04: Chrome PDF viewer, result recorded.
      - TEXT-RM-09: the password field must give `outcome=secureField` and read nothing.
      - TEXT-RM-10: an unresponsive app. Ask the user to agree first; use `kill -STOP <pid>` on a TextEdit instance Antigravity opened, then `kill -CONT`.
   7. **Gate decision:**
      - TEXT-04 PASS → continue.
      - FAIL → stop the dependent work. Present the measurements (which strategies returned what; whether `AXEnhancedUserInterface` was accepted; timings) and ask one question. Options: (a) continue with Chrome page selections supported only through the opt-in clipboard fallback (M04b), as a documented limitation; (b) investigate a further Accessibility approach in a time-boxed spike, if one is identified; (c) another direction from the user.
   8. Update the tracker; commit if consented.
7. **Automated tests:** TEXT-T-01…07, TEXT-T-09; the pure Chromium-set check (TEXT-18).
8. **Manual tests:** TEXT-RM-01, -02, -03, -04, -09, -10.
9. **Build and verification commands:** CMD-PKG-TEST, CMD-BUILD-DEBUG, CMD-LAUNCH, `open -a "Google Chrome" ManualTests/selection-test-page.html`, CMD-LOG-SHOW, CMD-VERIFY.
10. **Acceptance criteria:** TEXT-01, -02, -03, -04, -06, -07, -14, -15, -17, -18, -19, -22, -23.
11. **Failure conditions:** A logged count differs from the page count; Chrome page selection not captured; a password value read; acquisition exceeds the 5 s cap or blocks the main thread; selection text appearing in any log.
12. **Recovery strategy:** For count mismatches, check the trimming and grapheme rules against the validator tests and fix the cause. For Chrome failures, use the gate decision above. For timeouts, use the recorded measurements to tune within the spec budgets; changing a budget is an IMPL decision with evidence.
13. **Documentation updates:** `VERIFICATION_LOG.md` (counts, durations, Chrome version), `PHASE_TRACKER.md`, `RISK_REGISTER.md` R-05/R-06/R-07, `TEXT_ACQUISITION_SPECIFICATION.md` facts (Assumed → Verified/Refuted, with Chrome version), §E for the diagnostic wiring.
14. **Definition of done:** The mapped P0 criteria PASS, or the gate failed and the user's decision is recorded and scheduled.
15. **Next milestone:** M02.

---

## M02 — Menu-bar shell, theme, main window, panel foundation, single instance

1. **ID and name:** M02, Menu-bar shell and panel foundation.
2. **Objective:** Turn the foundation into the approved menu-bar agent: `LSUIElement`, the status menu, the on-demand main window (evolved from Home), the theme, the non-activating panel with geometry, and the single-instance guard.
3. **Prerequisites:** M04a DONE (or gate-stopped with a recorded decision).
4. **Inputs:** `PRODUCT_BEHAVIOR.md` §0.1 (menu), §5 lifecycle; `UI_SPECIFICATION.md` §2 tokens, §3 panel, §4 main window; `MODULE_CONTRACTS.md` §5.2, §5.4–§5.6, §6; P2-01, P2-12, P2-14, P3-08.
5. **File and module changes:**
   - DoomFeatures: `DesignSystem/DoomTheme.swift` (extended to the UI-spec tokens), `Panel/{DoomPanel,PanelController,PanelGeometry,PanelView}.swift`, `MainWindow/{MainWindowModel,MainWindowView}.swift` (replacing `Home/*`, with tests migrated), `Menu/StatusMenuContent.swift`, and the single-instance decision function.
   - App target: `MenuBarExtra` in `DOOMApp.swift`; lifecycle changes in `AppDelegate` (window close keeps running; reopen opens the window; the duplicate-instance check runs **before** any monitor is installed).
   - Config: `INFOPLIST_KEY_LSUIElement = YES`.
   - `smoke-test.sh` updated for agent mode (LIFE-13).
   - Tests: `PanelGeometryTests`, `MainWindowModelTests`, `SingleInstancePolicyTests`, `ThemeContrastTests`.
   - The checklist shows **only** the Accessibility row; the privacy and key rows arrive in M05 (no placeholders).
6. **Ordered tasks:**
   1. Update the review rules (R-OWN-PANEL, R-LSUIELEMENT, R-NO-CAPTURE).
   2. Write tests for the geometry (UI-T-01…03), contrast (UI-02), single instance (LIFE-14) and main-window model; then implement.
   3. Implement the theme, main window, menu (only the items whose functions exist: Show/Hide Panel, Open DOOM, Quit DOOM; "Ask DOOM About Selection" arrives in M03b) and the panel (non-activating, all Spaces, full-screen auxiliary, top-right of the pointer's screen, 440 pt).
   4. The menu's Show Panel shows the panel's idle state as defined in `UI_SPECIFICATION.md` §3.
   5. Update the smoke test, then run CMD-VERIFY.
   6. **Real Mac:**
      - UI-10, UI-20, UI-21, UI-27 (menu, window, close keeps running, quit from the menu and About; record ⌘Q behaviour).
      - UI-34 (panel over a full-screen app and across Spaces) and UI-35 (on each available display).
      - LIFE-01 (fresh state), LIFE-03, LIFE-04.
      - LIFE-14: run `open -n` on a second copy (for example the Release build) while the Debug build runs. Exactly one DOOM process remains (`pgrep -x DOOM | wc -l`).
   7. Update the tracker; commit if consented.
7. **Automated tests:** UI-T-01…03, `MainWindowModelTests` (from `HomeViewModelTests`), `SingleInstancePolicyTests`, `ThemeContrastTests`, smoke test.
8. **Manual tests:** The real-Mac list in task 6, plus a visual review against UI-01, UI-03, UI-04, UI-05.
9. **Build and verification commands:** CMD-PKG-TEST, CMD-BUILD-DEBUG, CMD-BUILD-RELEASE (needed for the LIFE-14 second copy), CMD-SMOKE, CMD-LAUNCH, `pgrep -x DOOM | wc -l`, CMD-LOG-SHOW, CMD-VERIFY.
10. **Acceptance criteria:** UI-01, -02, -03, -04, -05, -10, -20, -21, -27, -34, -35; LIFE-01, -03, -04, -13, -14.
11. **Failure conditions:** A Dock icon appears; the window doesn't come to the front; closing the window quits DOOM; the panel takes focus or misplaces; two instances survive; any colour-only status; any proprietary asset.
12. **Recovery strategy:** Fix against the spec. For panel behaviour that differs on macOS 27, record measurements and try the spec-allowed panel configuration variants. If none satisfies UI-34, record FAIL with evidence and ask the user whether to accept it as a limitation.
13. **Documentation updates:** `VERIFICATION_LOG.md`, `PHASE_TRACKER.md`, R-18/R-19/R-30, §E (any deviation).
14. **Definition of done:** The mapped P0 criteria PASS; `verify.sh` passes; the Home files are removed and their tests migrated (no dead code).
15. **Next milestone:** M03b.

---

## M03b — Control + Shift + H, AssistantController skeleton, menu activation

1. **ID and name:** M03b, Panel shortcut and controller skeleton.
2. **Objective:** Add the Carbon ⌃⇧H toggle, the `AssistantController` skeleton that owns the activation flow (activation → prerequisite check → panel), and the "Ask DOOM About Selection" menu item. This replaces the M04a diagnostic wiring.
3. **Prerequisites:** M02 DONE.
4. **Inputs:** `SHORTCUT_SPECIFICATION.md` §4 (hotkey, key-code resolution), §9; `MODULE_CONTRACTS.md` §4.1, §5.1; `PRODUCT_BEHAVIOR.md` §1 (states), §3 (E-ACC-01, E-SC-01). If the M03a gate chose option A, B or C, that decision's design applies here.
5. **File and module changes:**
   - DoomServices: the Carbon part of `Shortcuts/SystemShortcutMonitor.swift`; `Shortcuts/KeyCodeResolver.swift`.
   - DoomFeatures: `Assistant/AssistantController.swift` (states idle → checking prerequisites → acquiring; errors use catalog entries E-ACC-01 and E-SC-01), `Assistant/MessageCatalog.swift` (only the entries used so far), and the menu item.
   - App target: remove the M04a diagnostic wiring (close its IMPL entry).
   - Tests: `KeyCodeResolverTests` (SHORTCUT-T-08), `AssistantControllerTests` (initial transitions, LIFE-02 wiring where feasible).
   - Review rules R-OWN-HOTKEY, R-OWN-TIS.
6. **Ordered tasks:**
   1. Update the review rules.
   2. Write the tests, then implement the resolver, hotkey registration (failure → `panelToggle = .unavailable(status:)`, surfaced in the main window as E-SC-01) and the controller skeleton.
   3. Implement the interim successful-acquisition behaviour: until M06, success ends the flow (log the count and duration, return to idle, hide the panel), recorded as IMPL-xx.
   4. Run CMD-VERIFY.
   5. **Real Mac:**
      - SHORTCUT-RM-07 (⌃⇧H without Accessibility: ask the user's permission to reset via CMD-TCC-RESET, or test before granting on a fresh build identity if one is available).
      - SHORTCUT-07 (registration failure: a small helper registers ⌃⇧H first; the helper lives under `ManualTests/` and is recorded as IMPL-xx).
      - SHORTCUT-RM-09 (conflicts), SHORTCUT-RM-10 (one non-QWERTY layout), SHORTCUT-RM-08 and -06 (Secure Input, VoiceOver: SHORTCUT-12).
      - UI-33 / SHORTCUT-RM-11 (the chord with Chrome focused: Chrome keeps focus).
      - UI-11 (menu label), PERM-03 (not granted → E-ACC-01 through the menu and the chord path).
   6. Update the tracker; commit if consented.
7. **Automated tests:** SHORTCUT-T-08, initial `AssistantControllerTests`, all earlier suites.
8. **Manual tests:** SHORTCUT-RM-06, -07, -08, -09, -10, -11; the PERM-03 and UI-11 checks.
9. **Build and verification commands:** CMD-PKG-TEST, CMD-BUILD-DEBUG, CMD-LAUNCH, CMD-LOG-SHOW, CMD-TCC-RESET (only with consent), CMD-VERIFY.
10. **Acceptance criteria:** UI-11, UI-33; SHORTCUT-06, -07, -09, -12; LIFE-02; PERM-03.
11. **Failure conditions:** ⌃⇧H needs a permission; a registration failure is silent; the panel steals focus; the wrong key on a non-QWERTY layout; the diagnostic wiring is still present.
12. **Recovery strategy:** If Carbon registration is refused on macOS 27 (R-03), record the `OSStatus`, keep the menu toggle working, and ask the user whether to choose another panel shortcut (product decision).
13. **Documentation updates:** `VERIFICATION_LOG.md`, `PHASE_TRACKER.md`, R-03/R-04/R-24/R-25, `SHORTCUT_SPECIFICATION.md` facts F-12 and others with results, §E.
14. **Definition of done:** The mapped P0 criteria PASS; no diagnostic wiring remains; `verify.sh` passes.
15. **Next milestone:** M04b.

---

## M04b — Full text acquisition with the optional clipboard fallback

1. **ID and name:** M04b, Full text acquisition.
2. **Objective:** Complete `SystemTextAcquirer`: the opt-in, off-by-default clipboard fallback with snapshot and restore, all selection errors surfaced through the controller and catalog, the Copy Fallback toggle, and the menu path that preserves the selection.
3. **Prerequisites:** M03b DONE.
4. **Inputs:** `TEXT_ACQUISITION_SPECIFICATION.md` §4 (fallback algorithm, 600 ms wait, 50 MB cap, concealed and transient types, restore-if-unchanged), §5 errors; `UI_SPECIFICATION.md` §4.6 (toggle); `PRODUCT_BEHAVIOR.md` §3 (E-SEL-01…09, N-08); P2-05, P2-13.
5. **File and module changes:**
   - DoomServices: `Selection/ClipboardFallback.swift` (internal `PasteboardAccess` protocol + system wrapper + `KeyEventPosting` closure), the final `Selection/SystemTextAcquirer.swift`, `UserDefaultsPreferences.swift` (`copyFallbackEnabled` only at this point).
   - DoomCore: `Contracts/PreferencesStoring.swift`.
   - DoomFeatures: the Copy Fallback toggle with its disclosure text (UI §4.6, toggle part), the catalog entries for E-SEL-xx, and `applicationShouldTerminate` deferral support (LIFE-11).
   - Tests: `ClipboardFallbackTests` (TEXT-T-08), acquirer tests for the empty and stale cases.
   - Review rules R-OWN-PASTEBOARD, R-OWN-CGEVENT, R-NO-POLL, R-USERDEFAULTS.
6. **Ordered tasks:**
   1. Update the review rules.
   2. Write `ClipboardFallbackTests` against the in-memory fake, then implement the fallback (all pasteboard calls on the main actor; `Task.sleep` waits; no timers).
   3. Implement the toggle (default off) and the terminate deferral.
   4. Run CMD-VERIFY.
   5. **Real Mac** (fixture page, TextEdit, Google Docs or another app without Accessibility selection support, using synthetic text):
      - TEXT-RM-05 (fallback off → E-SEL-02; on → captured, clipboard restored).
      - TEXT-RM-06 (menu path).
      - TEXT-RM-07 (rich-content restore fidelity).
      - TEXT-RM-08 (macOS 27 pasteboard alert behaviour).
      - TEXT-05 RM part (empty selection → E-SEL-01; the old clipboard is not used).
      - LIFE-11 (quit during the fallback).
   6. Update the tracker; commit if consented.
7. **Automated tests:** TEXT-T-08 and TEXT-T-10 (review), acquirer tests (TEXT-05, -10, -11, -12, -16), preferences tests.
8. **Manual tests:** TEXT-RM-05, -06, -07, -08; the TEXT-05 RM part; LIFE-11.
9. **Build and verification commands:** CMD-PKG-TEST, CMD-BUILD-DEBUG, CMD-LAUNCH, CMD-LOG-SHOW, CMD-DEFAULTS, CMD-VERIFY.
10. **Acceptance criteria:** TEXT-05, -08, -09, -10, -11, -12, -13, -16, -20, -21; LIFE-11.
11. **Failure conditions:** The clipboard is altered after a fallback; any pasteboard read outside the fallback; polling; a concealed item copied; restore overwrites newer content; the toggle defaults to on.
12. **Recovery strategy:** Fidelity problems: record which types are lost, fix within the spec, or record them as a known limitation with the user's acknowledgement. A macOS 27 pasteboard alert: record the behaviour and show E-SEL-08 as specified.
13. **Documentation updates:** `VERIFICATION_LOG.md`, `PHASE_TRACKER.md`, R-08/R-09, `TEXT_ACQUISITION_SPECIFICATION.md` facts, §E.
14. **Definition of done:** The mapped P0 criteria PASS; the fallback is off by default after a fresh install (CMD-DEFAULTS shows no key, or `0`).
15. **Next milestone:** M05.

---

## M05 — Keychain, key UI, privacy notice, Gemini client, documentation revalidation

1. **ID and name:** M05, Keychain and Gemini integration.
2. **Objective:** Store the API key securely (entered only in DOOM's UI), show the one-time privacy notice, implement `GeminiClient` against the **current** Interactions API, verify that the default model is available for the user's key and record the real response structure, and write the dated provider-terms privacy note.
3. **Prerequisites:** M04b DONE. Apple Development signing (FND-05) for the data protection keychain. The user has a Gemini API key (from Google AI Studio) and knows its tier.
4. **Inputs:** `GEMINI_INTEGRATION_SPECIFICATION.md` (all, especially the ⟳ REVALIDATE items, §6 parsing, §7 errors, §8 retry cooldown, §9 Keychain), `SECURITY_AND_PRIVACY.md` §2.1–§2.4, `UI_SPECIFICATION.md` §4 (key field, model field, privacy sheet), `PRODUCT_BEHAVIOR.md` §4 (system instruction), P2-06…P2-11, P3-09, P3-13.
5. **File and module changes:**
   - DoomCore: `Domain/{ModelID,APIKey,Generation}.swift`, `Errors/{GenerationError,CredentialStoreError}.swift`, `Contracts/{CredentialStoring,AIResponding}.swift`, `Configuration/{GeminiConfiguration,PrivacyNotice}.swift`.
   - DoomServices: `KeychainCredentialStore.swift`, `Gemini/{GeminiClient,InteractionsRequestBuilder,InteractionsResponseParser,GeminiErrorMapper}.swift`; `UserDefaultsPreferences` gains `privacyNoticeAcknowledgedVersion` and `modelIDOverride`.
   - DoomFeatures: the key section (Save / Saved in Keychain / [Remove] with confirmation), the model field with [Reset], `MainWindow/PrivacyNoticeView.swift`, the privacy and key checklist rows, and the catalog entries for E-API, E-NET, E-GEN, E-KC and E-CFG.
   - Tests: the Gemini test files (`TESTING_STRATEGY.md` §4), `GeminiLiveTests` (opt-in), UI-T-05…08.
   - Conditional: `Config/DOOM.entitlements` (P3-13 only).
   - Review rules R-OWN-SECITEM, R-NO-RETURNDATA-PRESENCE, R-OWN-NET, R-HOST, R-NO-SHARED-SESSION.
6. **Ordered tasks:**
   1. **Revalidate the documentation (before coding).** Fetch Google's current Gemini API docs for: the Interactions endpoint and request fields; `store`; `generation_config` (`thinking_level`, `max_output_tokens`); the response schema and `status` values; the error shape and codes, including where blocked codes appear; `Retry-After`; the models list (whether `gemini-3.8-flash` is still stable and still rejects `minimal` thinking); and the terms (free vs paid tier use, human review, regional rules, retention). Record each ⟳ item as Confirmed or Changed, with the URL and date, in `VERIFICATION_LOG.md`. A material change (for example the endpoint or the default model) is an IMPL decision, plus a user question if it changes product behaviour. If web access is unavailable, record "revalidation NOT TESTED" and rely on the live test.
   2. Update the review rules.
   3. Write the tests (GEMINI-T-01…08, UI-T-05…08), then implement the builder, parser (lenient), error mapper, client (ephemeral session, fixed host, no redirects, 60 s timeout, one attempt), Keychain store (presence check without `kSecReturnData`), preferences and UI.
   4. Run CMD-VERIFY (live tests show as skipped).
   5. **Live tests, run by the user (P3-09; `TESTING_STRATEGY.md` §7):** GEMINI-INT-01 (default model, recording field paths: GEMINI-27, GEMINI-29), INT-02 (invalid key: use an obviously fake 39-character string such as `AIza` followed by 35 `X`, not a real key), INT-03 (non-existent model), INT-04 (cancel). Antigravity reads the log; it never sees the key.
   6. If the observed paths differ from §6, update the parser and spec through IMPL-xx and re-run.
   7. **Keychain on the real Mac (SEC-RM-04 as revised):** the user enters the key in DOOM's field and saves; quit and relaunch; check the status and `keychain op` logs; run CMD-KEYCHAIN-CLI and record the result; [Remove] → confirm → relaunch → "Not set". If `status=-34018` appears, apply **P3-13** (entitlements file with only `keychain-access-groups`), rebuild, re-test, and record IMPL-xx. If it still fails, ask the user (a file-based keychain would change D-23).
   8. **Privacy note:** update `SECURITY_AND_PRIVACY.md` §2.4 with a dated, sourced provider-terms note (SEC-14). Do not promise retention DOOM can't enforce. Confirm that the privacy-sheet text (UI §4.6) still matches the terms; any text change needs the user's approval, because P2-11 is a product decision.
   9. Real Mac: UI-22 (checklist reflects the real state on activation, no timers), UI-23 (no key characters shown after save), UI-24, UI-25, UI-26 (privacy acknowledgement stored as `1`: CMD-DEFAULTS).
   10. Update the tracker; commit if consented (confirm first that `check-secrets.sh` passes).
7. **Automated tests:** GEMINI-T-01…08, UI-T-04 (catalog entries so far), UI-T-05…08, the Keychain store's pure parts (query construction), opt-in live tests (skipped by default).
8. **Manual tests:** The user-run live tests; SEC-RM-04; the UI-22…26 checks.
9. **Build and verification commands:** CMD-PKG-TEST, CMD-LIVE (by the user), CMD-BUILD-DEBUG, CMD-SIGN (entitlements check if P3-13 is applied), CMD-LAUNCH, CMD-LOG-SHOW, CMD-KEYCHAIN-CLI, CMD-DEFAULTS, CMD-SECRETS, CMD-VERIFY.
10. **Acceptance criteria:** GEMINI-01…03, -05…07, -09…27, -29; SEC-02, -03, -10, -13, -14; UI-22, -23, -24, -25, -26.
11. **Failure conditions:** Default model unavailable (404/`model_not_found`); the response structure doesn't match and can't be parsed; the key appears anywhere outside the Keychain (SEC-13); −34018 not resolved by P3-13; any automatic retry; a request to any other host.
12. **Recovery strategy:**
    - **Model unavailable:** ask the user one question, recommending the closest documented stable model from the revalidated list (for example `gemini-3.6-flash` or `gemini-3.5-flash-lite`), and record the decision. Never switch silently.
    - **Schema change:** update the parser through IMPL-xx, with tests from the observed (content-free) structure.
    - **Keychain:** P3-13, then ask the user.
    - **Key exposure:** stop. Tell the user to revoke the key in Google AI Studio, remove the exposure, and record it.
13. **Documentation updates:** `VERIFICATION_LOG.md` (revalidation table, live-test results), `GEMINI_INTEGRATION_SPECIFICATION.md` (⟳ items updated with the date), `SECURITY_AND_PRIVACY.md` §2.4, `RISK_REGISTER.md` R-10/R-11/R-12/R-14/R-31, `PHASE_TRACKER.md`, §E.
14. **Definition of done:** The mapped P0 criteria PASS; model availability and the response structure are recorded; the privacy note is dated and sourced; no secret is in any tracked file or log.
15. **Next milestone:** M06.

---

## M06 — End-to-end flow, retry and hidden-arrival behaviour

1. **ID and name:** M06, End-to-end assistant flow.
2. **Objective:** Connect activation → acquisition → one Gemini request → response in the panel, with loading states, manual Retry with cooldown (no automatic retry), cancel, content discarding, hidden-arrival behaviour (a response arriving while the panel is hidden keeps it hidden), inline Markdown rendering with non-actionable links, and [Copy].
3. **Prerequisites:** M05 DONE.
4. **Inputs:** `PRODUCT_BEHAVIOR.md` §1 (state machine), §2 (flow), §3 (messages); `UI_SPECIFICATION.md` §3 (panel states, loading, N-04 after 15 s, Reduce Motion, Escape/⌘W), §3.6 (Markdown); `GEMINI_INTEGRATION_SPECIFICATION.md` §8 (cooldown 0/2/4/8/16/30 s); `MODULE_CONTRACTS.md` §5.1–§5.3; P2-09, P2-14, P2-15, P3-15.
5. **File and module changes:** DoomFeatures: the complete `AssistantController` (flow token, single flight, `copyResponse()` write-only), `PanelView` for all states, the full `MessageCatalog`, the Markdown rendering transform. App target: final wiring. The M03b interim success behaviour is removed (close its IMPL entry). Tests: complete `AssistantControllerTests` (LIFE-T-01…04, SHORTCUT-T-09, GEMINI-T-07), `MessageCatalogTests` (UI-T-04, exhaustive), `MarkdownRenderingTests`. Review rules R-ONE-CALLSITE, R-NO-OPENURL.
6. **Ordered tasks:**
   1. Update the review rules.
   2. Write the controller tests for every transition, including activation while busy (count = 1), hide during a request (no cancel, stays hidden), Retry (no re-read), cooldown and cancel; then implement.
   3. Write the rendering tests (links rendered as plain text; no URL opens), then implement.
   4. Run CMD-VERIFY.
   5. **Real Mac (fixture page, synthetic text only):**
      - The full flow in TextEdit and Chrome.
      - UI-30 (timing from notice timestamps), UI-31 (loading text; N-04 after 15 s, simulated with a debugger pause only if the user agrees; otherwise AUTO only, and the RM part stays NOT TESTED).
      - UI-32 (Reduce Motion), UI-36 (Markdown, links not clickable, [Copy]), UI-38 (VoiceOver), UI-39 (Escape/⌘W).
      - SHORTCUT-08 (hide during a request; the response arrives hidden; ⌃⇧H shows it).
      - LIFE-09 (cancel), LIFE-10 (`kill -9` during a request, with the user's consent; record behaviour per S-17), LIFE-12 (Quit from the menu: log shows `terminate`).
      - GEMINI-08 (one request per activation: notice `request.start` count = number of activations, cross-checked with CMD-NET snapshots).
      - UI-37 (Instruments, if the user agrees).
   6. Update the tracker; commit if consented.
7. **Automated tests:** LIFE-T-01…04, SHORTCUT-T-09, GEMINI-T-07, UI-T-04, rendering tests, all earlier suites.
8. **Manual tests:** As listed in task 5.
9. **Build and verification commands:** CMD-PKG-TEST, CMD-BUILD-DEBUG, CMD-LAUNCH, CMD-LOG-SHOW (`grep -c 'request.start'`), CMD-NET, CMD-VERIFY.
10. **Acceptance criteria:** UI-30, -31, -32, -36, -37, -38, -39, -40; LIFE-05, -06, -07, -08, -09, -10, -12; SHORTCUT-05, -08; GEMINI-08, -28; SEC-11.
11. **Failure conditions:** More than one request per activation; any automatic retry; a late result shown after cancel; the panel auto-showing on hidden arrival; a link opening; content retained after close; panel appearance > 150 ms median (P1: record it and continue).
12. **Recovery strategy:** Concurrency bugs: reproduce in `AssistantControllerTests` first, then fix. Performance misses (P1): measure, optimise within the design, otherwise list as a known limitation.
13. **Documentation updates:** `VERIFICATION_LOG.md`, `PHASE_TRACKER.md`, R-15/R-16/R-17, §E.
14. **Definition of done:** The mapped P0 criteria PASS; R-ONE-CALLSITE passes; the interim behaviour is removed; the complete flow has been demonstrated on the real Mac with synthetic content.
15. **Next milestone:** M07.

---

## M07 — Security, privacy and permissions verification

1. **ID and name:** M07, Security, privacy and permissions verification.
2. **Objective:** Verify the privacy and security guarantees on the real Mac (no launch-time network, Keychain reads or prompts; no file writes; no content in logs; exactly three preference keys; capture behaviour disclosed) and record permission behaviour, including restart requirements.
3. **Prerequisites:** M06 DONE.
4. **Inputs:** `SECURITY_AND_PRIVACY.md` (all), ACCEPTANCE §5–§6 and §8a SEC-RM-01…04, `SHORTCUT_SPECIFICATION.md` SHORTCUT-RM-05, `TEXT_ACQUISITION_SPECIFICATION.md` TEXT-RM-11.
5. **File and module changes:** No new features. Fixes only, each with a test where feasible. Documentation updates.
6. **Ordered tasks:**
   1. Full reading pass (REV) of every source file against SEC-04 (logging) and the §2 data inventory.
   2. SEC-01/GEMINI-04: fresh launch; CMD-NET snapshots at launch and after 2 minutes idle show 0 connections; logs show no Keychain read at launch.
   3. SEC-RM-01 (SEC-05): the user runs CMD-FS during a full flow, with and without the fallback; Antigravity reviews the output the user pastes (paths only).
   4. SEC-06: CMD-DEFAULTS shows at most the three approved keys.
   5. SEC-09/SEC-RM-03: capture check with ⇧⌘5 screenshot and recording (and screen sharing if the user has a tool). Record the results for each tool and macOS build. The disclosure text must match the results; never claim invisibility.
   6. **Permissions** (each `tccutil reset` only with consent):
      - PERM-01: fresh state, so no prompt before [Grant Access…].
      - PERM-04 / TEXT-RM-11: revoke while running → E-ACC-01 on the next activation, no crash.
      - PERM-05 / SHORTCUT-11 / SHORTCUT-RM-05: grant while running → the chord works without relaunch, or the restart prompt appears. **Record which.**
      - PERM-08: record the behaviour for grant, revoke and rebuild on the verified macOS build.
   7. Run CMD-VERIFY; update the tracker; commit if consented.
7. **Automated tests:** All suites (regression), review checks.
8. **Manual tests:** SEC-RM-01, -02, -03; the permission procedures above.
9. **Build and verification commands:** CMD-LAUNCH, CMD-NET, CMD-FS (by the user), CMD-DEFAULTS, CMD-LOG-SHOW, CMD-TCC-RESET (with consent), CMD-VERIFY.
10. **Acceptance criteria:** SEC-01, -04, -05, -06, -09; GEMINI-04; PERM-01, -04, -05, -08; SHORTCUT-11.
11. **Failure conditions:** Any network connection before activation; any DOOM file write outside system-managed preferences; content in logs; extra preference keys; a prompt at launch; a silently dead chord after a grant; a capture claim not backed by results.
12. **Recovery strategy:** Fix the cause and add a review rule or test that would have caught it. If a permission behaviour is inherent to macOS (for example a relaunch is required), make sure the restart prompt exists and record the behaviour as the documented outcome.
13. **Documentation updates:** `SECURITY_AND_PRIVACY.md` (capture results table, permission behaviour), `VERIFICATION_LOG.md`, R-22/R-26/R-33, `PHASE_TRACKER.md`, §E.
14. **Definition of done:** The mapped P0 criteria PASS; permission behaviour is recorded for the verified macOS build.
15. **Next milestone:** M08.

---

## M08 — Full test run and regression fixes

1. **ID and name:** M08, Full test run and regression fixes.
2. **Objective:** Run every automated test, review gate and script on the final code, fix regressions, re-run the affected real-Mac procedures, and record commands, exit codes and counts.
3. **Prerequisites:** M07 DONE.
4. **Inputs:** `TESTING_STRATEGY.md` §3, §4, §11; `PHASE_TRACKER.md` (which RM procedures may be affected by changes since they passed).
5. **File and module changes:** Fixes and tests only. No new features.
6. **Ordered tasks:**
   1. Run CMD-VERIFY and CMD-PKG-XCTEST and record the counts (passed / failed / skipped; live tests skipped and reported as skipped: TEST-03).
   2. Confirm the unit tests pass with Wi-Fi off, if the user agrees to toggle it, or with the network unavailable (TEST-02). Otherwise confirm by review that only `StubURLProtocol` sessions are used.
   3. TEST-04: map every test to an acceptance or procedure ID (table in `VERIFICATION_LOG.md`); delete or justify any orphan test.
   4. Fix any failure (test first). Re-run the affected RM procedures with the user.
   5. TEST-06/TEST-07: confirm the log has commands, exit codes and counts for every run, and synthetic-only content.
   6. Update the tracker; commit if consented.
7. **Automated tests:** Everything.
8. **Manual tests:** Re-runs of affected RM procedures only.
9. **Build and verification commands:** CMD-VERIFY, CMD-PKG-XCTEST, CMD-REVIEW, CMD-SECRETS.
10. **Acceptance criteria:** TEST-01, -02, -03, -04, -06, -07.
11. **Failure conditions:** Any failing test or warning; an orphan or meaningless test; a missing count or exit code.
12. **Recovery strategy:** Fix and re-run. Never skip or disable a test to pass. A test that is truly obsolete is removed with a recorded reason.
13. **Documentation updates:** `VERIFICATION_LOG.md` (full-run table), `PHASE_TRACKER.md`, §E.
14. **Definition of done:** 0 failures, 0 warnings, counts recorded, all mapped criteria PASS.
15. **Next milestone:** M09.

---

## M09 — Release build, local installation, signing check, README

1. **ID and name:** M09, Release build and local installation.
2. **Objective:** Produce a verified Release build signed with Apple Development (the least complicated secure local signing; no paid service), install it to `~/Applications`, provide a safe uninstaller, and document exact build and launch commands in `README.md`.
3. **Prerequisites:** M08 DONE.
4. **Inputs:** P3-04, P3-10, `PROJECT_STRUCTURE.md` §2.7, `SECURITY_AND_PRIVACY.md` (uninstall and data locations).
5. **File and module changes:** `scripts/install.sh`, `scripts/uninstall.sh`, `README.md` (updated: requirements, build, install, launch, permissions, API key, privacy summary, profile renewal, uninstall, known limitations, the not-affiliated notice), a `verify.sh` extension (syntax-check the new scripts; dry-run the uninstaller).
6. **Ordered tasks:**
   1. `install.sh`: `set -euo pipefail`; CMD-BUILD-RELEASE; `verify-bundle.sh release`; `smoke-test.sh release`; quit a running DOOM (ask through the user's menu Quit, or `pkill -x DOOM` with a printed notice); `mkdir -p ~/Applications`; `ditto build/DerivedData/Build/Products/Release/DOOM.app ~/Applications/DOOM.app`; `codesign --verify --deep --strict` on the installed copy; print the launch command `open ~/Applications/DOOM.app`. Never `sudo`, never `/Applications`, never `xattr -d` or `spctl` changes.
   2. `uninstall.sh`: list every action, support `--dry-run`, and ask for `y/N` confirmation. Actions: remind the user to click [Remove] for the API key in DOOM first (data protection keychain, R-12 note); quit DOOM; remove `~/Applications/DOOM.app`; `defaults delete com.tace.doom`; `tccutil reset Accessibility com.tace.doom`. It does not delete the repository or build folders.
   3. Run the installer; launch the installed copy; run the full flow once (PKG-02); record the Accessibility behaviour after the install (PERM-08). The Debug build must **not** run at the same time (LIFE-14 protects it, but avoid the confusion).
   4. PKG-03: CMD-SIGN on the installed copy; record the profile expiry and write the renewal procedure in the README ("re-run `scripts/install.sh` before <date>; with a free Personal Team the profile is short-lived" *[expiry period verified from the profile]*).
   5. Run `uninstall.sh --dry-run` (PKG-04). A real uninstall runs **only if the user wants it**; otherwise that part is NOT TESTED, with the reason.
   6. LIFE-15: verify the identifier in the installed bundle, and R-BUNDLEID passes.
   7. Run CMD-VERIFY; update the tracker; commit if consented.
7. **Automated tests:** All suites; `bash -n` on the scripts; the uninstall dry run.
8. **Manual tests:** Launching the installed copy, the full flow, permission behaviour, an optional real uninstall.
9. **Build and verification commands:** `scripts/install.sh`, `open ~/Applications/DOOM.app`, CMD-SIGN on `~/Applications/DOOM.app`, `scripts/uninstall.sh --dry-run`, CMD-VERIFY.
10. **Acceptance criteria:** PKG-01, -02, -03, -04; LIFE-15.
11. **Failure conditions:** The installed app fails to launch; the signature is invalid; the uninstaller acts without confirmation or its dry run modifies anything; the README commands differ from the scripts.
12. **Recovery strategy:** Signing or profile problems: rebuild with `-allowProvisioningUpdates` and re-check that the user is signed in to Xcode. Never use ad-hoc signing for the installed copy without the user's decision. A Developer ID or paid membership is only suggested as an option needing the user's approval.
13. **Documentation updates:** `README.md`, `VERIFICATION_LOG.md`, `PHASE_TRACKER.md`, R-29 (actual expiry), §E.
14. **Definition of done:** The mapped P0 criteria PASS; the README is accurate; the user can launch DOOM from `~/Applications`.
15. **Next milestone:** M10.

---

## M10 — Final acceptance report

1. **ID and name:** M10, Final acceptance report.
2. **Objective:** Produce `docs/FINAL_ACCEPTANCE_REPORT.md` with an evidence-backed status for every acceptance criterion, and an honest separation of what was implemented, built, unit-tested, integration-tested, verified manually, not verified, and known limitations.
3. **Prerequisites:** M09 DONE (or every remaining milestone BLOCKED with recorded reasons).
4. **Inputs:** `ACCEPTANCE_CRITERIA.md` (all rows, §10, §11), `VERIFICATION_LOG.md`, `PHASE_TRACKER.md`, `TECHNICAL_DECISIONS.md` §E, `RISK_REGISTER.md`.
5. **File and module changes:** Create `docs/FINAL_ACCEPTANCE_REPORT.md` (Appendix E). Update the Status column of `ACCEPTANCE_CRITERIA.md`. No code changes, unless a defect is found; in that case go back to the owning milestone and re-run M08.
6. **Ordered tasks:**
   1. For each criterion (148 at Phase 03; add any later IMPL additions), assign PASS / FAIL / BLOCKED / NOT TESTED / NOT APPLICABLE, with the evidence reference (`VERIFICATION_LOG.md` entry heading). No evidence, no PASS (TEST-05).
   2. Fill the seven report sections (Appendix E).
   3. Apply the v1 completion rule (ACCEPTANCE §11) and state the outcome plainly: "v1 accepted" or "v1 not accepted: open P0 items …".
   4. Run CMD-VERIFY one last time and record it.
   5. Update `PHASE_TRACKER.md` (M10 DONE) and commit if consented.
   6. Tell the user the outcome in one short message: the result, the known limitations, and the profile renewal date.
7. **Automated tests:** The final CMD-VERIFY run.
8. **Manual tests:** None new.
9. **Build and verification commands:** CMD-VERIFY; `grep -c '| PASS |' docs/ACCEPTANCE_CRITERIA.md` and the same for each status, to give the totals in the report.
10. **Acceptance criteria:** TEST-05, and the final status of all criteria.
11. **Failure conditions:** Any PASS without evidence; a P0 criterion silently omitted; the report claims notarization, App Store readiness, screen-capture invisibility, or other unverified properties.
12. **Recovery strategy:** Correct the statuses. If a P0 is FAIL or NOT TESTED, either complete it (return to the owning milestone) or report v1 as not accepted.
13. **Documentation updates:** `FINAL_ACCEPTANCE_REPORT.md`, `ACCEPTANCE_CRITERIA.md` statuses, `PHASE_TRACKER.md`, `RISK_REGISTER.md` (final remaining uncertainty).
14. **Definition of done:** The report exists, every criterion has a status and evidence reference, the totals match the table, and the outcome is stated.
15. **Next milestone:** None. After M10, Antigravity continues to maintain DOOM only on the user's request.

---

## Appendix A — GUI fallback for creating the Xcode project (only if P3-01 gates fail)

This is used only when the hand-authored project cannot pass Appendix B after reasonable repair. It takes about 10 minutes of the user's time. Antigravity gives these steps one at a time and verifies each result with commands.

1. Antigravity moves its failed `DOOM.xcodeproj` to `build/failed-project/` (git-ignored). It does not delete it.
2. User: Xcode › File › New › Project › macOS › App › Next.
3. User: Product Name `DOOM`; Team: their team; Organization Identifier `com.tace`; Bundle Identifier should then show `com.tace.doom`; Interface SwiftUI; Language Swift; Testing System None; Storage None. Click Next.
4. User: when Xcode asks where to save, choose the folder `build/gui-project/` inside the repository (Antigravity creates it first and tells the user the exact path); leave "Create Git repository" unticked. Antigravity then moves the generated `DOOM.xcodeproj` to the repository root and moves the template's own `DOOM/` source folder to `build/gui-project-template/` (not deleted). The synchronized `DOOM` group then refers to the repository's existing `DOOM/` folder.
5. User: File › Add Package Dependencies › Add Local… › select the `DoomKit` folder › add the `DoomCore` and `DoomFeatures` products to the DOOM target.
6. User: in the project's Info tab, set "Based on Configuration File" to `Config/DOOM.xcconfig` for Debug and Release (target level).
7. User: Product › Scheme › Manage Schemes › tick **Shared** for DOOM.
8. User: quit Xcode.
9. Antigravity: remove the template files (`ContentView.swift`, the entitlements file, `Preview Content`), remove target-level build settings that duplicate or contradict the xcconfig (the template-settings rule in `PROJECT_STRUCTURE.md` §3), remove `DEVELOPMENT_TEAM` from `project.pbxproj` (it moves to `Local.xcconfig`), then re-run Appendix B gates B-1…B-6.

## Appendix B — Requirements and gates for the agent-authored project (P3-01)

**Requirements for `DOOM.xcodeproj/project.pbxproj`:**
- `objectVersion` supported by the installed Xcode (use the value Xcode writes for synchronized-folder projects, at least 77 *[Assumed; confirm against the installed Xcode's documentation or a template]*).
- One native target `DOOM` (product type `com.apple.product-type.application`), with a `PBXFileSystemSynchronizedRootGroup` for `DOOM/`. No per-file references.
- `XCLocalSwiftPackageReference` with `relativePath = DoomKit`, and `XCSwiftPackageProductDependency` entries for `DoomCore`, `DoomFeatures` and, from M03a, `DoomServices`, linked in the Frameworks build phase.
- A file reference to `Config/DOOM.xcconfig`, set as `baseConfigurationReference` for the target's Debug and Release configurations.
- Target-level `buildSettings` **empty** (or containing only what Xcode strictly requires and the xcconfig cannot provide; each such key is recorded as IMPL-xx).
- Project-level settings: only neutral defaults (`SDKROOT = macosx`, Debug `ONLY_ACTIVE_ARCH = YES`, Debug optimisation / Release whole-module). Nothing that contradicts the xcconfig.
- No `DEVELOPMENT_TEAM`, `PRODUCT_BUNDLE_IDENTIFIER`, `INFOPLIST_KEY_*`, `SWIFT_DEFAULT_ACTOR_ISOLATION`, `SWIFT_APPROACHABLE_CONCURRENCY` or `CODE_SIGN_ENTITLEMENTS` (except P3-13).
- Unique 24-hex-character object IDs, generated deterministically and documented in a comment at the top of the file.
- A shared scheme `xcshareddata/xcschemes/DOOM.xcscheme` with Build, Run (Debug) and Archive (Release) actions referencing the DOOM target. Tests run from the package (CMD-PKG-TEST / CMD-PKG-XCTEST).
- `project.xcworkspace/contents.xcworkspacedata` referencing `self:`.

**Gates (each recorded in `VERIFICATION_LOG.md`):**

| Gate | Command | Pass condition |
|---|---|---|
| B-1 | `plutil -lint DOOM.xcodeproj/project.pbxproj` | `OK` |
| B-2 | `xcodebuild -list -project DOOM.xcodeproj` | Target `DOOM`; configurations Debug, Release; scheme `DOOM` |
| B-3 | CMD-PROJECT build-settings grep + `scripts/review-checks.sh` (R-PBXPROJ) | xcconfig values shown; no forbidden keys |
| B-4 | `xcodebuild -project DOOM.xcodeproj -scheme DOOM -configuration Debug -derivedDataPath build/DerivedData -resolvePackageDependencies` | Local package resolved; no remote fetch |
| B-5 | CMD-BUILD-DEBUG and CMD-BUILD-RELEASE | Exit 0, 0 warnings |
| B-6 | CMD-VERIFY-BUNDLE + CMD-SMOKE for both | Pass |

Optional check that it opens in the GUI: the user opens `DOOM.xcodeproj` in Xcode once and confirms there is no "damaged project" alert. This is recommended once, at the end of M01.

## Appendix C — `docs/ENVIRONMENT_REPORT.md` template

```markdown
# DOOM — Environment Report (M00)
Date: <YYYY-MM-DD>   Recorded by: Antigravity

| Fact | Command | Actual output (trimmed) | Exit | Conclusive now? | Notes |
|---|---|---|---|---|---|
| macOS version / build | `sw_vers` | | | Yes | Reported: 27.0.1 "Golden Gate" |
| Marketing name | license RTF grep | | | Informational | |
| Architecture | `uname -m` | | | Yes | |
| Mac model / chip | `system_profiler … grep` | | | Yes | No serial recorded |
| Developer directory | `xcode-select -p` | | | Yes | |
| Xcode installs | `ls -d /Applications/Xcode*.app` | | | Yes | |
| Xcode version | `xcodebuild -version` | | | Yes | |
| macOS SDK | `xcrun --sdk macosx --show-sdk-version` | | | Yes | Deployment target per P3-02 |
| First-launch status | `xcodebuild -checkFirstLaunchStatus` | | | Yes | |
| Swift | `swift --version` | | | Yes | |
| Git | `git --version` | | | Yes | |
| Repository state | `git status --short` / "not a repository" | | | Yes | |
| Free disk | `df -h .` | | | Yes | |
| Globe key setting | `defaults read com.apple.HIToolbox AppleFnUsageType` | | | Partly | Meaning confirmed in M03a |
| Apple Development identities | `security find-identity … \| grep -c` | count only | | Yes | |
| Chrome version | `defaults read …` | | | Yes | |

## Needs a real build or run (not conclusive from M00)
- Fn delivery to NSEvent monitors (M03a) · Chrome Accessibility selection (M04a) · Carbon hotkey on this macOS (M03b) · data protection keychain with a Personal Team (M05) · TCC behaviour (M03a, M07) · panel behaviour over full-screen apps (M02)

## Discrepancies with the reported baseline
- <none / list>
```

## Appendix D — `docs/VERIFICATION_LOG.md` header

```markdown
# DOOM — Verification Log
Evidence for every acceptance status. Format: TESTING_STRATEGY.md §2. Newest entries at the bottom.
Never record secrets, selected text, responses, Apple ID, full team ID, serial numbers or user-name paths.
```

## Appendix E — `docs/FINAL_ACCEPTANCE_REPORT.md` structure

1. **Summary:** outcome (v1 accepted / not accepted), date, build, macOS version and build, Xcode version.
2. **Implemented:** features and files, by milestone.
3. **Built:** Debug and Release build commands, exit codes, warnings = 0, signing authority (redacted), profile expiry.
4. **Unit-tested:** suites, counts (passed / failed / skipped), commands, exit codes.
5. **Integration-tested:** live Gemini tests (user-run), dates, model, observed field paths.
6. **Verified manually on the real Mac:** procedures with dates and the user's confirmations.
7. **Not verified:** criteria NOT TESTED or BLOCKED, with reasons.
8. **Known limitations:** for example the Globe-key side effect, apps without Accessibility selection, panel visible in screen capture, Personal Team profile expiry, free-tier data use.
9. **Criteria table:** every ID, status and evidence reference; totals per status.
10. **Decisions made during implementation:** link to `TECHNICAL_DECISIONS.md` §E.
