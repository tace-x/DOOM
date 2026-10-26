# DOOM — Phase Tracker

| | |
|---|---|
| **Maintained by** | Antigravity (sole development agent). Updated at the start and end of every milestone and whenever a blocker appears or clears |
| **Created** | 2026-10-24 (Phase 03 handoff) |
| **Status values** | NOT STARTED · IN PROGRESS · BLOCKED (name the blocker and who can clear it) · DONE (only per the completion rule, `ACCEPTANCE_CRITERIA.md` §11) |

**Current state:** Milestones M00, M01, M03a, M02, M03b, M04a, and M04b are **DONE**. Milestone **M05** (Keychain and Gemini integration) is **PARTIAL** (All automated criteria pass; live provider verification awaits user key entry). Next milestone is **M06** (End-to-end assistant flow).

---

## 1. Milestones (in execution order)

| Order | Milestone | Status | Started | Finished | Mapped criteria PASS / total | Blocker / note |
|---|---|---|---|---|---|---|
| 1 | M00 Environment verification and work preservation | DONE | 2026-10-24 14:40 | 2026-10-24 14:45 | 3 / 3 | Evidence in `VERIFICATION_LOG.md` |
| 2 | M01 Foundation, Xcode project and signing | DONE | 2026-10-24 14:46 | 2026-10-24 15:00 | 9 / 9 | Evidence in `VERIFICATION_LOG.md` |
| 3 | M03a Activation chord feasibility gate | DONE | 2026-10-25 02:08 | 2026-10-25 02:22 | 9 / 9 | Feasibility confirmed on Mac17,3; evidence in `VERIFICATION_LOG.md` |
| 4 | M04a Chrome selection feasibility gate | DONE | 2026-10-25 02:24 | 2026-10-25 02:35 | 13 / 13 | Chrome feasibility confirmed on Mac17,3 (Chrome 156); evidence in `VERIFICATION_LOG.md` |
| 5 | M02 Menu-bar shell and panel foundation | DONE | 2026-10-25 01:45 | 2026-10-25 02:06 | 16 / 16 | Phase 05 verified; evidence in `VERIFICATION_LOG.md` |
| 6 | M03b Panel shortcut and controller skeleton | DONE | 2026-10-25 02:08 | 2026-10-25 02:22 | 8 / 8 | Control+Shift+H and panel preservation verified; evidence in `VERIFICATION_LOG.md` |
| 7 | M04b Full text acquisition | DONE | 2026-10-25 02:30 | 2026-10-25 02:44 | 11 / 11 | Full acquisition, validation & fallback verified; evidence in `VERIFICATION_LOG.md` |
| 8 | M05 Keychain and Gemini integration | PARTIAL | 2026-10-25 14:26 | 2026-10-25 15:08 | 34 / 36 | Implementation complete; Keychain save/read/replace/delete bug fixed & verified; live test awaits user key |
| 9 | M06 End-to-end assistant flow | NOT STARTED | — | — | 0 / 20 | — |
| 10 | M07 Security, privacy and permissions verification | NOT STARTED | — | — | 0 / 11 | — |
| 11 | M08 Full test run and regression fixes | NOT STARTED | — | — | 0 / 6 | — |
| 12 | M09 Release build and local installation | NOT STARTED | — | — | 0 / 5 | — |
| 13 | M10 Final acceptance report | NOT STARTED | — | — | 0 / 1 (+ all) | — |

(The totals come from `ACCEPTANCE_CRITERIA.md` §10.)

## 2. Standing answers from the user

| Question | Answer | Date |
|---|---|---|
| Local git commits at milestone completion (never push), P3-12 | *not asked yet (M00)* | — |
| Apple ID signed in to Xcode for Apple Development signing, P3-04 | *not asked yet (M01, only if needed)* | — |

## 3. Open blockers

*None.*

## 4. Known limitations accepted by the user

*None yet.*

## 5. Real-Mac procedures to re-run after code changes (for M08)

| Procedure | Last PASS (date, build) | Code changed since? |
|---|---|---|
| SHORTCUT-RM-01 (Fn activation chord) | 2026-10-25 02:20, 0.1.0(1) | No |
| SHORTCUT-RM-02 (Normal typing test) | 2026-10-25 02:20, 0.1.0(1) | No |
| SHORTCUT-RM-03 (Globe key side effect test) | 2026-10-25 02:20, 0.1.0(1) | No |
| SHORTCUT-RM-07 (Control+Shift+H hotkey) | 2026-10-26 14:45, 0.1.0(1) | Yes (improved release tracking & debouncing) |
| SEC-RM-03 (Screen capture behavior investigation) | 2026-10-26 14:45, 0.1.0(1) | Verified via `scripts/screen-capture-test.swift` |
| TEXT-RM-01 (TextEdit native selection) | 2026-10-25 02:42, 0.1.0(1) | No |
| TEXT-RM-02 (Chrome web-page selection) | 2026-10-25 02:35, 0.1.0(1) | No |
| TEXT-RM-03 (Chrome textarea selection) | 2026-10-25 02:35, 0.1.0(1) | No |
| TEXT-RM-09 (Password field guard) | 2026-10-25 02:35, 0.1.0(1) | No |


