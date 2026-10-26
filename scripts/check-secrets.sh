#!/usr/bin/env bash
set -euo pipefail

# scripts/check-secrets.sh
# Scans tracked and untracked-but-not-ignored files for secrets and credentials.

echo "Running secret scan..."

# Find all candidate files (tracked + untracked non-ignored)
FILES=$(git ls-files --cached --others --exclude-standard)

if [ -z "${FILES}" ]; then
    echo "No files found to scan."
    exit 0
fi

VIOLATIONS=0

# 1. Check for credential-type files that would be committed
for file in ${FILES}; do
    filename=$(basename "${file}")
    case "${filename}" in
        .env|.env.*|*.p12|*.pem|*.key|*.mobileprovision|*.provisionprofile|Local.xcconfig)
            echo "ERROR: Credential file candidate staged/tracked: ${file}" >&2
            VIOLATIONS=$((VIOLATIONS + 1))
            ;;
    esac
done

# 2. Check for Google API key patterns: AIza[0-9A-Za-z_-]{35}
API_KEY_MATCHES=$(echo "${FILES}" | xargs grep -En 'AIza[0-9A-Za-z_-]{35}' 2>/dev/null || true)
if [ -n "${API_KEY_MATCHES}" ]; then
    # Filter out known synthetic/test patterns in docs or tests if clearly dummy
    # But per spec: check-secrets scans all files. If any real or fake key is found, report it unless excluded.
    echo "ERROR: Potential Google API key pattern detected:" >&2
    echo "${API_KEY_MATCHES}" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# 3. Check for PEM private key blocks
KEY_BLOCKS=$(echo "${FILES}" | xargs grep -En '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' 2>/dev/null || true)
if [ -n "${KEY_BLOCKS}" ]; then
    echo "ERROR: Private key block detected:" >&2
    echo "${KEY_BLOCKS}" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
fi

if [ ${VIOLATIONS} -gt 0 ]; then
    echo "Secret scan failed with ${VIOLATIONS} violation(s)." >&2
    exit 1
fi

echo "Secret scan passed: zero secrets or credential files detected."
