#!/usr/bin/env bash

set -euo pipefail

BASE="${WORKER_URL}"
RELEASE_TAG="${RELEASE_TAG:-apk-latest}"
RELEASE_APK_NAME="${RELEASE_APK_NAME:-sa7bi-ai.apk}"

echo "============================================================"
echo "SA7BI AI - WORKER BASIC VERIFICATION"
echo "============================================================"

# ------------------------------------------------------------
# /health
# ------------------------------------------------------------

echo ""
echo "TESTING WORKER /health"

HTTP_CODE=$(curl \
  --silent \
  --show-error \
  --request GET \
  --connect-timeout 15 \
  --max-time 60 \
  --output /tmp/sa7bi-health.json \
  --write-out "%{http_code}" \
  "${BASE}/health")

echo "HTTP status: ${HTTP_CODE}"
cat /tmp/sa7bi-health.json || true

if [ "${HTTP_CODE}" != "200" ]; then
  echo ""
  echo "ERROR: Worker /health failed."
  exit 1
fi

echo ""
echo "Worker /health verified."

# ------------------------------------------------------------
# /
# ------------------------------------------------------------

echo ""
echo "TESTING WORKER ROOT"

HTTP_CODE=$(curl \
  --silent \
  --show-error \
  --request GET \
  --connect-timeout 15 \
  --max-time 60 \
  --output /tmp/sa7bi-root.json \
  --write-out "%{http_code}" \
  "${BASE}/")

echo "HTTP status: ${HTTP_CODE}"
cat /tmp/sa7bi-root.json || true

if [ "${HTTP_CODE}" != "200" ]; then
  echo ""
  echo "ERROR: Worker root endpoint failed."
  exit 1
fi

echo ""
echo "Worker root endpoint verified."

# ------------------------------------------------------------
# /v1/diagnostics
# ------------------------------------------------------------

echo ""
echo "TESTING WORKER /v1/diagnostics"

HTTP_CODE=$(curl \
  --silent \
  --show-error \
  --request GET \
  --connect-timeout 15 \
  --max-time 60 \
  --output /tmp/sa7bi-diagnostics.json \
  --write-out "%{http_code}" \
  "${BASE}/v1/diagnostics")

echo "HTTP status: ${HTTP_CODE}"
cat /tmp/sa7bi-diagnostics.json || true

if [ "${HTTP_CODE}" != "200" ]; then
  echo ""
  echo "ERROR: Worker diagnostics endpoint failed."
  exit 1
fi

echo ""
echo "Worker diagnostics verified."

# ------------------------------------------------------------
# /download
# ------------------------------------------------------------

DOWNLOAD_URL="${BASE}/download"

EXPECTED_APK_URL="https://github.com/ahmedsab34-prog/sa7bi_ai_new/releases/download/${RELEASE_TAG}/${RELEASE_APK_NAME}"

echo ""
echo "============================================================"
echo "TESTING WORKER APK DOWNLOAD ENDPOINT"
echo "============================================================"

echo "Worker URL:"
echo "${DOWNLOAD_URL}"

echo ""
echo "STEP 1: Testing GET /download without following redirect"

HTTP_CODE=$(curl \
  --silent \
  --show-error \
  --request GET \
  --connect-timeout 15 \
  --max-time 60 \
  --dump-header /tmp/sa7bi-download-headers.txt \
  --output /dev/null \
  --write-out "%{http_code}" \
  "${DOWNLOAD_URL}")

echo "Worker HTTP status: ${HTTP_CODE}"

if [ "${HTTP_CODE}" != "302" ]; then
  echo ""
  echo "ERROR: Worker /download did not return HTTP 302."
  echo ""
  echo "===== RESPONSE HEADERS ====="
  cat /tmp/sa7bi-download-headers.txt || true
  echo "============================"
  exit 1
fi

echo ""
echo "Worker returned the expected HTTP 302 redirect."

echo ""
echo "STEP 2: Verifying redirect destination"

LOCATION=$(grep -i '^location:' /tmp/sa7bi-download-headers.txt \
  | head -n 1 \
  | sed 's/^[Ll]ocation:[[:space:]]*//' \
  | tr -d '\r')

echo "Redirect Location:"
echo "${LOCATION}"

if [ -z "${LOCATION}" ]; then
  echo ""
  echo "ERROR: Worker returned 302 but no Location header."
  exit 1
fi

if [ "${LOCATION}" != "${EXPECTED_APK_URL}" ]; then
  echo ""
  echo "ERROR: Worker redirect points to an unexpected APK URL."
  echo ""
  echo "Expected:"
  echo "${EXPECTED_APK_URL}"
  echo ""
  echo "Actual:"
  echo "${LOCATION}"
  exit 1
fi

echo ""
echo "Redirect destination is correct."

echo ""
echo "STEP 3: Following Worker redirect to the APK"

FINAL_HTTP_CODE=$(curl \
  --silent \
  --show-error \
  --location \
  --request GET \
  --connect-timeout 15 \
  --max-time 120 \
  --output /dev/null \
  --write-out "%{http_code}" \
  "${DOWNLOAD_URL}")

echo "Final HTTP status: ${FINAL_HTTP_CODE}"

if [ "${FINAL_HTTP_CODE}" != "200" ]; then
  echo ""
  echo "ERROR: Worker redirect did not reach the APK successfully."
  exit 1
fi

echo ""
echo "============================================================"
echo "WORKER APK DOWNLOAD VERIFIED"
echo "============================================================"
echo "GET /download       : 302"
echo "Redirect target     : verified"
echo "Final APK response  : 200"
echo "============================================================"
