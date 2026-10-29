#!/usr/bin/env bash
set -euo pipefail

# scripts/uninstall.sh
# Uninstallation workflow for DOOM (acceptance criterion PKG-04).
# Supports --dry-run mode to inspect planned actions without making changes.

DRY_RUN=false
for arg in "$@"; do
    if [ "${arg}" = "--dry-run" ]; then
        DRY_RUN=true
    fi
done

TARGET_APP="${HOME}/Applications/DOOM.app"
BUNDLE_ID="com.tace.doom"

echo "=================================================="
echo "DOOM — Uninstaller"
echo "=================================================="

echo "Planned uninstallation actions:"
echo "1. Remind user to remove Keychain API key within DOOM (Keychain item: ${BUNDLE_ID} / gemini-api-key)."
echo "2. Terminate any running DOOM application instance."
echo "3. Remove application bundle at ${TARGET_APP}."
echo "4. Delete preferences domain: defaults delete ${BUNDLE_ID}."
echo "5. Reset Accessibility permission: tccutil reset Accessibility ${BUNDLE_ID}."
echo ""
echo "Note: Repository and build folders will remain untouched."
echo "=================================================="

if [ "${DRY_RUN}" = true ]; then
    echo "DRY RUN MODE: No modifications will be made."
    echo "Dry run complete. Exiting cleanly (exit 0)."
    exit 0
fi

echo "IMPORTANT: The Gemini API key is stored in the macOS Data Protection Keychain,"
echo "which external scripts cannot delete without user interaction."
echo "If you have not already done so, launch DOOM, open Settings, and click [Remove API Key]."
echo ""
read -r -p "Do you want to proceed with uninstallation? (y/N): " CONFIRMATION

case "${CONFIRMATION}" in
    [Yy]|[Yy][Ee][Ss])
        echo "Proceeding with uninstallation..."
        ;;
    *)
        echo "Uninstallation cancelled by user. No changes made."
        exit 0
        ;;
esac

# 1. Quit running DOOM
if pgrep -x DOOM >/dev/null 2>&1; then
    echo "Stopping running DOOM instance..."
    pkill -x DOOM || true
    sleep 0.5
fi

# 2. Remove ~/Applications/DOOM.app
if [ -d "${TARGET_APP}" ]; then
    echo "Removing ${TARGET_APP}..."
    rm -rf "${TARGET_APP}"
else
    echo "Notice: ${TARGET_APP} was not found."
fi

# 3. Delete defaults
echo "Removing preferences (${BUNDLE_ID})..."
defaults delete "${BUNDLE_ID}" 2>/dev/null || true

# 4. Reset TCC Accessibility
echo "Resetting Accessibility permission..."
tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || true

echo "=================================================="
echo "Uninstallation complete."
echo "=================================================="
