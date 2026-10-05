#!/usr/bin/env bash

set -euo pipefail

BASE="${WORKER_URL}"
TEST_DEVICE_ID="github-actions-diagnostic-device"

echo "============================================================"
echo "SA7BI AI - CREDITS SERVICE VERIFICATION"
echo "============================================================"

rm -f \
  /tmp/sa7bi-credits.json \
  /tmp/sa7bi-credits.curl-error

CREDITS_META=$(curl \
  --silent \
  --show-error \
  --request GET \
  --connect-timeout 15 \
  --max-time 60 \
  --header "X-Sa7bi-Device-Id: ${TEST_DEVICE_ID}" \
  --output /tmp/sa7bi-credits.json \
  --write-out "%{http_code} %{time_total}" \
  "${BASE}/v1/credits" \
  2>/tmp/sa7bi-credits.curl-error)

CREDITS_STATUS=$?
CREDITS_HTTP="${CREDITS_META%% *}"
CREDITS_TIME="${CREDITS_META#* }"

echo ""
echo "HTTP status   : ${CREDITS_HTTP}"
echo "Response time : ${CREDITS_TIME}s"

echo ""
echo "Response:"
head -c 3000 /tmp/sa7bi-credits.json 2>/dev/null || true
echo ""

if [ "${CREDITS_STATUS}" -ne 0 ]; then
  echo ""
  echo "RESULT: CREDITS CURL FAILURE"
  cat /tmp/sa7bi-credits.curl-error 2>/dev/null || true
  exit 1
fi

if [ "${CREDITS_HTTP}" != "200" ]; then
  echo ""
  echo "RESULT: CREDITS HTTP FAILURE"
  exit 1
fi

if ! grep -q '"ok"[[:space:]]*:[[:space:]]*true' /tmp/sa7bi-credits.json; then
  echo ""
  echo "RESULT: CREDITS RESPONSE FAILURE"
  exit 1
fi

echo ""
echo "============================================================"
echo "CREDITS SERVICE VERIFIED"
echo "============================================================"

python3 - <<'PY'
import json

path = "/tmp/sa7bi-credits.json"

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as exc:
    print(f"WARNING: Could not parse credits response: {exc}")
    raise SystemExit(0)

print(f"ok       : {data.get('ok')}")
print(f"balance  : {data.get('balance')}")
print(f"credits  : {data.get('credits')}")
print(f"dailyCap : {data.get('dailyCap')}")
print(f"date     : {data.get('date')}")

if data.get("balance") is not None:
    try:
        balance = int(data["balance"])

        if balance < 0:
            print("ERROR: Credits balance is negative.")
            raise SystemExit(1)
    except (TypeError, ValueError):
        print("WARNING: Credits balance is not numeric.")
PY

echo ""
echo "Credits endpoint is operational."
echo "============================================================"
