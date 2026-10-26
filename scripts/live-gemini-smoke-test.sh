#!/usr/bin/env bash
set -euo pipefail

# scripts/live-gemini-smoke-test.sh
# User-triggered live smoke test for Gemini API integration using macOS Keychain.
# Sends a minimal test prompt ("ping") using the key saved in Keychain.
# Never prints the API key or raw response body.

echo "=================================================="
echo "DOOM — Live Gemini API Smoke Test"
echo "=================================================="
echo "NOTE: This test sends a live request to Google Gemini."
echo "It consumes 1 request and ~5 tokens from your quota."
echo ""

SERVICE="com.tace.doom"
ACCOUNT="gemini-api-key"

echo "Reading API key from macOS Keychain (service: ${SERVICE}, account: ${ACCOUNT})..."
API_KEY=$(security find-generic-password -s "${SERVICE}" -a "${ACCOUNT}" -w 2>/dev/null || true)

if [ -z "${API_KEY}" ]; then
    echo "FAIL: No API key found in Keychain."
    echo "Please open DOOM, paste your Gemini API key in Settings, and save it first."
    exit 1
fi

echo "API key retrieved from Keychain (contents hidden)."
echo "Dispatching stateless test interaction to https://generativelanguage.googleapis.com/v1beta/interactions..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "https://generativelanguage.googleapis.com/v1beta/interactions" \
    -H "Content-Type: application/json" \
    -H "x-goog-api-key: ${API_KEY}" \
    -d '{
      "model": "gemini-3.5-flash",
      "input": "ping",
      "system_instruction": "Respond with the word pong only.",
      "generation_config": {
        "thinking_level": "low",
        "max_output_tokens": 4096
      },
      "store": false,
      "stream": false
    }')

HTTP_STATUS=$(echo "${RESPONSE}" | tail -n 1)
BODY=$(echo "${RESPONSE}" | sed '$d')

echo "HTTP Response Status: ${HTTP_STATUS}"

if [ "${HTTP_STATUS}" -eq 200 ]; then
    echo "SUCCESS: Gemini API connection verified!"
    echo "Stateless interaction succeeded with model 'gemini-3.5-flash'."
    exit 0
elif [ "${HTTP_STATUS}" -eq 503 ]; then
    echo "FAIL: Gemini service is temporarily unavailable (HTTP 503 Service Unavailable)."
    exit 1
elif [ "${HTTP_STATUS}" -eq 400 ] && echo "${BODY}" | grep -q "API_KEY_INVALID"; then
    echo "FAIL: API key was rejected by Gemini (HTTP 400 API_KEY_INVALID)."
    echo "Please replace the key in DOOM Settings with a valid key from Google AI Studio."
    exit 1
elif [ "${HTTP_STATUS}" -eq 401 ]; then
    echo "FAIL: API key was rejected by Gemini (HTTP 401 Unauthorized)."
    echo "Please replace the key in DOOM Settings with a valid key from Google AI Studio."
    exit 1
elif [ "${HTTP_STATUS}" -eq 429 ]; then
    echo "FAIL: Gemini rate limit or quota exceeded (HTTP 429)."
    exit 1
else
    echo "FAIL: Gemini request failed with HTTP ${HTTP_STATUS}."
    exit 1
fi
