#!/usr/bin/env bash
set -euo pipefail

# scripts/verify.sh
# Complete build and verification sequence for DOOM.
# Outputs to stdout and logs to build/verification.log.

mkdir -p build/logs

run_verified() {
    echo "=================================================="
    echo "STEP: $1"
    echo "=================================================="
    shift
    "$@"
}

{
    echo "Starting DOOM verification run at $(date)"

    # 1. Environment check
    run_verified "Environment Developer Directory" bash -c '
        DEV_DIR=$(xcode-select -p)
        if [[ "${DEV_DIR}" == *CommandLineTools* ]]; then
            echo "ERROR: Active developer directory is Command Line Tools (${DEV_DIR}). Full Xcode required." >&2
            exit 1
        fi
        echo "Active developer directory: ${DEV_DIR}"
    '

    # 2. Secret scan
    run_verified "Secret Scan" ./scripts/check-secrets.sh

    # 3. Review checks
    run_verified "Architecture & Review Checks" ./scripts/review-checks.sh

    # 4. Package unit tests (Swift Testing, warnings as errors)
    run_verified "Package Unit Tests (Core)" swift test --package-path DoomKit --test-product DoomCoreTests -Xswiftc -warnings-as-errors
    run_verified "Package Unit Tests (Services)" swift test --package-path DoomKit --test-product DoomServicesTests -Xswiftc -warnings-as-errors
    run_verified "Package Unit Tests (Features)" swift test --package-path DoomKit --test-product DoomFeaturesTests -Xswiftc -warnings-as-errors

    # 5. Debug build with warnings as errors
    run_verified "Debug Build" ./scripts/build.sh debug SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

    # 6. Verify Debug bundle
    run_verified "Verify Debug Bundle" ./scripts/verify-bundle.sh debug

    # 7. Smoke test Debug build
    run_verified "Smoke Test Debug" ./scripts/smoke-test.sh debug

    # 8. Release build with warnings as errors
    run_verified "Release Build" ./scripts/build.sh release SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

    # 9. Verify Release bundle
    run_verified "Verify Release Bundle" ./scripts/verify-bundle.sh release

    # 10. Smoke test Release build
    run_verified "Smoke Test Release" ./scripts/smoke-test.sh release

    # 11. Script syntax verification
    run_verified "Script Syntax Check" bash -c '
        for script in scripts/*.sh; do
            bash -n "${script}"
        done
        echo "All scripts passed syntax validation (bash -n)."
    '

    # 12. Uninstaller dry run
    run_verified "Uninstaller Dry Run" ./scripts/uninstall.sh --dry-run

    # 13. Git hygiene check (.gitignore patterns)
    run_verified "Git Hygiene" git check-ignore -v build .build Config/Local.xcconfig DoomKit/.build DoomKit/.swiftpm

    echo "=================================================="
    echo "ALL CHECKS PASSED"
    echo "=================================================="
} 2>&1 | tee build/verification.log
