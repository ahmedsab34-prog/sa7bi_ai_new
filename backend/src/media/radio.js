
 // backend/src/media/radio.js
// Sa7bi AI Backend - Radio Module
// Version: 6.3.1

import {
  json,
  normalizeArabic,
} from "../utils.js";

const BACKEND_VERSION = "6.3.1";

const RADIO_BASE_URLS = [
  "https://de1.api.radio-browser.info",
  "https://nl1.api.radio-browser.info",
  "https://at1.api.radio-browser.info",
];

const RADIO_BASE_URL = `${RADIO_BASE_URLS[0]}/json`;
const RADIO_SOURCE = "Radio Browser";
const MAX_LIMIT = 100;
const PROVIDER_TIMEOUT_MS = 3500;
const COUNTRY_CACHE_TTL_MS = 30 * 60 * 1000;

// Cache lives within a Worker isolate. It reduces repeat requests,
// but is not a persistent or guaranteed cross-isolate cache.
let cachedCountries = null;
let cachedCountriesAt = 0;

// Used only when the external country directory is unavailable.
// For entries not in this map, the country name itself is used as
// the search value; the backend supports full country names too.
const COUNTRY_CODES = {
  "Argentina": "AR",
  "Australia": "AU",
  "Austria": "AT",
  "Bahrain": "BH",
  "Bangladesh": "BD",
  "Belgium": "BE",
  "Brazil": "BR",
  "Canada": "CA",
  "China": "CN",
  "Denmark": "DK",
  "Egypt": "EG",
  "Finland": "FI",
  "France": "FR",
  "Germany": "DE",
  "Ghana": "GH",
  "Greece": "GR",
  "India": "IN",
  "Indonesia": "ID",
  "Iran": "IR",
  "Iraq": "IQ",
  "Ireland": "IE",
  "Italy": "IT",
  "Japan": "JP",
  "Jordan": "JO",
  "Kenya": "KE",
  "Kuwait": "KW",
  "Lebanon": "LB",
  "Libya": "LY",
  "Malaysia": "MY",
  "Morocco": "MA",
  "Nepal": "NP",
  "Netherlands": "NL",
  "New Zealand": "NZ",
  "Nigeria": "NG",
  "Norway": "NO",
  "Oman": "OM",
  "Pakistan": "PK",
  "Palestine": "PS",
  "Philippines": "PH",
  "Poland": "PL",
  "Portugal": "PT",
  "Qatar": "QA",
  "Romania": "RO",
  "Russia": "RU",
  "Saudi Arabia": "SA",
  "Singapore": "SG",
  "Somalia": "SO",
  "South Africa": "ZA",
  "South Korea": "KR",
  "Spain": "ES",
  "Sudan": "SD",
  "Sweden": "SE",
  "Switzerland": "CH",
  "Syria": "SY",
  "Tunisia": "TN",
  "Turkey": "TR",
  "Türkiye": "TR",
  "Ukraine": "UA",
  "United Arab Emirates": "AE",
  "United Kingdom": "GB",
  "United States": "US",
  "United States of America": "US",
  "Yemen": "YE",
};

const FALLBACK_COUNTRIES = [
  ["Egypt", "EG"],
  ["Saudi Arabia", "SA"],
  ["United Arab Emirates", "AE"],
  ["Kuwait", "KW"],
  ["Qatar", "QA"],
  ["Bahrain", "BH"],
  ["Oman", "OM"],
  ["Jordan", "JO"],
  ["Palestine", "PS"],
  ["Lebanon", "LB"],
  ["Iraq", "IQ"],
  ["Morocco", "MA"],
  ["Algeria", "DZ"],
  ["Tunisia", "TN"],
  ["Sudan", "SD"],
  ["Yemen", "YE"],
  ["United Kingdom", "GB"],
  ["United States", "US"],
  ["France", "FR"],
  ["Germany", "DE"],
  ["Turkey", "TR"],
  ["India", "IN"],
].map(([name, code]) => ({
  name,
  iso: code,
  code,
  countryCode: code,
  stationCount: 0,
}));

function isSafeHttpUrl(value) {
  if (typeof value !== "string" || !value.trim()) {
    return false;
  }

  try {
    const url = new URL(value.trim());

    if (url.protocol !== "http:" && url.protocol !== "https:") {
      return false;
    }

    const hostname = url.hostname.toLowerCase();

    if (
      hostname === "localhost" ||
      hostname === "127.0.0.1" ||
      hostname === "::1" ||
      hostname.endsWith(".localhost") ||
      hostname.endsWith(".local")
    ) {
      return false;
    }

    return true;
  } catch (_) {
    return false;
  }
}

function normalizeStation(station, index = 0) {
  if (!station || typeof station !== "object") {
    return null;
  }

  const streamUrl = station.url_resolved || station.url || null;

  if (!isSafeHttpUrl(streamUrl)) {
    return null;
  }

  const stationUuid =
    station.stationuuid ||
    station.stationId ||
    `${index + 1}`;

  return {
    id: stationUuid,
    stationUuid,
    name: String(station.name || "Radio Station").trim(),
    country: station.country || "",
    countryCode: String(station.countrycode || "").toUpperCase(),
    state: station.state || "",
    language: station.language || "",
    languageCodes: station.languagecodes || "",
    codec: station.codec || "",
    bitrate: Number(station.bitrate || 0),
    favicon: isSafeHttpUrl(station.favicon) ? station.favicon : null,
    streamUrl,
    homepage: isSafeHttpUrl(station.homepage) ? station.homepage : null,
    tags: station.tags || "",
    votes: Number(station.votes || 0),
    clickCount: Number(station.clickcount || 0),
    clickTrend: Number(station.clicktrend || 0),
    lastCheckOk: Number(station.lastcheckok || 0) === 1,
    lastCheckTime:
      station.lastchecktime_iso8601 ||
      station.lastchecktime ||
      null,
    hls: Number(station.hls || 0) === 1,
    source: RADIO_SOURCE,
  };
}

function normalizeLimit(value, fallback = 30) {
  const number = Number(value);

  if (!Number.isFinite(number)) {
    return fallback;
  }

  return Math.min(Math.max(Math.floor(number), 1), MAX_LIMIT);
}

function normalizeCountry(item) {
  const name = String(item?.name || "").trim();

  if (!name) {
    return null;
  }

  const explicitCode = String(
    item?.iso_3166_1 ||
    item?.iso_3166_1_code ||
    item?.countrycode ||
    item?.countryCode ||
    item?.iso ||
    item?.code ||
    "",
  ).trim().toUpperCase();

  const mappedCode =
    COUNTRY_CODES[name] ||
    COUNTRY_CODES[name.replace(/\s+/g, " ")] ||
    "";

  // Some Radio Browser country responses contain no ISO code.
  // Keep the country selectable by falling back to its name.
  const searchCode = explicitCode || mappedCode || name;

  return {
    name,
    iso: searchCode,
    code: searchCode,
    countryCode: searchCode,
    stationCount: Number(item?.stationcount || item?.stationCount || 0),
  };
}

async function fetchRadioJson(endpoint) {
  const parsed = new URL(endpoint);
  const pathAndQuery = `${parsed.pathname}${parsed.search}`;
  const errors = [];

  for (const baseUrl of RADIO_BASE_URLS) {
    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      PROVIDER_TIMEOUT_MS,
    );

    try {
      const response = await fetch(`${baseUrl}${pathAndQuery}`, {
        method: "GET",
        redirect: "follow",
        signal: controller.signal,
        headers: {
          Accept: "application/json",
          "User-Agent": "Sa7bi-AI/6.3.1",
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP_${response.status}`);
      }

      const data = await response.json();
      return data;
    } catch (error) {
      errors.push(
        `${new URL(baseUrl).hostname}: ${error?.message || "Unknown error"}`,
      );
    } finally {
      clearTimeout(timer);
    }
  }

  throw new Error(
    `RADIO_PROVIDER_UNAVAILABLE: ${errors.join(" | ")}`,
  );
}

async function fetchStations(params) {
  const endpoint =
    `${RADIO_BASE_URL}/stations/search?${params.toString()}`;

  const data = await fetchRadioJson(endpoint);
  return Array.isArray(data) ? data : [];
}

function mergeStations(first, second, limit) {
  const result = [];
  const ids = new Set();

  for (const station of [...first, ...second]) {
    const normalized = normalizeStation(station, result.length);

    if (!normalized || ids.has(normalized.stationUuid)) {
      continue;
    }

    ids.add(normalized.stationUuid);
    result.push(normalized);

    if (result.length >= limit) {
      break;
    }
  }

  return result;
}

function countryResponse(countries, degraded = false) {
  return json({
    ok: true,
    type: "radio-countries",
    count: countries.length,
    items: countries,
    countries,
    degraded,
    source: degraded ? "local-country-fallback" : RADIO_SOURCE,
    backendVersion: BACKEND_VERSION,
  });
}

/**
 * GET /v1/radio/stations
 *
 * Supports:
 * ?q=Egypt
 * ?country=EG
 * ?country=Egypt
 * ?countrycode=EG
 * ?language=arabic
 */
export async function handleRadioSearch(request) {
  try {
    const url = new URL(request.url);

    const query = normalizeArabic(url.searchParams.get("q") || "");
    const rawCountry = String(
      url.searchParams.get("country") || "",
    ).trim();

    const explicitCountryCode = String(
      url.searchParams.get("countrycode") ||
      url.searchParams.get("countryCode") ||
      "",
    ).trim().toUpperCase();

    let country = rawCountry;
    let countryCode = explicitCountryCode;

    if (!countryCode && /^[A-Z]{2}$/i.test(rawCountry)) {
      countryCode = rawCountry.toUpperCase();
      country = "";
    }

    const language = String(
      url.searchParams.get("language") || "",
    ).trim();

    const limit = normalizeLimit(
      url.searchParams.get("limit"),
      30,
    );

    const params = new URLSearchParams();
    params.set("hidebroken", "true");
    params.set("order", "votes");
    params.set("reverse", "true");
    params.set("limit", String(limit));

    if (countryCode) {
      params.set("countrycode", countryCode);
    } else if (country) {
      params.set("country", country);
    }

    if (language) params.set("language", language);
    if (query) params.set("name", query);

    const primaryRaw = await fetchStations(params);

    let stations = primaryRaw
      .map((station, index) => normalizeStation(station, index))
      .filter(Boolean);

    if (query && stations.length < 5 && !country && !countryCode) {
      try {
        const fallbackEndpoint =
          `${RADIO_BASE_URL}/stations/byname/${encodeURIComponent(query)}` +
          `?hidebroken=true&order=votes&reverse=true&limit=${limit}`;

        const fallbackData = await fetchRadioJson(fallbackEndpoint);

        if (Array.isArray(fallbackData)) {
          stations = mergeStations(stations, fallbackData, limit);
        }
      } catch (_) {
        // Preserve any results already received.
      }
    }

    stations = stations.slice(0, limit);

    return json({
      ok: true,
      type: "radio",
      query,
      country,
      countryCode,
      language,
      count: stations.length,
      items: stations,
      stations,
      backendVersion: BACKEND_VERSION,
      source: RADIO_SOURCE,
    });
  } catch (error) {
    return json({
      ok: false,
      type: "radio",
      count: 0,
      items: [],
      stations: [],
      error: "Radio provider unavailable",
      message: error?.message || "Unknown error",
      backendVersion: BACKEND_VERSION,
      source: RADIO_SOURCE,
    }, 502);
  }
}

/**
 * GET /v1/radio/countries
 *
 * Keeps the country picker usable if the public radio directory
 * is temporarily unavailable. A fallback country list does not
 * imply that station streams themselves are available.
 */
export async function handleRadioCountries() {
  try {
    const endpoint =
      `${RADIO_BASE_URL}/countries?order=stationcount&reverse=true&hidebroken=true`;

    const data = await fetchRadioJson(endpoint);

    const countries = Array.isArray(data)
      ? data.map(normalizeCountry).filter(Boolean)
      : [];

    if (countries.length > 0) {
      countries.sort(
        (a, b) => b.stationCount - a.stationCount,
      );

      cachedCountries = countries;
      cachedCountriesAt = Date.now();

      return countryResponse(countries, false);
    }

    throw new Error("RADIO_COUNTRIES_EMPTY");
  } catch (error) {
    const cacheIsFresh =
      Array.isArray(cachedCountries) &&
      cachedCountries.length > 0 &&
      Date.now() - cachedCountriesAt < COUNTRY_CACHE_TTL_MS;

    if (cacheIsFresh) {
      return countryResponse(cachedCountries, true);
    }

    return countryResponse(FALLBACK_COUNTRIES, true);
  }
}

/**
 * GET /v1/radio/stations?country=EG
 */
export async function handleRadioByCountry(countryCode, limit = 50) {
  const normalizedCode = String(countryCode || "").trim();

  if (!normalizedCode) {
    return json({
      ok: false,
      error: "A country code or country name is required",
      backendVersion: BACKEND_VERSION,
    }, 400);
  }

  try {
    const safeLimit = normalizeLimit(limit, 50);
    const params = new URLSearchParams();

    params.set("hidebroken", "true");
    params.set("order", "votes");
    params.set("reverse", "true");
    params.set("limit", String(safeLimit));

    if (/^[A-Z]{2}$/i.test(normalizedCode)) {
      params.set("countrycode", normalizedCode.toUpperCase());
    } else {
      params.set("country", normalizedCode);
    }

    const endpoint =
      `${RADIO_BASE_URL}/stations/search?${params.toString()}`;

    const data = await fetchRadioJson(endpoint);

    const stations = Array.isArray(data)
      ? data
          .map((station, index) => normalizeStation(station, index))
          .filter(Boolean)
          .slice(0, safeLimit)
      : [];

    return json({
      ok: true,
      type: "radio-country",
      country: normalizedCode,
      countryCode: /^[A-Z]{2}$/i.test(normalizedCode)
        ? normalizedCode.toUpperCase()
        : "",
      count: stations.length,
      items: stations,
      stations,
      backendVersion: BACKEND_VERSION,
      source: RADIO_SOURCE,
    });
  } catch (error) {
    return json({
      ok: false,
      type: "radio-country",
      countryCode: normalizedCode,
      items: [],
      stations: [],
      error: "Unable to load radio stations",
      message: error?.message || "Unknown error",
      backendVersion: BACKEND_VERSION,
      source: RADIO_SOURCE,
    }, 502);
  }
}

/**
 * Register a station click and return its current playable URL.
 */
export async function handleRadioStationClick(stationUuid) {
  const normalizedUuid = String(stationUuid || "").trim();

  if (!normalizedUuid) {
    return json({
      ok: false,
      error: "stationUuid is required",
      backendVersion: BACKEND_VERSION,
    }, 400);
  }

  try {
    const endpoint =
      `${RADIO_BASE_URL}/url/${encodeURIComponent(normalizedUuid)}`;

    const data = await fetchRadioJson(endpoint);
    const streamUrl = data?.url || null;

    if (!isSafeHttpUrl(streamUrl)) {
      return json({
        ok: false,
        error: "Station stream unavailable",
        backendVersion: BACKEND_VERSION,
      }, 404);
    }

    return json({
      ok: true,
      type: "radio-station",
      stationUuid: normalizedUuid,
      name: data?.name || "",
      streamUrl,
      backendVersion: BACKEND_VERSION,
      source: RADIO_SOURCE,
    });
  } catch (error) {
    return json({
      ok: false,
      type: "radio-station",
      stationUuid: normalizedUuid,
      error: "Unable to open radio station",
      message: error?.message || "Unknown error",
      backendVersion: BACKEND_VERSION,
      source: RADIO_SOURCE,
    }, 502);
  }
}

/**
 * Check whether a radio stream URL is reachable.
 */
export async function checkRadioStream(streamUrl) {
  if (!isSafeHttpUrl(streamUrl)) {
    return false;
  }

  try {
    const response = await fetch(streamUrl, {
      method: "HEAD",
      redirect: "follow",
      signal: AbortSignal.timeout(5000),
      headers: {
        "User-Agent": "Sa7bi-AI/6.3.1",
      },
    });

    if (response.ok) {
      return true;
    }

    const rangeResponse = await fetch(streamUrl, {
      method: "GET",
      redirect: "follow",
      signal: AbortSignal.timeout(5000),
      headers: {
        Range: "bytes=0-1",
        "User-Agent": "Sa7bi-AI/6.3.1",
      },
    });

    return rangeResponse.ok || rangeResponse.status === 206;
  } catch (_) {
    return false;
  }
}

/**
 * Radio provider health.
 */
export async function handleRadioHealth() {
  try {
    const endpoint = `${RADIO_BASE_URL}/stats`;
    const data = await fetchRadioJson(endpoint);

    return json({
      ok: true,
      type: "radio-health",
      provider: RADIO_SOURCE,
      providerStatus: data?.status || "OK",
      stations: Number(data?.stations || 0),
      countries: Number(data?.countries || 0),
      backendVersion: BACKEND_VERSION,
    });
  } catch (error) {
    return json({
      ok: false,
      type: "radio-health",
      provider: RADIO_SOURCE,
      error: "Radio provider unavailable",
      message: error?.message || "Unknown error",
      backendVersion: BACKEND_VERSION,
    }, 502);
  }
}

export default {
  handleRadioSearch,
  handleRadioCountries,
  handleRadioByCountry,
  handleRadioStationClick,
  checkRadioStream,
  handleRadioHealth,
};
