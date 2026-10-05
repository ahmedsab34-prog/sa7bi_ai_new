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
# Normal media files are verified with a bounded request.
#
# Live radio streams are different:
# they normally never finish, so curl may return exit code 28
# after successfully receiving audio data.
#
# For live streams, a timeout is NOT considered a failure when:
#   1. HTTP status is 2xx or 3xx
#   2. Content-Type is audio/*
#   3. A meaningful amount of data was received
#
# This prevents false CI failures on healthy infinite streams.

probe_url() {
  local NAME="$1"
  local URL="$2"
  local MAX_TIME="${3:-30}"
  local LIVE_STREAM="${4:-false}"

  echo ""
  echo "------------------------------------------------------------"
  echo "MEDIA PROBE: ${NAME}"
  echo "URL: ${URL}"
  echo "------------------------------------------------------------"

  if [[ ! "${URL}" =~ ^https?:// ]]; then
    echo "ERROR: URL is not HTTP/HTTPS."
    return 1
  fi

  local META=""
  local CURL_STATUS=0
  local HTTP_CODE=""
  local CONTENT_TYPE=""
  local FINAL_URL=""
  local SIZE_DOWNLOAD="0"

  # curl can legitimately return 28 for an infinite live stream.
  # Disable errexit only around curl so we can inspect its actual
  # HTTP/content/byte results before deciding pass/fail.
  set +e

  META=$(curl \
    --silent \
    --show-error \
    --location \
    --range 0-0 \
    --connect-timeout 15 \
    --max-time "${MAX_TIME}" \
    --output /dev/null \
    --write-out "%{http_code}|%{content_type}|%{url_effective}|%{size_download}" \
    "${URL}" 2>/tmp/sa7bi-media-curl-error)

  CURL_STATUS=$?

  set -e

  HTTP_CODE="${META%%|*}"

  local REST="${META#*|}"
  CONTENT_TYPE="${REST%%|*}"

  REST="${REST#*|}"
  FINAL_URL="${REST%%|*}"

  SIZE_DOWNLOAD="${REST#*|}"

  if [[ -z "${SIZE_DOWNLOAD}" || "${SIZE_DOWNLOAD}" == "${REST}" ]]; then
    SIZE_DOWNLOAD="0"
  fi

  echo "curl status  : ${CURL_STATUS}"
  echo "HTTP status  : ${HTTP_CODE}"
  echo "Content type : ${CONTENT_TYPE}"
  echo "Bytes read   : ${SIZE_DOWNLOAD}"
  echo "Final URL    : ${FINAL_URL}"

  # ----------------------------------------------------------
  # Live radio stream handling
  # ----------------------------------------------------------
  #
  # A live stream normally keeps sending bytes forever.
  # Therefore curl may exit with 28 after the timeout even though
  # the stream is healthy.
  #
  # Accept timeout only when the server actually responded with
  # a valid HTTP status, audio content type, and meaningful data.
  #
  if [[ "${LIVE_STREAM}" == "true" ]]; then
    if [[ "${HTTP_CODE}" =~ ^(2|3)[0-9][0-9]$ ]] \
      && [[ "${CONTENT_TYPE,,}" == audio/* ]] \
      && [[ "${SIZE_DOWNLOAD}" =~ ^[0-9]+$ ]] \
      && (( SIZE_DOWNLOAD >= 32768 )); then

      if [[ "${CURL_STATUS}" -eq 28 ]]; then
        echo "RESULT: PASS - live audio stream is reachable."
        echo "Note: curl timeout is expected because the stream is continuous."
        return 0
      fi

      if [[ "${CURL_STATUS}" -eq 0 ]]; then
        echo "RESULT: PASS - live audio stream is reachable."
        return 0
      fi

      echo "RESULT: PASS - live audio stream delivered valid audio data."
      return 0
    fi

    echo "RESULT: FAIL - live stream did not provide valid audio data."

    if [[ -s /tmp/sa7bi-media-curl-error ]]; then
      cat /tmp/sa7bi-media-curl-error
    fi

    return 1
  fi

  # ----------------------------------------------------------
  # Normal media handling
  # ----------------------------------------------------------

  if [ "${CURL_STATUS}" -ne 0 ]; then
    echo "RESULT: FAIL - curl could not reach the media URL."

    if [[ -s /tmp/sa7bi-media-curl-error ]]; then
      cat /tmp/sa7bi-media-curl-error
    fi

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
  45 \
  false

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

# Prefer HTTPS stations first.
# A single unavailable station must never fail the whole test.
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
echo "Live-stream validation accepts continuous audio streams"
echo "when HTTP, content type, and received bytes are valid."

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
    20 \
    true
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
  45 \
  false

echo ""
echo "============================================================"
echo "MEDIA URL VERIFICATION PASSED"
echo "============================================================"
echo "Quran audio URL : REACHABLE"
echo "Radio stream    : REACHABLE"
echo "Podcast feed    : REACHABLE"
echo "============================================================"
