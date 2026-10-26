# DOOM — Environment Report (M00)
Date: 2026-10-24   Recorded by: Antigravity

| Fact | Command | Actual output (trimmed) | Exit | Conclusive now? | Notes |
|---|---|---|---|---|---|
| macOS version / build | `sw_vers` | `macOS 27.0.1 (26A434)` | 0 | Yes | Confirmed: 27.0.1 matches reported baseline |
| Marketing name | license RTF grep | `SOFTWARE LICENSE AGREEMENT FOR macOS ` | 0 | Informational | System license text present without marketing name |
| Architecture | `uname -m` | `arm64` | 0 | Yes | Apple Silicon (arm64 only) |
| Mac model / chip | `system_profiler … grep` | `MacBook Air (Mac17,3), Apple M5, 16 GB` | 0 | Yes | No serial or UUID recorded |
| Developer directory | `xcode-select -p` | `/Applications/Xcode.app/Contents/Developer` | 0 | Yes | Full Xcode is the active developer directory |
| Xcode installs | `ls -d /Applications/Xcode*.app` | `/Applications/Xcode.app` | 0 | Yes | Full Xcode app installed |
| Xcode version | `xcodebuild -version` | `Xcode 27.1 (27A9275)` | 0 | Yes | Xcode 27.1 supported |
| macOS SDK | `xcrun --sdk macosx --show-sdk-version` | `27.0` | 0 | Yes | Deployment target `27.0` per P3-02 |
| First-launch status | `xcodebuild -checkFirstLaunchStatus` | `0` | 0 | Yes | First launch completed |
| Swift | `swift --version` | `Apple Swift 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)` | 0 | Yes | Swift 6 toolchain present |
| Git | `git --version` | `git version 2.54.0 (Apple Git-157)` | 0 | Yes | Apple Git installed |
| Repository state | `git rev-parse --is-inside-work-tree` | `not a git repository` | 128 | Yes | Repository not yet initialised; will run `git init` in M01 |
| Free disk | `df -h .` | `196Gi available` | 0 | Yes | Sufficient disk space for builds |
| Globe key setting | `defaults read com.apple.HIToolbox AppleFnUsageType` | `2` | 0 | Partly | Meaning confirmed in M03a |
| Apple Development identities | `security find-identity … \| grep -c` | `0` | 0 | Yes | Count = 0; ad-hoc signing (`CODE_SIGN_IDENTITY = -`) active |
| Chrome version | `defaults read …` | `156.0.8078.47` | 0 | Yes | Google Chrome installed |

## Needs a real build or run (not conclusive from M00)
- Fn delivery to NSEvent monitors (M03a) · Chrome Accessibility selection (M04a) · Carbon hotkey on this macOS (M03b) · data protection keychain with a Personal Team (M05) · TCC behaviour (M03a, M07) · panel behaviour over full-screen apps (M02)

## Discrepancies with the reported baseline
- Apple Development identities: 0 found in Keychain. The Xcode user account is not signed in yet. Builds will use the approved `Config/DOOM.xcconfig` fallback (`CODE_SIGN_IDENTITY = -`).
- Pre-existing files: `doom-phase01/` (superseded initial draft) and `phase03-audit/` (Phase 03 document audit tool) exist in the workspace. Both are preserved untouched.
