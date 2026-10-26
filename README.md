# DOOM

A native macOS assistant for personal use.

> **Notice:** DOOM is an independent personal project and is not affiliated with, endorsed by, or connected to Marvel, Disney, id Software, Bethesda, or any of their affiliates or trademarks.

---

## Requirements

- **Operating System:** macOS 27.0 or later (verified on macOS 27.0.1)
- **Architecture:** Apple Silicon (arm64)
- **Toolchain:** Full Xcode 16.0 or later (tested on Xcode 27.1) with Swift 6

---

## Foundation Status

DOOM is currently at the **Foundation (Phase 04 / Milestone M01)** stage:
- Native Xcode application target (`DOOM`) configured with `com.tace.doom`
- Local Swift package `DoomKit` (`DoomCore` and `DoomFeatures`) with 100% strict concurrency and data-race safety
- Standard dark metallic visual identity with emerald accents
- Deterministic configuration validation and fallback handling
- Privacy-conscious logging using `os.Logger` with zero secret exposure

*Assistant capabilities (activation shortcut, text acquisition, and Gemini integration) are scheduled for subsequent milestones.*

---

## Quick Start & Verification

Run the full automated verification suite:

```bash
./scripts/verify.sh
```

Individual scripts:
- Build debug: `./scripts/build.sh debug`
- Build release: `./scripts/build.sh release`
- Package unit tests: `swift test --package-path DoomKit`
- Bundle verification: `./scripts/verify-bundle.sh debug`
- Smoke test: `./scripts/smoke-test.sh debug`
- Secret scan: `./scripts/check-secrets.sh`
- Review checks: `./scripts/review-checks.sh`

To launch the built debug application:

```bash
open build/DerivedData/Build/Products/Debug/DOOM.app
```

---

## Documentation

Full project architecture, specifications, roadmaps, and verification logs are maintained in [`docs/`](docs/):
- [`HANDOFF_README.md`](docs/HANDOFF_README.md): Document map and project orientation
- [`ARCHITECTURE.md`](docs/ARCHITECTURE.md): System architecture and constraints
- [`IMPLEMENTATION_ROADMAP.md`](docs/IMPLEMENTATION_ROADMAP.md): Milestone definitions (M00–M10)
- [`TESTING_STRATEGY.md`](docs/TESTING_STRATEGY.md): Verification layers, commands, and review rules
- [`ACCEPTANCE_CRITERIA.md`](docs/ACCEPTANCE_CRITERIA.md): Acceptance criteria inventory
- [`ENVIRONMENT_REPORT.md`](docs/ENVIRONMENT_REPORT.md): Verified Mac environment facts (M00)
- [`VERIFICATION_LOG.md`](docs/VERIFICATION_LOG.md): Evidence log for every milestone
- [`PHASE_TRACKER.md`](docs/PHASE_TRACKER.md): Live progress and milestone status
