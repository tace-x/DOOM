#!/usr/bin/env bash
set -euo pipefail

# scripts/install.sh
# Production Release build and safe local installation to ~/Applications/DOOM.app.
# Meets acceptance criteria PKG-01, PKG-02, PKG-03, LIFE-15.

echo "=================================================="
echo "DOOM — Release Build and Local Installation"
echo "=================================================="

# 1. Build Release configuration with warnings as errors
echo "Step 1: Building Release configuration..."
./scripts/build.sh release SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

# 2. Verify Release bundle before touching installed copy
echo "Step 2: Verifying Release bundle structure..."
./scripts/verify-bundle.sh release

# 3. Smoke test Release build before touching installed copy
echo "Step 3: Running smoke test on Release build..."
./scripts/smoke-test.sh release

# 4. Safely stop running DOOM instance if active
if pgrep -x DOOM >/dev/null 2>&1; then
    echo "Stopping currently running DOOM process..."
    pkill -x DOOM || true
    for _ in {1..10}; do
        if ! pgrep -x DOOM >/dev/null 2>&1; then
            break
        fi
        sleep 0.3
    done
fi

# 5. Destination setup in user home directory (never /Applications or sudo)
TARGET_DIR="${HOME}/Applications"
TARGET_APP="${TARGET_DIR}/DOOM.app"
mkdir -p "${TARGET_DIR}"

SOURCE_APP="build/DerivedData/Build/Products/Release/DOOM.app"

# 6. Preserve previous working copy during installation
BACKUP_DIR=""
if [ -d "${TARGET_APP}" ]; then
    BACKUP_DIR=$(mktemp -d "${TARGET_DIR}/.doom-backup-XXXXXX")
    ditto "${TARGET_APP}" "${BACKUP_DIR}/DOOM.app"
fi

rollback_on_failure() {
    if [ -n "${BACKUP_DIR}" ] && [ -d "${BACKUP_DIR}/DOOM.app" ]; then
        echo "WARNING: Installation step failed. Rolling back previous DOOM.app..." >&2
        rm -rf "${TARGET_APP}"
        ditto "${BACKUP_DIR}/DOOM.app" "${TARGET_APP}"
        rm -rf "${BACKUP_DIR}"
    fi
}
trap rollback_on_failure ERR

echo "Step 4: Installing to ${TARGET_APP}..."
rm -rf "${TARGET_APP}"
ditto "${SOURCE_APP}" "${TARGET_APP}"

# 7. Verify installed copy signature and bundle integrity
echo "Step 5: Verifying installed copy signature and bundle..."
codesign --verify --deep --strict "${TARGET_APP}"
./scripts/verify-bundle.sh "${TARGET_APP}"
./scripts/smoke-test.sh "${TARGET_APP}"

# Installation succeeded: clean up backup
trap - ERR
if [ -n "${BACKUP_DIR}" ] && [ -d "${BACKUP_DIR}" ]; then
    rm -rf "${BACKUP_DIR}"
fi

echo "=================================================="
echo "INSTALLATION SUCCESSFUL"
echo "Target: ${TARGET_APP}"
echo "Identifier: com.tace.doom"
echo "Architecture: arm64"
echo ""
echo "To launch DOOM:"
echo "  open ~/Applications/DOOM.app"
echo "=================================================="
