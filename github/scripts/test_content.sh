#!/usr/bin/env bash

set -u
set -o pipefail

BASE="${WORKER_URL:?WORKER_URL is required}"
FAILURES=0
WARNINGS=0

test_endpoint() {
  local NAME="$1"
  local URL="$2"
  local EXPECTED="$3"
  local FILE="$4"
  local MAX_TIME="$5"

  echo ""
  echo "============================================================"
  echo "TEST: ${NAME}"
  echo "URL : ${URL}"
  echo "============================================================"

  rm -f "${FILE}" "${FILE}.curl-error"

  local META
  META=$(curl \
    --silent \
    --show-error \
    --request GET \
    --connect-timeout 15 \
    --max-time "${MAX_TIME}" \
    --output "${FILE}" \
    --write-out "%{http_code} %{time_total}" \
    "${URL}" 2>"${FILE}.curl-error")

  local CURL_STATUS=$?
  local HTTP_CODE="${META%% *}"
  local RESPONSE_TIME="${META#* }"

  echo "HTTP status   : ${HTTP_CODE:-UNKNOWN}"
  echo "Response time : ${RESPONSE_TIME:-UNKNOWN}s"

  echo "Response preview:"
  head -c 2000 "${FILE}" 2>/dev/null || true
  echo ""

  if [ "${CURL_STATUS}" -ne 0 ]; then
    echo "RESULT: CURL FAILED"
    cat "${FILE}.curl-error" 2>/dev/null || true
    FAILURES=$((FAILURES + 1))
    return
  fi

  if [ "${HTTP_CODE}" != "200" ]; then
    echo "RESULT: HTTP FAILURE"
    FAILURES=$((FAILURES + 1))
    return
  fi

  if ! grep -q "${EXPECTED}" "${FILE}"; then
    echo "RESULT: RESPONSE SHAPE FAILURE"
    echo "Missing expected key: ${EXPECTED}"
    FAILURES=$((FAILURES + 1))
    return
  fi

  echo "RESULT: HTTP/SHAPE CHECK PASSED"
  echo "Note: This does not prove provider or playback success."
}

# ------------------------------------------------------------
# ENDPOINT TESTS
# ------------------------------------------------------------

test_endpoint \
  "NEWS" \
  "${BASE}/v1/news?refresh=${GITHUB_RUN_ID:-manual}" \
  '"items"' \
  /tmp/sa7bi-news.json \
  90

test_endpoint \
  "QURAN CATALOG" \
  "${BASE}/v1/audio/quran" \
  '"reciters"' \
  /tmp/sa7bi-quran.json \
  60

test_endpoint \
  "HADITH BOOKS" \
  "${BASE}/v1/hadith/books" \
  '"items"' \
  /tmp/sa7bi-hadith-books.json \
  60

test_endpoint \
  "HADITH SEARCH" \
  "${BASE}/v1/hadith?limit=3" \
  '"items"' \
  /tmp/sa7bi-hadith.json \
  60

test_endpoint \
  "TAFSIR BOOKS" \
  "${BASE}/v1/tafsir/books" \
  '"items"' \
  /tmp/sa7bi-tafsir-books.json \
  60

test_endpoint \
  "TAFSIR SEARCH" \
  "${BASE}/v1/tafsir?tafsir=1&sura=1" \
  '"items"' \
  /tmp/sa7bi-tafsir.json \
  60

test_endpoint \
  "RADIO COUNTRIES" \
  "${BASE}/v1/radio/countries" \
  '"countries"' \
  /tmp/sa7bi-radio-countries.json \
  60

test_endpoint \
  "RADIO EGYPT" \
  "${BASE}/v1/radio/stations?country=EG&limit=10" \
  '"stations"' \
  /tmp/sa7bi-radio-eg.json \
  60

test_endpoint \
  "PODCAST SEARCH" \
  "${BASE}/v1/podcasts/search?q=podcast&limit=5" \
  '"items"' \
  /tmp/sa7bi-podcasts.json \
  60

test_endpoint \
  "SHORTS" \
  "${BASE}/v1/shorts" \
  '"items"' \
  /tmp/sa7bi-shorts.json \
  60

test_endpoint \
  "AUDIO SEARCH" \
  "${BASE}/v1/audio/search-v4?q=%D9%82%D8%B1%D8%A2%D9%86&type=quran" \
  '"items"' \
  /tmp/sa7bi-audio.json \
  60

# ------------------------------------------------------------
# DEEP CONTENT DIAGNOSTICS
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo "DEEP CONTENT DIAGNOSTICS"
echo "============================================================"

python3 - <<'PY'
import json
import re
import sys

failures = 0
warnings = 0

def load(path):
    try:
        with open(path, "r", encoding="utf-8") as file:
            return json.load(file)
    except Exception as exc:
        print(f"JSON ERROR {path}: {exc}")
        return None

def is_http_url(value):
    return isinstance(value, str) and bool(
        re.match(r"^https?://", value.strip(), re.I)
    )

def as_list(value):
    return value if isinstance(value, list) else []

# الجزء الثاني يكمل فحوص المحتوى وملخص النتائج.
# ------------------------------------------------------
# NEWS
# ------------------------------------------------------

news = load("/tmp/sa7bi-news.json")

if isinstance(news, dict):
    items = as_list(news.get("items"))

    images = [
        item for item in items
        if isinstance(item, dict) and is_http_url(
            item.get("imageUrl")
            or item.get("image")
            or item.get("image_url")
            or ""
        )
    ]

    links = [
        item for item in items
        if isinstance(item, dict)
        and is_http_url(item.get("link") or "")
    ]

    print("\nNEWS DIAGNOSTICS")
    print(f"  count         : {len(items)}")
    print(f"  image URLs    : {len(images)}")
    print(f"  article links : {len(links)}")

    if not items:
        print("  ERROR: News returned zero items.")
        failures += 1

    if not links:
        print("  ERROR: News returned no valid article links.")
        failures += 1

    if not images:
        print("  WARNING: No usable news images.")
        warnings += 1
else:
    failures += 1

# ------------------------------------------------------
# QURAN
# ------------------------------------------------------

quran = load("/tmp/sa7bi-quran.json")

if isinstance(quran, dict):
    reciters = as_list(quran.get("reciters"))
    suras = as_list(quran.get("suras") or quran.get("suwar"))

    servers = []

    for reciter in reciters:
        if not isinstance(reciter, dict):
            continue

        for entry in as_list(reciter.get("moshaf")):
            if not isinstance(entry, dict):
                continue

            server = entry.get("server") or entry.get("url")
            if is_http_url(server):
                servers.append(server)

    print("\nQURAN DIAGNOSTICS")
    print(f"  reciters      : {len(reciters)}")
    print(f"  suras         : {len(suras)}")
    print(f"  valid servers : {len(servers)}")

    if not reciters:
        print("  ERROR: No Quran reciters.")
        failures += 1

    if not suras:
        print("  ERROR: No Quran suras.")
        failures += 1

    if not servers:
        print("  ERROR: No valid Quran audio servers.")
        failures += 1
else:
    failures += 1

# ------------------------------------------------------
# RADIO
# ------------------------------------------------------

radio = load("/tmp/sa7bi-radio-eg.json")

if isinstance(radio, dict):
    stations = as_list(
        radio.get("stations") or radio.get("items")
    )

    streams = []

    for station in stations:
        if not isinstance(station, dict):
            continue

        url = (
            station.get("streamUrl")
            or station.get("url_resolved")
            or station.get("url")
        )

        if is_http_url(url):
            streams.append(url)

    https_count = sum(
        1 for url in streams
        if url.lower().startswith("https://")
    )

    print("\nRADIO DIAGNOSTICS")
    print(f"  stations      : {len(stations)}")
    print(f"  valid streams : {len(streams)}")
    print(f"  HTTPS streams : {https_count}")

    if not stations:
        print("  ERROR: Egypt radio returned zero stations.")
        failures += 1

    if not streams:
        print("  ERROR: No valid radio stream URLs.")
        failures += 1

    if streams and https_count == 0:
        print("  WARNING: All streams use HTTP; Android may block them.")
        warnings += 1
    elif len(streams) > https_count:
        print("  WARNING: Some streams use HTTP.")
        warnings += 1
else:
    failures += 1

# ------------------------------------------------------
# PODCASTS — PROVIDER VALIDATION
# ------------------------------------------------------

podcasts = load("/tmp/sa7bi-podcasts.json")

if isinstance(podcasts, dict):
    items = as_list(podcasts.get("items"))

    feeds = [
        item.get("feedUrl")
        for item in items
        if isinstance(item, dict)
        and is_http_url(item.get("feedUrl") or "")
    ]

    fallback = podcasts.get("fallback") is True
    provider_status = podcasts.get("providerStatus")
    provider_error = podcasts.get("providerError")

    print("\nPODCAST DIAGNOSTICS")
    print(f"  items          : {len(items)}")
    print(f"  playable feeds : {len(feeds)}")
    print(f"  fallback       : {fallback}")
    print(f"  providerStatus : {provider_status}")
    print(f"  providerError  : {provider_error}")

    if fallback:
        print(
            "  ERROR: Provider returned fallback data. "
            "This is not genuine provider success."
        )
        failures += 1

    if provider_status == 429:
        print("  ERROR: Podcast provider rate-limited the request.")
        failures += 1

    if provider_error:
        print("  ERROR: Podcast provider reported an error.")
        failures += 1

    if not items:
        print("  ERROR: Podcast search returned zero items.")
        failures += 1

    if not feeds:
        print("  ERROR: No playable podcast feeds.")
        failures += 1
else:
    print("  ERROR: Podcast response is not valid JSON object.")
    failures += 1

# ------------------------------------------------------
# SHORTS
# ------------------------------------------------------

shorts = load("/tmp/sa7bi-shorts.json")

if isinstance(shorts, dict):
    items = as_list(shorts.get("items"))

    print("\nSHORTS DIAGNOSTICS")
    print(f"  count : {len(items)}")

    if not items:
        print("  ERROR: Shorts returned zero items.")
        failures += 1
else:
    failures += 1

# ------------------------------------------------------
# AUDIO SEARCH
# ------------------------------------------------------

audio = load("/tmp/sa7bi-audio.json")

if isinstance(audio, dict):
    items = as_list(audio.get("items"))

    playable = [
        item for item in items
        if isinstance(item, dict)
        and is_http_url(
            item.get("audioUrl")
            or item.get("url")
            or ""
        )
    ]

    print("\nAUDIO SEARCH DIAGNOSTICS")
    print(f"  items         : {len(items)}")
    print(f"  playable URLs : {len(playable)}")

    if not items:
        print("  WARNING: Audio search returned zero items.")
        warnings += 1
    elif not playable:
        print("  WARNING: No obvious playable audio URL.")
        warnings += 1
else:
    failures += 1

print("\n============================================================")
print("DEEP CONTENT DIAGNOSTIC SUMMARY")
print(f"Failures : {failures}")
print(f"Warnings : {warnings}")
print("============================================================")

if failures:
    sys.exit(1)
PY

echo ""
echo "============================================================"
echo "CONTENT / SERVICE TEST SUMMARY"
echo "============================================================"
echo "Failures: ${FAILURES}"
echo "Warnings: ${WARNINGS}"
echo "============================================================"

if [ "${FAILURES}" -ne 0 ]; then
  echo ""
  echo "ERROR: One or more content/service checks failed."
  echo "Fallback provider responses are not reported as genuine success."
  exit 1
fi

echo ""
echo "All blocking content/service diagnostics passed."
echo "Warnings: ${WARNINGS}"
echo "============================================================"
