# DOOM — Handoff README

| | |
|---|---|
| **Date** | 2026-10-24 |
| **State** | Planning complete (Phase 01 architecture, Phase 02 specification, Phase 03 roadmap and handoff). **Nothing is implemented.** No Swift code, Xcode project, build, test or signed app exists. |
| **From now on** | **Antigravity is the sole development agent.** The Orchestration AI is finished and will not review, approve or continue this work. There is no Phase 04. |

---

## 1. What you (the user) do to start, about 5 minutes

1. On your Mac, create an empty folder for the project, for example `~/Developer/DOOM`. Any location works; avoid iCloud-synced folders such as Desktop or Documents if they sync, because build folders are large.
2. Copy this entire `docs/` folder into it, so you have `~/Developer/DOOM/docs/…`.
3. **Do not copy** anything from `doom-phase01/` (the superseded first draft). It is obsolete and contradicts the approved decisions.
4. Open the folder in **Antigravity**.
5. Paste the content of `docs/ANTIGRAVITY_MASTER_PROMPT.md` (everything below its line) as your first message.
6. From then on, Antigravity runs the work. It will ask you only for:
   - physical steps on the Mac (pressing the shortcut, selecting test text) and what you saw;
   - granting Accessibility in System Settings;
   - signing in to Xcode with your Apple ID if needed (a free account is enough);
   - entering your Gemini API key **in DOOM's own Settings field** (never in chat);
   - running the occasional `sudo` command it explains;
   - one-question product decisions, if a test on your Mac proves something can't work as planned.

You never need to write code, edit project files or fix builds.

## 2. Things to have ready (not needed for the first steps)

- **Xcode** (full app, not just Command Line Tools). You reported it is installed; Antigravity checks this first.
- An **Apple ID**, for free Apple Development signing. This keeps your Accessibility permission across rebuilds and lets the Keychain store the API key properly. No paid membership is required.
- A **Gemini API key** from Google AI Studio, needed in milestone M05. If it is a free-tier key, Google may use the content you send to improve its products, and human reviewers may read it. DOOM shows this notice once before the first request.
- **Google Chrome** and **TextEdit**, for the hardware tests.

## 3. Document map

| Document | What it is | Phase |
|---|---|---|
| `ANTIGRAVITY_MASTER_PROMPT.md` | The first message for Antigravity; permanent operating rules | 03 |
| `IMPLEMENTATION_ROADMAP.md` | Milestones M00–M10 with 15 fields each; GUI fallback; project-file requirements; report templates | 03 |
| `TESTING_STRATEGY.md` | Test layers, exact commands, real-Mac protocol, review greps, live-test procedure, evidence format | 03 |
| `PHASE_TRACKER.md` | Milestone status (all NOT STARTED), user answers, blockers | 03 |
| `HANDOFF_README.md` | This file | 03 |
| `ACCEPTANCE_CRITERIA.md` | 148 criteria (all NOT TESTED), milestone mapping, status vocabulary, completion rules | 02, extended 03 |
| `RISK_REGISTER.md` | R-01…R-34 and decision status | 02, extended 03 |
| `TECHNICAL_DECISIONS.md` | D-01…D-26, deferred DD-xx, P2-01…P2-17, **P3-01…P3-15**, §E implementation log (empty) | 01–03 |
| `ARCHITECTURE.md` | System architecture, constraints C-1…C-7 | 01 |
| `PROJECT_STRUCTURE.md` | Foundation file list, xcconfig keys, scripts | 01, annotated 03 |
| `ENGINEERING_STANDARDS.md` | Coding, concurrency, logging, git, evidence rules | 01, annotated 03 |
| `PHASE_01_SUMMARY.md` | Phase 01 history | 01 |
| `PRODUCT_BEHAVIOR.md` | States, flows, every user-visible message | 02 |
| `SHORTCUT_SPECIFICATION.md` | Chord recogniser, ⌃⇧H, hardware procedures, fallback options | 02 |
| `TEXT_ACQUISITION_SPECIFICATION.md` | Accessibility strategies, Chrome handling, clipboard fallback | 02 |
| `GEMINI_INTEGRATION_SPECIFICATION.md` | Request, response, errors, retry cooldown, Keychain | 02 |
| `UI_SPECIFICATION.md` | Colours, panel, main window, privacy notice text | 02 |
| `SECURITY_AND_PRIVACY.md` | Data inventory, logging rules, capture disclosure | 02 |
| `MODULE_CONTRACTS.md` | Module graph, protocols, planned files | 02 |

Files Antigravity will create: `docs/ENVIRONMENT_REPORT.md` (M00), `docs/VERIFICATION_LOG.md` (M00), `docs/FINAL_ACCEPTANCE_REPORT.md` (M10), plus all source code, the Xcode project, scripts, the test fixture and `README.md`.

## 4. Key facts to remember

- **Bundle ID `com.tace.doom` is permanent.** Changing it later would lose the stored API key, the Accessibility permission and the preferences.
- **Two feasibility gates come first.** Fn + Control + Option (M03a) and Chrome selection (M04a) are tested on your Mac before the UI is built. If either fails, Antigravity stops and asks you to choose; it will not quietly change the design.
- **Privacy:** DOOM sends only the selected text and a fixed instruction, one request per activation, with `store:false`. It writes no files and logs no content. The panel **can** appear in screenshots and screen sharing; press ⌃⇧H to hide it.
- **Personal use:** DOOM is installed to `~/Applications` by a script, signed with your free Apple Development identity. It is not notarized, and not intended for distribution. With a free account the signing profile expires periodically; the README will say when and how to refresh it (re-run the install script).
