#!/usr/bin/env bash

set -u
set -o pipefail

BASE="${WORKER_URL}"
FAILURES=0

echo "========================================"
echo "Sa7bi AI - Real AI Verification"
echo "========================================"
echo "Worker: ${BASE}"
echo "Run: ${GITHUB_RUN_ID}"
echo ""

post_ai() {
  local NAME="$1"
  local URL="$2"
  local BODY="$3"
  local DEVICE="$4"
  local FILE="$5"

  echo "----------------------------------------"
  echo "Testing: ${NAME}"
  echo "URL: ${URL}"
  echo "Device: ${DEVICE}"
  echo ""

  local HTTP_CODE

  HTTP_CODE="$(
    curl -sS \
      --max-time 180 \
      -o "${FILE}" \
      -w '%{http_code}' \
      -X POST "${URL}" \
      -H 'Content-Type: application/json' \
      -H 'Accept: application/json' \
      -H 'Cache-Control: no-cache' \
      -H 'Pragma: no-cache' \
      -H "X-Sa7bi-Device-Id: ${DEVICE}" \
      -H "X-Sa7bi-Request-Id: github-actions-${GITHUB_RUN_ID}-${DEVICE}" \
      --data "${BODY}" \
      || true
  )"

  echo "HTTP: ${HTTP_CODE}"

  if [ "${HTTP_CODE}" != "200" ]; then
    echo "ERROR: ${NAME} returned HTTP ${HTTP_CODE}"
    [ -s "${FILE}" ] && cat "${FILE}" || true
    FAILURES=$((FAILURES + 1))
    return
  fi

  if ! grep -q '"ok"[[:space:]]*:[[:space:]]*true' "${FILE}"; then
    echo "ERROR: ${NAME} did not return ok=true"
    cat "${FILE}"
    FAILURES=$((FAILURES + 1))
    return
  fi

  echo "OK: ${NAME}"
}

PRIMARY_URL="${BASE}/v1/chat"
PRIMARY_BODY='{"messages":[{"role":"user","content":"رد بكلمة واحدة فقط: مرحبًا"}]}'
PRIMARY_DEVICE="github-actions-ai-primary-${GITHUB_RUN_ID}"
PRIMARY_FILE="/tmp/sa7bi-ai-primary.json"

post_ai \
  "AI primary text" \
  "${PRIMARY_URL}" \
  "${PRIMARY_BODY}" \
  "${PRIMARY_DEVICE}" \
  "${PRIMARY_FILE}"

echo ""
echo "Checking primary provider..."

if [ -s "${PRIMARY_FILE}" ]; then
  if grep -q '"provider"[[:space:]]*:[[:space:]]*"gemini"' "${PRIMARY_FILE}"; then
    echo "Primary provider: Gemini"
  elif \
    grep -q '"provider"[[:space:]]*:[[:space:]]*"cloudflare-workers-ai"' "${PRIMARY_FILE}" \
    && grep -q '"fallback"[[:space:]]*:[[:space:]]*true' "${PRIMARY_FILE}" \
    && grep -q '"fallbackReason"[[:space:]]*":' "${PRIMARY_FILE}"
  then
    echo "Primary request used Cloudflare Workers AI fallback."
  else
    echo "ERROR: Primary AI response has an invalid provider/fallback state."
    cat "${PRIMARY_FILE}"
    FAILURES=$((FAILURES + 1))
  fi
else
  echo "ERROR: Primary AI response file is empty."
  FAILURES=$((FAILURES + 1))
fi

FALLBACK_URL="${BASE}/v1/chat?provider=workers"
FALLBACK_BODY='{"messages":[{"role":"user","content":"رد بكلمة واحدة فقط: اختبار"}]}'
FALLBACK_DEVICE="github-actions-ai-fallback-${GITHUB_RUN_ID}"
FALLBACK_FILE="/tmp/sa7bi-ai-fallback.json"

post_ai \
  "AI forced fallback" \
  "${FALLBACK_URL}" \
  "${FALLBACK_BODY}" \
  "${FALLBACK_DEVICE}" \
  "${FALLBACK_FILE}"

echo ""
echo "Checking forced fallback provider..."

if [ -s "${FALLBACK_FILE}" ]; then
  if grep -q '"provider"[[:space:]]*:[[:space:]]*"cloudflare-workers-ai"' "${FALLBACK_FILE}"; then
    echo "Forced fallback provider: Cloudflare Workers AI"
  else
    echo "ERROR: Forced fallback did not report Cloudflare Workers AI."
    cat "${FALLBACK_FILE}"
    FAILURES=$((FAILURES + 1))
  fi
else
  echo "ERROR: Forced fallback response file is empty."
  FAILURES=$((FAILURES + 1))
fi

IMAGE_URL="${BASE}/v1/image"
IMAGE_BODY='{"prompt":"صورة اختبار بسيطة جدًا: تفاحة حمراء على خلفية بيضاء","aspectRatio":"1:1","imageSize":"1K"}'
IMAGE_DEVICE="github-actions-ai-image-${GITHUB_RUN_ID}"
IMAGE_FILE="/tmp/sa7bi-ai-image.json"

post_ai \
  "AI image generation" \
  "${IMAGE_URL}" \
  "${IMAGE_BODY}" \
  "${IMAGE_DEVICE}" \
  "${IMAGE_FILE}"

echo ""
echo "Checking generated image..."

if [ -s "${IMAGE_FILE}" ]; then
  if grep -q '"imageDataUrl"[[:space:]]*":' "${IMAGE_FILE}"; then
    echo "Image generation returned imageDataUrl."
  else
    echo "ERROR: Image generation response does not contain imageDataUrl."
    cat "${IMAGE_FILE}"
    FAILURES=$((FAILURES + 1))
  fi
else
  echo "ERROR: Image generation response file is empty."
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "========================================"
echo "AI verification summary"
echo "========================================"

if [ "${FAILURES}" -eq 0 ]; then
  echo "AI primary       : VERIFIED"
  echo "AI fallback      : VERIFIED"
  echo "AI image         : VERIFIED"
  echo ""
  echo "REAL AI VERIFICATION PASSED"
  exit 0
fi

echo "AI verification failures: ${FAILURES}"
echo "REAL AI VERIFICATION FAILED"
exit 1
