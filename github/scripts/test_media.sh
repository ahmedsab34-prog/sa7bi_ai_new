#!/usr/bin/env bash

set -euo pipefail

BASE="${WORKER_URL}"

echo "============================================================"
echo "SA7BI AI - REAL MEDIA URL VERIFICATION"
echo "============================================================"

# This script verifies actual media URLs returned by the backend.
# It does not modify backend data.
# It does not require the Flutter APK.
#
# Sources:
#   /tmp/sa7bi-quran.json
#   /tmp/sa7bi-radio-eg.json
#   /tmp/sa7bi-podcasts.json
#
# A media URL is considered reachable when curl receives a valid
# HTTP response (2xx or 3xx) within the configured timeout.
#
# For audio streams, a small byte-range request is used because
# many streaming servers do not implement HEAD correctly.

probe_url() {
  local NAME="$1"
  local URL="$2"
  local MAX_TIME="${3:-30}"

  echo ""
  echo "------------------------------------------------------------"
  echo "MEDIA PROBE: ${NAME}"
  echo "URL: ${URL}"
  echo "------------------------------------------------------------"

  if [[ ! "${URL}" =~ ^https?:// ]]; then
    echo "ERROR: URL is not HTTP/HTTPS."
    return 1
  fi

  local META
  local CURL_STATUS
  local HTTP_CODE
  local CONTENT_TYPE
  local FINAL_URL

  META=$(curl \
    --silent \
    --show-error \
    --location \
    --range 0-0 \
    --connect-timeout 15 \
    --max-time "${MAX_TIME}" \
    --output /dev/null \
    --write-out "%{http_code}|%{content_type}|%{url_effective}" \
    "${URL}" 2>/tmp/sa7bi-media-curl-error)

  CURL_STATUS=$?

  HTTP_CODE="${META%%|*}"
  local REST="${META#*|}"
  CONTENT_TYPE="${REST%%|*}"
  FINAL_URL="${REST#*|}"

  echo "curl status  : ${CURL_STATUS}"
  echo "HTTP status  : ${HTTP_CODE}"
  echo "Content type : ${CONTENT_TYPE}"
  echo "Final URL    : ${FINAL_URL}"

  if [ "${CURL_STATUS}" -ne 0 ]; then
    echo "RESULT: FAIL - curl could not reach the media URL."
    cat /tmp/sa7bi-media-curl-error 2>/dev/null || true
    return 1
  fi

  case "${HTTP_CODE}" in
    2*|3*)
      echo "RESULT: PASS - media URL is reachable."
      return 0
      ;;
    *)
      echo "RESULT: FAIL - unexpected HTTP status."
      return 1
      ;;
  esac
}

# ------------------------------------------------------------
# Quran
# ------------------------------------------------------------

QURAN_URL=$(python3 - <<'PY'
import json
import re
import sys

path = "/tmp/sa7bi-quran.json"

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as exc:
    print(f"ERROR:{exc}")
    sys.exit(1)

reciters = data.get("reciters")
suras = data.get("suras") or data.get("suwar")

if not isinstance(reciters, list):
    print("ERROR:reciters is not a list")
    sys.exit(1)

if not isinstance(suras, list):
    print("ERROR:suras is not a list")
    sys.exit(1)

server = None

for reciter in reciters:
    if not isinstance(reciter, dict):
        continue

    moshaf = reciter.get("moshaf")

    if not isinstance(moshaf, list):
        continue

    for entry in moshaf:
        if not isinstance(entry, dict):
            continue

        candidate = entry.get("server") or entry.get("url")

        if isinstance(candidate, str) and re.match(
            r"^https?://",
            candidate.strip(),
            re.I,
        ):
            server = candidate.strip().rstrip("/")
            break

    if server:
        break

if not server:
    print("ERROR:no Quran server")
    sys.exit(1)

surah_id = None

for sura in suras:
    if not isinstance(sura, dict):
        continue

    raw_id = str(sura.get("id", ""))

    if raw_id.isdigit():
        number = int(raw_id)

        if 1 <= number <= 114:
            surah_id = number
            break

if surah_id is None:
    print("ERROR:no valid Quran surah id")
    sys.exit(1)

print(f"{server}/{surah_id:03d}.mp3")
PY
)

if [[ "${QURAN_URL}" == ERROR:* ]]; then
  echo ""
  echo "ERROR: Could not construct a Quran media URL."
  echo "${QURAN_URL}"
  exit 1
fi

echo ""
echo "============================================================"
echo "QURAN MEDIA"
echo "============================================================"

probe_url \
  "First Quran audio file" \
  "${QURAN_URL}" \
  45

# ------------------------------------------------------------
# Radio
# ------------------------------------------------------------

RADIO_CANDIDATES=$(python3 - <<'PY'
import json
import re
import sys

path = "/tmp/sa7bi-radio-eg.json"

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as exc:
    print(f"ERROR:{exc}")
    sys.exit(1)

stations = data.get("stations") or data.get("items")

if not isinstance(stations, list):
    print("ERROR:stations is not a list")
    sys.exit(1)

https_urls = []
http_urls = []

for station in stations:
    if not isinstance(station, dict):
        continue

    candidate = (
        station.get("streamUrl")
        or station.get("url_resolved")
        or station.get("url")
    )

    if not isinstance(candidate, str):
        continue

    candidate = candidate.strip()

    if not re.match(r"^https?://", candidate, re.I):
        continue

    if candidate.lower().startswith("https://"):
        if candidate not in https_urls:
            https_urls.append(candidate)

    elif candidate.lower().startswith("http://"):
        if candidate not in http_urls:
            http_urls.append(candidate)

# Test every HTTPS station before trying HTTP.
# A single dead/slow stream must not fail the entire CI job
# when another station works.
for url in https_urls + http_urls:
    print(url)

if not (https_urls or http_urls):
    print("ERROR:no radio stream")
    sys.exit(1)
PY
)

if [[ "${RADIO_CANDIDATES}" == ERROR:* ]]; then
  echo ""
  echo "ERROR: Could not find any usable radio stream."
  echo "${RADIO_CANDIDATES}"
  exit 1
fi

echo ""
echo "============================================================"
echo "RADIO MEDIA"
echo "============================================================"
echo "Testing radio streams until one responds successfully."

RADIO_URL=""
RADIO_ATTEMPTS=0

while IFS= read -r CANDIDATE; do
  [[ -z "${CANDIDATE}" ]] && continue

  RADIO_ATTEMPTS=$((RADIO_ATTEMPTS + 1))

  echo ""
  echo "Radio candidate #${RADIO_ATTEMPTS}:"
  echo "${CANDIDATE}"

  if [[ "${CANDIDATE}" == http://* ]]; then
    echo "WARNING: Candidate uses HTTP; Android cleartext policy may block it."
  fi

  if probe_url \
    "Egypt radio candidate #${RADIO_ATTEMPTS}" \
    "${CANDIDATE}" \
    20
  then
    RADIO_URL="${CANDIDATE}"
    break
  fi

  echo "Candidate did not respond successfully; trying the next station."
done <<< "${RADIO_CANDIDATES}"

if [[ -z "${RADIO_URL}" ]]; then
  echo ""
  echo "RESULT: FAIL - no Egypt radio stream responded successfully."
  echo "Tested ${RADIO_ATTEMPTS} candidate stream(s)."
  exit 1
fi

echo ""
echo "Selected reachable radio stream:"
echo "${RADIO_URL}"

# ------------------------------------------------------------
# Podcast
# ------------------------------------------------------------

PODCAST_URL=$(python3 - <<'PY'
import json
import re
import sys

path = "/tmp/sa7bi-podcasts.json"

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as exc:
    print(f"ERROR:{exc}")
    sys.exit(1)

items = data.get("items")

if not isinstance(items, list):
    print("ERROR:items is not a list")
    sys.exit(1)

for item in items:
    if not isinstance(item, dict):
        continue

    feed = item.get("feedUrl")

    if isinstance(feed, str) and re.match(
        r"^https?://",
        feed.strip(),
        re.I,
    ):
        print(feed.strip())
        sys.exit(0)

print("ERROR:no podcast feed")
sys.exit(1)
PY
)

if [[ "${PODCAST_URL}" == ERROR:* ]]; then
  echo ""
  echo "ERROR: Could not find a playable podcast feed URL."
  echo "${PODCAST_URL}"
  exit 1
fi

echo ""
echo "============================================================"
echo "PODCAST MEDIA"
echo "============================================================"
echo "Selected feed:"
echo "${PODCAST_URL}"

probe_url \
  "First podcast feed" \
  "${PODCAST_URL}" \
  45

echo ""
echo "============================================================"
echo "MEDIA URL VERIFICATION PASSED"
echo "============================================================"
echo "Quran audio URL : REACHABLE"
echo "Radio stream    : REACHABLE"
echo "Podcast feed    : REACHABLE"
echo "============================================================"
