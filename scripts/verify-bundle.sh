#!/usr/bin/env bash
set -euo pipefail

# scripts/verify-bundle.sh [debug|release]

CONFIG_RAW="${1:-debug}"

case "${CONFIG_RAW}" in
    [Dd][Ee][Bb][Uu][Gg])
        CONFIGURATION="Debug"
        APP="build/DerivedData/Build/Products/${CONFIGURATION}/DOOM.app"
        ;;
    [Rr][Ee][Ll][Ee][Aa][Ss][Ee])
        CONFIGURATION="Release"
        APP="build/DerivedData/Build/Products/${CONFIGURATION}/DOOM.app"
        ;;
    *)
        if [ -d "${CONFIG_RAW}" ]; then
            CONFIGURATION="Custom"
            APP="${CONFIG_RAW}"
        else
            echo "Unknown configuration or path: ${CONFIG_RAW}. Use 'debug', 'release', or a path to .app bundle." >&2
            exit 1
        fi
        ;;
esac

PLIST="${APP}/Contents/Info.plist"
BINARY="${APP}/Contents/MacOS/DOOM"

echo "Verifying bundle at ${APP}..."

if [ ! -d "${APP}" ]; then
    echo "ERROR: Bundle not found: ${APP}" >&2
    exit 1
fi

if [ ! -f "${PLIST}" ]; then
    echo "ERROR: Info.plist not found: ${PLIST}" >&2
    exit 1
fi

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: Executable not found: ${BINARY}" >&2
    exit 1
fi

# 1. CFBundleIdentifier
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "${PLIST}" 2>/dev/null || true)
if [ "${BUNDLE_ID}" != "com.tace.doom" ]; then
    echo "ERROR: Expected bundle identifier 'com.tace.doom', got '${BUNDLE_ID}'" >&2
    exit 1
fi

# 2. CFBundleDisplayName & CFBundleExecutable
DISPLAY_NAME=$(plutil -extract CFBundleDisplayName raw "${PLIST}" 2>/dev/null || true)
if [ "${DISPLAY_NAME}" != "DOOM" ]; then
    echo "ERROR: Expected CFBundleDisplayName 'DOOM', got '${DISPLAY_NAME}'" >&2
    exit 1
fi

EXECUTABLE=$(plutil -extract CFBundleExecutable raw "${PLIST}" 2>/dev/null || true)
if [ "${EXECUTABLE}" != "DOOM" ]; then
    echo "ERROR: Expected CFBundleExecutable 'DOOM', got '${EXECUTABLE}'" >&2
    exit 1
fi

# 3. LSMinimumSystemVersion
MIN_OS=$(plutil -extract LSMinimumSystemVersion raw "${PLIST}" 2>/dev/null || true)
if [ "${MIN_OS}" != "27.0" ]; then
    echo "ERROR: Expected LSMinimumSystemVersion '27.0', got '${MIN_OS}'" >&2
    exit 1
fi

# 4. Version formats
VERSION=$(plutil -extract CFBundleShortVersionString raw "${PLIST}" 2>/dev/null || true)
if ! echo "${VERSION}" | grep -qE '^[0-9]+(\.[0-9]+){0,2}$'; then
    echo "ERROR: Invalid version format: '${VERSION}'" >&2
    exit 1
fi

BUILD=$(plutil -extract CFBundleVersion raw "${PLIST}" 2>/dev/null || true)
if ! echo "${BUILD}" | grep -qE '^[0-9]+$'; then
    echo "ERROR: Invalid build format: '${BUILD}'" >&2
    exit 1
fi

# 5. No *UsageDescription keys
if plutil -p "${PLIST}" | grep -iE 'UsageDescription' >/dev/null 2>&1; then
    echo "ERROR: Found forbidden UsageDescription key in Info.plist" >&2
    plutil -p "${PLIST}" | grep -iE 'UsageDescription' >&2
    exit 1
fi

# 6. Architecture (arm64 only)
ARCHS=$(lipo -archs "${BINARY}")
if [ "${ARCHS}" != "arm64" ]; then
    echo "ERROR: Expected architecture 'arm64', got '${ARCHS}'" >&2
    exit 1
fi

# 7. Codesign verification
if ! codesign --verify --deep --strict "${APP}"; then
    echo "ERROR: codesign --verify --deep --strict failed on ${APP}" >&2
    exit 1
fi

# 8. Hardened runtime flag present
CS_DETAILS=$(codesign -dvv "${APP}" 2>&1)
if ! echo "${CS_DETAILS}" | grep -E 'flags=.*runtime' >/dev/null 2>&1; then
    echo "ERROR: Hardened runtime flag not found in codesign details" >&2
    echo "${CS_DETAILS}" >&2
    exit 1
fi

# 9. No app-sandbox entitlement
ENTITLEMENTS=$(codesign -d --entitlements - "${APP}" 2>&1 || true)
if echo "${ENTITLEMENTS}" | grep -q 'com.apple.security.app-sandbox'; then
    echo "ERROR: Forbidden app-sandbox entitlement found in ${APP}" >&2
    exit 1
fi

echo "Bundle verification passed for ${CONFIGURATION}: com.tace.doom, arm64, hardened runtime, no sandbox."
