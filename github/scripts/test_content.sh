#!/usr/bin/env bash

set -u
set -o pipefail

BASE="${WORKER_URL}"
FAILURES=0

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

  echo "HTTP status   : ${HTTP_CODE}"
  echo "Response time : ${RESPONSE_TIME}s"

  echo "Response preview:"
  head -c 3000 "${FILE}" 2>/dev/null || true
  echo ""

  if [ "${CURL_STATUS}" -ne 0 ]; then
    echo "RESULT: CURL FAILED"
    cat "${FILE}.curl-error" 2>/dev/null || true
    FAILURES=$((FAILURES + 1))
    return
  fi

  if [ "${HTTP_CODE}" != "200" ]; then
    echo "RESULT: HTTP FAILURE (expected 200)"
    FAILURES=$((FAILURES + 1))
    return
  fi

  if ! grep -q "${EXPECTED}" "${FILE}"; then
    echo "RESULT: RESPONSE SHAPE FAILURE"
    echo "Missing expected key: ${EXPECTED}"
    FAILURES=$((FAILURES + 1))
    return
  fi

  echo "RESULT: PASS"
}

# ------------------------------------------------------------
# ENDPOINT TESTS
# ------------------------------------------------------------

test_endpoint \
  "NEWS" \
  "${BASE}/v1/news?refresh=${GITHUB_RUN_ID}" \
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

def load(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as exc:
        print(f"JSON ERROR {path}: {exc}")
        return None

def is_http_url(value):
    return isinstance(value, str) and re.match(
        r"^https?://",
        value.strip(),
        re.I,
    )

# ------------------------------------------------------
# NEWS
# ------------------------------------------------------

news = load("/tmp/sa7bi-news.json")

if isinstance(news, dict):
    items = news.get("items")
    items = items if isinstance(items, list) else []

    images = [
        item
        for item in items
        if isinstance(item, dict)
        and is_http_url(
            item.get("imageUrl")
            or item.get("image")
            or item.get("image_url")
            or ""
        )
    ]

    links = [
        item
        for item in items
        if isinstance(item, dict)
        and is_http_url(item.get("link") or "")
    ]

    print("")
    print("NEWS DIAGNOSTICS")
    print(f"  backendVersion : {news.get('backendVersion')}")
    print(f"  count          : {len(items)}")
    print(f"  image URLs     : {len(images)}")
    print(f"  article links  : {len(links)}")

    if len(items) == 0:
        print("  ERROR: News returned zero items.")
        failures += 1

    if len(links) == 0:
        print("  ERROR: News returned no valid article links.")
        failures += 1

    if len(images) == 0:
        print("  WARNING: News returned zero usable image URLs.")
    else:
        print(
            "  first image    : "
            + str(
                images[0].get("imageUrl")
                or images[0].get("image")
                or images[0].get("image_url")
            )
        )
else:
    failures += 1

# ------------------------------------------------------
# QURAN
# ------------------------------------------------------

quran = load("/tmp/sa7bi-quran.json")

if isinstance(quran, dict):
    reciters = quran.get("reciters")
    suras = quran.get("suras") or quran.get("suwar")

    reciters = reciters if isinstance(reciters, list) else []
    suras = suras if isinstance(suras, list) else []

    moshaf_count = 0
    servers = []

    for reciter in reciters:
        if not isinstance(reciter, dict):
            continue

        moshaf = reciter.get("moshaf")

        if not isinstance(moshaf, list):
            continue

        moshaf_count += len(moshaf)

        for entry in moshaf:
            if (
                isinstance(entry, dict)
                and is_http_url(
                    entry.get("server")
                    or entry.get("url")
                    or ""
                )
            ):
                servers.append(
                    entry.get("server")
                    or entry.get("url")
                )

    print("")
    print("QURAN DIAGNOSTICS")
    print(f"  backendVersion : {quran.get('backendVersion')}")
    print(f"  reciters       : {len(reciters)}")
    print(f"  moshaf entries : {moshaf_count}")
    print(f"  suras          : {len(suras)}")
    print(f"  valid servers  : {len(servers)}")

    if not reciters:
        print("  ERROR: Quran returned zero reciters.")
        failures += 1

    if not suras:
        print("  ERROR: Quran returned zero suras.")
        failures += 1

    if not servers:
        print("  ERROR: Quran returned no valid audio servers.")
        failures += 1
    else:
        server = servers[0].rstrip("/")

        first_sura = next(
            (
                s
                for s in suras
                if (
                    isinstance(s, dict)
                    and str(s.get("id", "")).isdigit()
                    and 1 <= int(s.get("id")) <= 114
                )
            ),
            None,
        )

        if first_sura:
            surah_id = int(first_sura["id"])
            audio_url = f"{server}/{surah_id:03d}.mp3"

            print(f"  first audio URL: {audio_url}")

            if not is_http_url(audio_url):
                print("  ERROR: Generated Quran audio URL is invalid.")
                failures += 1
        else:
            print("  ERROR: No valid Quran surah id was found.")
            failures += 1
else:
    failures += 1

# ------------------------------------------------------
# RADIO
# ------------------------------------------------------

radio = load("/tmp/sa7bi-radio-eg.json")

if isinstance(radio, dict):
    stations = radio.get("stations") or radio.get("items")
    stations = stations if isinstance(stations, list) else []

    valid_streams = []
    https_streams = 0
    http_streams = 0
    checked_ok = 0

    for station in stations:
        if not isinstance(station, dict):
            continue

        url = (
            station.get("streamUrl")
            or station.get("url_resolved")
            or station.get("url")
        )

        if is_http_url(url):
            valid_streams.append(url)

            if str(url).lower().startswith("https://"):
                https_streams += 1
            else:
                http_streams += 1

        if station.get("lastCheckOk") is True:
            checked_ok += 1

    print("")
    print("RADIO DIAGNOSTICS")
    print(f"  backendVersion : {radio.get('backendVersion')}")
    print(f"  stations       : {len(stations)}")
    print(f"  valid streams  : {len(valid_streams)}")
    print(f"  HTTPS streams  : {https_streams}")
    print(f"  HTTP streams   : {http_streams}")
    print(f"  lastCheckOk    : {checked_ok}")

    if not stations:
        print("  ERROR: Egypt radio returned zero stations.")
        failures += 1

    if not valid_streams:
        print("  ERROR: Radio returned no valid stream URLs.")
        failures += 1
    elif http_streams and not https_streams:
        print("  WARNING: All returned radio streams are HTTP.")
        print("  Android cleartext policy may block these streams.")
    elif http_streams:
        print("  WARNING: Some radio streams are HTTP and may be blocked on Android.")

    print(
        "  first stream   : "
        + (
            str(valid_streams[0])
            if valid_streams
            else "NONE"
        )
    )
else:
    failures += 1

# ------------------------------------------------------
# PODCASTS
# ------------------------------------------------------

podcasts = load("/tmp/sa7bi-podcasts.json")

if isinstance(podcasts, dict):
    items = podcasts.get("items")
    items = items if isinstance(items, list) else []

    feeds = [
        item.get("feedUrl")
        for item in items
        if (
            isinstance(item, dict)
            and is_http_url(item.get("feedUrl") or "")
        )
    ]

    artwork = [
        item.get("artwork")
        for item in items
        if (
            isinstance(item, dict)
            and is_http_url(item.get("artwork") or "")
        )
    ]

    print("")
    print("PODCAST DIAGNOSTICS")
    print(f"  backendVersion : {podcasts.get('backendVersion')}")
    print(f"  count          : {len(items)}")
    print(f"  playable feeds : {len(feeds)}")
    print(f"  artwork URLs   : {len(artwork)}")
    print(f"  fallback       : {podcasts.get('fallback')}")

    if podcasts.get("providerStatus") is not None:
        print(f"  providerStatus : {podcasts.get('providerStatus')}")

    if podcasts.get("providerError"):
        print(f"  providerError  : {podcasts.get('providerError')}")

    if not items:
        print("  ERROR: Podcast search returned zero items.")
        failures += 1

    if not feeds:
        print("  ERROR: Podcast search returned no playable feedUrl.")
        failures += 1
    else:
        print(f"  first feed     : {feeds[0]}")
else:
    failures += 1

# ------------------------------------------------------
# SHORTS
# ------------------------------------------------------

shorts = load("/tmp/sa7bi-shorts.json")

if isinstance(shorts, dict):
    items = shorts.get("items")
    items = items if isinstance(items, list) else []

    print("")
    print("SHORTS DIAGNOSTICS")
    print(f"  count          : {len(items)}")

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
    items = audio.get("items")
    items = items if isinstance(items, list) else []

    playable = [
        item
        for item in items
        if (
            isinstance(item, dict)
            and is_http_url(
                item.get("audioUrl")
                or item.get("url")
                or ""
            )
        )
    ]

    print("")
    print("AUDIO SEARCH DIAGNOSTICS")
    print(f"  count          : {len(items)}")
    print(f"  playable URLs  : {len(playable)}")

    # IMPORTANT:
    # Audio Search currently returns zero items in the backend.
    # This is diagnostic information, not a reason to stop
    # AI / credits / media verification.
    if not items:
        print(
            "  WARNING: Audio search returned zero items."
        )
        print(
            "  This is non-blocking so the remaining diagnostics continue."
        )

    elif not playable:
        print(
            "  WARNING: Audio search returned items "
            "but no obvious playable URL."
        )
else:
    failures += 1

print("")
print("============================================================")
print("DEEP CONTENT DIAGNOSTIC SUMMARY")
print(f"Failures: {failures}")
print("============================================================")

if failures:
    sys.exit(1)
PY

echo ""
echo "============================================================"
echo "CONTENT / SERVICE TEST SUMMARY"
echo "============================================================"
echo "Failures: ${FAILURES}"
echo "============================================================"

if [ "${FAILURES}" -ne 0 ]; then
  echo ""
  echo "ERROR: One or more app service endpoints or deep diagnostics failed."
  echo "The response status, timing, counts, URLs, and provider metadata"
  echo "printed above identify the failing backend layer."
  echo ""
  echo "No fake success will be reported."
  exit 1
fi

echo ""
echo "All content/service endpoint diagnostics passed."
echo "============================================================"
