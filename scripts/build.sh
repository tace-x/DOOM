#!/usr/bin/env bash
set -euo pipefail

# scripts/build.sh [debug|release] [extra xcodebuild args...]

CONFIG_RAW="${1:-debug}"
shift || true

case "${CONFIG_RAW}" in
    [Dd][Ee][Bb][Uu][Gg])
        CONFIGURATION="Debug"
        ;;
    [Rr][Ee][Ll][Ee][Aa][Ss][Ee])
        CONFIGURATION="Release"
        ;;
    *)
        echo "Unknown configuration: ${CONFIG_RAW}. Use 'debug' or 'release'." >&2
        exit 1
        ;;
esac

echo "Building DOOM (${CONFIGURATION})..."

mkdir -p build/DerivedData

xcodebuild \
    -project DOOM.xcodeproj \
    -scheme DOOM \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath build/DerivedData \
    build \
    "$@"

APP_PATH="build/DerivedData/Build/Products/${CONFIGURATION}/DOOM.app"
if [ ! -d "${APP_PATH}" ]; then
    echo "Build failed: ${APP_PATH} does not exist" >&2
    exit 1
fi

echo "Build succeeded: ${APP_PATH}"
