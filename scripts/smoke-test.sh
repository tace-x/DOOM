#!/usr/bin/env bash
set -euo pipefail

# scripts/smoke-test.sh [debug|release]

CONFIG_RAW="${1:-debug}"

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

APP="build/DerivedData/Build/Products/${CONFIGURATION}/DOOM.app"
BINARY="${APP}/Contents/MacOS/DOOM"

echo "Running smoke test on ${CONFIGURATION} build..."

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: Executable not found at ${BINARY}" >&2
    exit 1
fi

TMP_LOG=$(mktemp)
trap 'rm -f "${TMP_LOG}"' EXIT

# Launch with 15s timeout
set +e
python3 -c '
import subprocess, sys, time

proc = subprocess.Popen(
    [sys.argv[1], "--doom-smoke-test"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True
)

try:
    stdout, stderr = proc.communicate(timeout=15)
    with open(sys.argv[2], "w") as f:
        f.write(stdout)
    if proc.returncode != 0:
        print(f"Process exited with non-zero code: {proc.returncode}", file=sys.stderr)
        if stderr:
            print(f"stderr: {stderr}", file=sys.stderr)
        sys.exit(proc.returncode)
except subprocess.TimeoutExpired:
    proc.kill()
    print("ERROR: Smoke test timed out after 15 seconds", file=sys.stderr)
    sys.exit(124)
' "${BINARY}" "${TMP_LOG}"

STATUS=$?
set -e

if [ $STATUS -ne 0 ]; then
    echo "Smoke test failed with exit code $STATUS" >&2
    exit $STATUS
fi

if ! grep -Fxq "DOOM_SMOKE_OK" "${TMP_LOG}"; then
    echo "ERROR: Expected output marker 'DOOM_SMOKE_OK' not found in stdout." >&2
    echo "stdout output was:" >&2
    cat "${TMP_LOG}" >&2
    exit 1
fi

echo "Smoke test passed: DOOM_SMOKE_OK received, clean exit 0."
