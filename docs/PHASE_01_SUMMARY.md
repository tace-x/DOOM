# DOOM — Phase 01 Summary: Architecture and Technical Foundation

| | |
|---|---|
| **Status** | Complete as a *design*, **awaiting user approval** |
| **Date** | 2026-10-24 |
| **Implementation** | **Not started.** No source code, project, scripts or configuration files have been created for DOOM. |

---

## 1. What was decided

The full register, with options, rationale and trade-offs, is in `TECHNICAL_DECISIONS.md`.

| Area | Decision | Approval needed |
|---|---|---|
| Build system | **Xcode project for a thin app target, plus a local Swift package `DoomKit` for all modules and tests** (D-01). This supersedes the earlier unapproved draft (SwiftPM plus a bundling script). | **Yes** |
| Project creation | The user creates the Xcode project once in the GUI from a checklist. No XcodeGen or Tuist (D-02). | **Yes** |
| Modules | App target → `DoomFeatures` → `DoomCore`; `DoomServices` is deferred to its first real use (D-03). | No |
| Boundaries | `DoomCore` uses Foundation and OSLog only. `DoomFeatures` uses SwiftUI (AppKit only when documented). Only the app target reads process globals (D-04). | No |
| Swift and concurrency | Swift 6 mode, complete checking and explicit isolation, without Xcode default-isolation settings (D-05). | No |
| Minimum macOS | **14.0, provisional** (D-06). | **Yes** |
| Architecture | arm64 only (D-07). | No |
| Settings | `Config/DOOM.xcconfig` is the source of truth; a git-ignored `Local.xcconfig` holds the team ID (D-08). | No |
| Bundle metadata | Generated `Info.plist`; SemVer marketing version and an integer build number (D-09). | No |
| Bundle ID | **`com.example.doom`, placeholder** (D-10). | **Yes** |
| Configuration | Validated `AppConfiguration`, typed errors and a visible safe fallback (D-11). | No |
| Errors | Typed domain enums in Core; user text mapped in view models (D-12). | No |
| Logging | `os.Logger`; content is never logged; a `.public` allowlist; no `print` (D-13). | No |
| Testing | Swift Testing in the package; full Xcode required (D-14); smoke-test launch flag (D-15); built-bundle validation script (D-16). | No |
| Sandbox | **Non-sandboxed** (D-17), because Accessibility-based selection can't work sandboxed. | **Yes** |
| Hardened runtime | On from the start (D-18). | No |
| Signing | Ad-hoc in Phase 01; **a stable Apple Development identity is required before any TCC or Keychain phase** (D-19). | **Yes** |
| Dependencies and telemetry | No third-party dependencies (D-20); no telemetry (D-24). | No |
| UI surface | A Dock app with one dark 520 × 320 status window and design tokens; no proprietary assets (D-21, D-22). | No |
| Secrets (direction only) | Data protection keychain, key in a header only, never logged (D-23). | Later |
| Git safety and warnings | No agent commits or destructive operations without approval (D-25); zero warnings enforced at verification (D-26). | No |

## 2. Deliberately deferred

- **Product and UX decisions:** activation model, Dock vs menu-bar (DD-01).
- **Pending feasibility spikes:** the shortcut implementation (DD-02) and the selection strategy (DD-03).
- **Pending user approval:**
  - clipboard fallback policy (DD-04)
  - Gemini model and request design (DD-05)
  - Gemini tier and privacy disclosure (DD-06)
  - panel design and the best-effort capture option (DD-07)
  - distribution (DD-08)
  - updates (DD-09)
  - icon and branding (DD-10)
- **Belonging to later phases:** preferences storage (DD-11) and diagnostics (DD-12).
- **Not built in Phase 01:**
  - global shortcuts
  - Accessibility or selection code
  - clipboard code
  - Gemini or network code
  - Keychain code
  - floating panel
  - permission flows
  - diagnostics
  - packaging or notarization
  - app icon
  - entitlements
  - empty placeholder modules or folders

## 3. Technical feasibility vs product requirements

| Item | Status |
|---|---|
| `Fn + Control + Option` global activation | **A product requirement with feasibility not established.** It needs an event tap on modifier flags (Input Monitoring or Accessibility). It is affected by Globe-key system actions, external keyboards, a reported macOS 27 beta change, the VoiceOver modifier conflict and secure input. A hardware spike is required, and **no silent substitution** is allowed (`ARCHITECTURE.md` C-1). |
| `Control + Shift + H` panel toggle | Expected to be feasible with standard hotkey registration. Conflicts with other apps are possible (C-2). |
| Selected text from Chrome via Accessibility | Feasible in principle, but only for a non-sandboxed app. Reliability in every web context is unproven (C-3). |
| Clipboard fallback and restoration | Technically feasible with caveats: possible pasteboard-privacy prompts, non-atomic restoration and concealed types. **Whether to offer it is a product decision** (C-4). |
| Hiding the panel from screen capture | **Cannot be guaranteed.** Apple calls `NSWindow.SharingType.none` a legacy constant, and DTS says there is no public API to prevent capture. At most it can be a best-effort, honestly labelled option (C-7). |
| Gemini integration | Feasible. **The data-use policy is a product decision**: unpaid-tier content can be used for product improvement and seen by human reviewers (C-5). |
| Keychain storage | Feasible. It needs team-based signing and a provisioning profile for the data protection keychain (C-6). |

## 4. Important risks

1. **The architect has no Mac.** Phase 01 analysis ran in a remote Linux sandbox (Debian 13, x86_64) without Swift, Xcode or the macOS SDK. Nothing in this design has been compiled or run, and every macOS-specific claim marked *[Assumed]* must be confirmed on the user's Mac.
2. **The user's Mac environment is unknown:** macOS version, Xcode version, whether full Xcode is installed, keyboard type. Several decisions depend on these (D-06, D-14, C-1).
3. **Xcode template drift.** The creation checklist (D-02) must match the installed Xcode version: template target-level settings, sandbox entitlement, default isolation. Mitigation: `xcodebuild -showBuildSettings`, `verify-bundle.sh` and the review greps detect drift.
4. **Swift 6 strict concurrency** may reject details of the specified APIs (for example delegate-adaptor access or `Logger` sendability). Mitigation: the smallest fix, recorded as a deviation.
5. **Signing and TCC churn** in later phases if a stable identity isn't set up first (D-19).
6. **Infeasible shortcut.** The `Fn + Control + Option` requirement may be infeasible or unreliable on the user's hardware or OS (C-1).
7. **Privacy exposure.** Selected text sent to Gemini on an unpaid tier (C-5).
8. **Trademark.** "DOOM" is an established video-game trademark and "Doctor Doom" is a Marvel character. This is acceptable as a private project name; public distribution under this name carries legal risk (DD-10).
9. **Smoke-test environment.** It needs a logged-in GUI session and cannot run over SSH or headless CI.

## 5. Open questions that genuinely need the user's input

1. **Your Mac:** which macOS version (`sw_vers`), and is **full Xcode** installed? Which version (`xcodebuild -version`)? This determines D-06 and D-14.
2. **Build system (D-01, D-02):** do you approve the change to an Xcode project plus a local package, and the one-time GUI step to create the project?
3. **Bundle identifier (D-10):** which reverse-DNS ID should DOOM use (for example `com.<yourname>.doom`)?
4. **Minimum macOS (D-06):** keep 14.0, or target your installed version?
5. **Sandbox and distribution (D-17):** do you accept that DOOM is non-sandboxed and therefore can't be distributed through the Mac App Store?
6. **Apple account (D-19):** will you use an Apple ID / Apple Developer account for stable signing before the permission phases, and is it free or paid? Paid is needed only for Developer ID distribution.

Questions that can wait until their phase: DD-01, DD-04, DD-06, DD-07, DD-08, DD-09, DD-10.

## 6. Quality-control review (performed before presenting)

| # | Check | Result |
|---|---|---|
| 1 | Architecture matches the directory structure | ✅ Every module and file in `ARCHITECTURE.md` §2 appears in `PROJECT_STRUCTURE.md` §1–2, and vice versa. `AppContext` is used consistently; the earlier draft's name, `AppEnvironment`, has been replaced everywhere. |
| 2 | Every module has a clear responsibility | ✅ Three modules, each with an owner, allowed imports and forbidden imports (`PROJECT_STRUCTURE.md` §4). |
| 3 | Dependencies don't contradict the architecture | ✅ The `Package.swift` spec allows only `Features → Core`, and the app links both. Removing `live()` from `AppContext` keeps process globals in the app target only. |
| 4 | The build-system decision is technically justified | ✅ D-01 is evaluated on all 11 required criteria. The decisive factors are the provisioning profile needed for the data protection keychain, TCC attribution while debugging, and distribution. |
| 5 | Standards are compatible with the build system | ✅ After correction (see contradictions below). |
| 6 | Testing is practical | ✅ The package tests need no app host. Bundle checks run on the real artifact. The smoke test needs no extra target or privileges. |
| 7 | No future functionality in scope | ✅ Every future capability appears only as a constraint (C-1…C-10) or a deferred decision. A review grep detects leakage. |
| 8 | Security and privacy are explicit | ✅ `ARCHITECTURE.md` §9 and `ENGINEERING_STANDARDS.md` §5, §6.3 and §10. |
| 9 | Unresolved decisions are identified | ✅ Six approval items (§5) and twelve deferred decisions. |
| 10 | Usable by Antigravity later | ✅ It gives the exact file list, public API surfaces, xcconfig keys, test cases, scripts and review checks. The project-creation checklist is intentionally left for the handoff package, which this phase must not produce. |

**Contradictions found and how they were resolved:**
- **Earlier draft vs this design.** The earlier, unapproved brief (`doom-phase01/`) uses SwiftPM plus a bundling script and different names. *Resolution:* D-01 supersedes it, and a notice was added to that folder. Its files were **not deleted** (no destructive cleanup without approval).
- **"Strict boundaries" vs Xcode template defaults.** Newer templates enable App Sandbox, add target-level build settings and may enable default MainActor isolation, all of which contradict D-05, D-08 and D-17. *Resolution:* the template-settings rule in `PROJECT_STRUCTURE.md` §3 and the review greps.
- **"Zero warnings" vs SDK upgrades.** A permanent warnings-as-errors setting would break builds after an SDK update for reasons unrelated to the change. *Resolution:* enforce zero warnings in the verification commands only (D-26).
- **"No stdout logging" vs a machine-checkable smoke result.** *Resolution:* one explicit, documented exception, the `DOOM_SMOKE_OK` marker (D-15).
- **Plist validation vs a generated plist.** There is no source plist to unit-test. *Resolution:* unit-test the validation logic and validate the built product with a script (D-16). The fallback bundle ID is deliberately distinct, so no ID has to be kept in sync across files.
- **"Avoid placeholders" vs the Xcode template's empty `AppIcon` set.** *Resolution:* keep the template's empty icon set, which is an Xcode artifact rather than a feature placeholder, and record it explicitly (DD-10).
- **The `Fn + Control + Option` requirement vs platform reality.** This is not resolved; it is recorded honestly as a feasibility risk with a no-substitution rule.

## 7. What Phase 01 has and has not accomplished

**Has accomplished:**
- Requirements analysed and the 13 framing questions answered across these documents.
- Build system evaluated, with a justified decision.
- Modular architecture, dependency rules, lifecycle, error, concurrency and logging strategies defined.
- Exact initial file structure, with per-file responsibilities, dependencies and test ownership.
- Engineering standards for Swift, concurrency, configuration, errors, logging, testing and Git.
- Future-feature constraints researched and documented with sources.
- Security and privacy boundaries, approval items and deferred decisions identified.
- Five documents created in `docs/`.

**Has not accomplished (by design or by constraint):**
- No implementation, Xcode project, scripts or configuration files exist.
- No compilation, tests, launch or bundle verification. Nothing can be claimed to build or pass.
- No inspection of the user's Mac. Its environment is unknown.
- No Antigravity handoff package, project-creation checklist, Phase 02 plan or roadmap. Each was explicitly out of scope.

## 8. Environment and access limitations
- The workspace is a remote **Linux** sandbox. `swift`, `xcodebuild`, `xcrun` and `sw_vers` are all unavailable, and no software was installed.
- The only pre-existing project documentation was this conversation's earlier draft (`doom-phase01/ANTIGRAVITY_BRIEF.md` and `reference/`). It was read and evaluated, and is superseded where it conflicts.
- No other project files were provided, and none were claimed as inspected.
- External facts come from web research on 2026-10-24 (Apple documentation, Apple DTS forum answers, the Gemini API terms, and developer reports). Single developer reports are labelled unverified.

## 9. Recommendation
**Phase 01 is ready for review and approval**, subject to the user answering the six questions in §5. Approving D-01, D-02, D-10 and D-17 in particular changes or fixes the foundation. Nothing in Phase 02 should start until that approval is given.
