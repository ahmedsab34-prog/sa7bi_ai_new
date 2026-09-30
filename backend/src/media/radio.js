// backend/src/media/radio.js
// Sa7bi AI Backend - Radio Module
// Version: 6.3.0

import {
  json,
  normalizeArabic,
  fetchJson,
} from "../utils.js";

const BACKEND_VERSION = "6.3.0";

const RADIO_BASE_URL =
  "https://de1.api.radio-browser.info/json";

const RADIO_SOURCE =
  "Radio Browser";

const MAX_LIMIT = 100;

function isSafeHttpUrl(value) {
  if (
    typeof value !== "string" ||
    !value.trim()
  ) {
    return false;
  }

  try {
    const url = new URL(value.trim());

    if (
      url.protocol !== "http:" &&
      url.protocol !== "https:"
    ) {
      return false;
    }

    const hostname =
      url.hostname.toLowerCase();

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

function normalizeStation(
  station,
  index = 0,
) {
  if (
    !station ||
    typeof station !== "object"
  ) {
    return null;
  }

  const streamUrl =
    station.url_resolved ||
    station.url ||
    null;

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

    name:
      String(
        station.name ||
        "Radio Station",
      ).trim(),

    country:
      station.country ||
      "",

    countryCode:
      String(
        station.countrycode ||
        "",
      ).toUpperCase(),

    state:
      station.state ||
      "",

    language:
      station.language ||
      "",

    languageCodes:
      station.languagecodes ||
      "",

    codec:
      station.codec ||
      "",

    bitrate:
      Number(
        station.bitrate || 0,
      ),

    favicon:
      isSafeHttpUrl(
        station.favicon,
      )
        ? station.favicon
        : null,

    streamUrl,

    homepage:
      isSafeHttpUrl(
        station.homepage,
      )
        ? station.homepage
        : null,

    tags:
      station.tags ||
      "",

    votes:
      Number(
        station.votes || 0,
      ),

    clickCount:
      Number(
        station.clickcount || 0,
      ),

    clickTrend:
      Number(
        station.clicktrend || 0,
      ),

    lastCheckOk:
      Number(
        station.lastcheckok || 0,
      ) === 1,

    lastCheckTime:
      station.lastchecktime_iso8601 ||
      station.lastchecktime ||
      null,

    hls:
      Number(
        station.hls || 0,
      ) === 1,

    source:
      RADIO_SOURCE,
  };
}

function normalizeLimit(
  value,
  fallback = 30,
) {
  const number =
    Number(value);

  if (
    !Number.isFinite(number)
  ) {
    return fallback;
  }

  return Math.min(
    Math.max(
      Math.floor(number),
      1,
    ),
    MAX_LIMIT,
  );
}

async function fetchStations(
  params,
) {
  const endpoint =
    `${RADIO_BASE_URL}/stations/search?${params.toString()}`;

  const data =
    await fetchJson(endpoint);

  return Array.isArray(data)
    ? data
    : [];
}

function mergeStations(
  first,
  second,
  limit,
) {
  const result = [];
  const ids = new Set();

  for (
    const station of [
      ...first,
      ...second,
    ]
  ) {
    const normalized =
      normalizeStation(
        station,
        result.length,
      );

    if (!normalized) {
      continue;
    }

    if (
      ids.has(
        normalized.stationUuid,
      )
    ) {
      continue;
    }

    ids.add(
      normalized.stationUuid,
    );

    result.push(
      normalized,
    );

    if (
      result.length >= limit
    ) {
      break;
    }
  }

  return result;
}

/**
 * Search radio stations.
 *
 * Supported:
 *
 * /v1/radio/stations?q=Egypt
 * /v1/radio/stations?country=EG
 * /v1/radio/stations?countrycode=EG
 * /v1/radio/stations?language=arabic
 */
export async function handleRadioSearch(
  request,
) {
  try {
    const url =
      new URL(request.url);

    const query =
      normalizeArabic(
        url.searchParams.get("q") ||
        "",
      );

    const rawCountry =
      String(
        url.searchParams.get(
          "country",
        ) || "",
      ).trim();

    const explicitCountryCode =
      String(
        url.searchParams.get(
          "countrycode",
        ) ||
        url.searchParams.get(
          "countryCode",
        ) ||
        "",
      )
        .trim()
        .toUpperCase();

    // ----------------------------------------------------------
    // IMPORTANT:
    //
    // Flutter الحالي يرسل:
    //
    // ?country=EG
    //
    // لذلك إذا كانت country عبارة عن ISO code
    // نستخدمها كـ countrycode بدل البحث باسم الدولة.
    // ----------------------------------------------------------

    let country = rawCountry;

    let countryCode =
      explicitCountryCode;

    if (
      !countryCode &&
      /^[A-Z]{2}$/i.test(
        rawCountry,
      )
    ) {
      countryCode =
        rawCountry.toUpperCase();

      country = "";
    }

    const language =
      String(
        url.searchParams.get(
          "language",
        ) || "",
      ).trim();

    const limit =
      normalizeLimit(
        url.searchParams.get(
          "limit",
        ),
        30,
      );

    const params =
      new URLSearchParams();

    params.set(
      "hidebroken",
      "true",
    );

    params.set(
      "order",
      "votes",
    );

    params.set(
      "reverse",
      "true",
    );

    params.set(
      "limit",
      String(limit),
    );

    if (countryCode) {
      params.set(
        "countrycode",
        countryCode,
      );
    } else if (country) {
      params.set(
        "country",
        country,
      );
    }

    if (language) {
      params.set(
        "language",
        language,
      );
    }

    if (query) {
      params.set(
        "name",
        query,
      );
    }

    const primaryRaw =
      await fetchStations(
        params,
      );

    let stations =
      primaryRaw
        .map(
          (station, index) =>
            normalizeStation(
              station,
              index,
            ),
        )
        .filter(Boolean);

    if (
      query &&
      stations.length < 5 &&
      !country &&
      !countryCode
    ) {
      try {
        const fallbackEndpoint =
          `${RADIO_BASE_URL}/stations/byname/${encodeURIComponent(query)}?hidebroken=true&order=votes&reverse=true&limit=${limit}`;

        const fallbackData =
          await fetchJson(
            fallbackEndpoint,
          );

        if (
          Array.isArray(
            fallbackData,
          )
        ) {
          stations =
            mergeStations(
              stations,
              fallbackData,
              limit,
            );
        }
      } catch (_) {
        // Keep successful primary results.
      }
    }

    stations =
      stations.slice(
        0,
        limit,
      );

    return json({
      ok: true,

      type: "radio",

      query,

      country,

      countryCode,

      language,

      count:
        stations.length,

      // --------------------------------------------------------
      // Compatibility:
      // Flutter القديم / الحالي قد يستخدم أيًا من المفتاحين.
      // --------------------------------------------------------

      items:
        stations,

      stations:
        stations,

      backendVersion:
        BACKEND_VERSION,

      source:
        RADIO_SOURCE,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type: "radio",

        count: 0,

        items: [],

        stations: [],

        error:
          "Radio provider unavailable",

        message:
          error?.message ||
          "Unknown error",

        backendVersion:
          BACKEND_VERSION,

        source:
          RADIO_SOURCE,
      },
      502,
    );
  }
}

/**
 * Get available radio countries.
 */
export async function handleRadioCountries() {
  try {
    const endpoint =
      `${RADIO_BASE_URL}/countries?order=stationcount&reverse=true&hidebroken=true`;

    const data =
      await fetchJson(endpoint);

    const countries =
      Array.isArray(data)
        ? data
            .map((item) => {
              const iso =
                String(
                  item?.iso_3166_1 ||
                  item?.iso_3166_1_code ||
                  item?.countrycode ||
                  "",
                )
                  .trim()
                  .toUpperCase();

              return {
                name:
                  String(
                    item?.name ||
                    "",
                  ).trim(),

                iso,

                code:
                  iso,

                countryCode:
                  iso,

                stationCount:
                  Number(
                    item?.stationcount ||
                    0,
                  ),
              };
            })
            .filter(
              (item) =>
                item.name,
            )
        : [];

    return json({
      ok: true,

      type:
        "radio-countries",

      count:
        countries.length,

      // Compatibility with Flutter.
      items:
        countries,

      countries:
        countries,

      backendVersion:
        BACKEND_VERSION,

      source:
        RADIO_SOURCE,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "radio-countries",

        count: 0,

        items: [],

        countries: [],

        error:
          "Unable to load radio countries",

        message:
          error?.message ||
          "Unknown error",

        backendVersion:
          BACKEND_VERSION,

        source:
          RADIO_SOURCE,
      },
      502,
    );
  }
}

/**
 * Get stations for one country.
 */
export async function handleRadioByCountry(
  countryCode,
  limit = 50,
) {
  const normalizedCode =
    String(
      countryCode || "",
    )
      .trim()
      .toUpperCase();

  if (
    !/^[A-Z]{2}$/.test(
      normalizedCode,
    )
  ) {
    return json(
      {
        ok: false,

        error:
          "A valid two-letter countryCode is required",

        backendVersion:
          BACKEND_VERSION,
      },
      400,
    );
  }

  try {
    const safeLimit =
      normalizeLimit(
        limit,
        50,
      );

    const params =
      new URLSearchParams();

    params.set(
      "hidebroken",
      "true",
    );

    params.set(
      "order",
      "votes",
    );

    params.set(
      "reverse",
      "true",
    );

    params.set(
      "limit",
      String(safeLimit),
    );

    const endpoint =
      `${RADIO_BASE_URL}/stations/bycountrycodeexact/${encodeURIComponent(normalizedCode)}?${params.toString()}`;

    const data =
      await fetchJson(
        endpoint,
      );

    const stations =
      Array.isArray(data)
        ? data
            .map(
              (station, index) =>
                normalizeStation(
                  station,
                  index,
                ),
            )
            .filter(Boolean)
            .slice(
              0,
              safeLimit,
            )
        : [];

    return json({
      ok: true,

      type:
        "radio-country",

      countryCode:
        normalizedCode,

      count:
        stations.length,

      items:
        stations,

      stations:
        stations,

      backendVersion:
        BACKEND_VERSION,

      source:
        RADIO_SOURCE,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "radio-country",

        countryCode:
          normalizedCode,

        items: [],

        stations: [],

        error:
          "Unable to load radio stations",

        message:
          error?.message ||
          "Unknown error",

        backendVersion:
          BACKEND_VERSION,

        source:
          RADIO_SOURCE,
      },
      502,
    );
  }
}

/**
 * Register a station click with Radio Browser
 * and return its current playable URL.
 */
export async function handleRadioStationClick(
  stationUuid,
) {
  const normalizedUuid =
    String(
      stationUuid || "",
    ).trim();

  if (
    !normalizedUuid
  ) {
    return json(
      {
        ok: false,

        error:
          "stationUuid is required",

        backendVersion:
          BACKEND_VERSION,
      },
      400,
    );
  }

  try {
    const endpoint =
      `${RADIO_BASE_URL}/url/${encodeURIComponent(normalizedUuid)}`;

    const data =
      await fetchJson(
        endpoint,
      );

    const streamUrl =
      data?.url ||
      null;

    if (
      !isSafeHttpUrl(
        streamUrl,
      )
    ) {
      return json(
        {
          ok: false,

          error:
            "Station stream unavailable",

          backendVersion:
            BACKEND_VERSION,
        },
        404,
      );
    }

    return json({
      ok: true,

      type:
        "radio-station",

      stationUuid:
        normalizedUuid,

      name:
        data?.name ||
        "",

      streamUrl,

      backendVersion:
        BACKEND_VERSION,

      source:
        RADIO_SOURCE,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "radio-station",

        stationUuid:
          normalizedUuid,

        error:
          "Unable to open radio station",

        message:
          error?.message ||
          "Unknown error",

        backendVersion:
          BACKEND_VERSION,

        source:
          RADIO_SOURCE,
      },
      502,
    );
  }
}

/**
 * Check whether a radio stream URL is reachable.
 */
export async function checkRadioStream(
  streamUrl,
) {
  if (
    !isSafeHttpUrl(
      streamUrl,
    )
  ) {
    return false;
  }

  try {
    const response =
      await fetch(
        streamUrl,
        {
          method: "HEAD",

          redirect:
            "follow",

          headers: {
            "User-Agent":
              "Sa7bi-AI/6.3.0",
          },
        },
      );

    if (
      response.ok
    ) {
      return true;
    }

    const rangeResponse =
      await fetch(
        streamUrl,
        {
          method: "GET",

          redirect:
            "follow",

          headers: {
            "Range":
              "bytes=0-1",

            "User-Agent":
              "Sa7bi-AI/6.3.0",
          },
        },
      );

    return (
      rangeResponse.ok ||
      rangeResponse.status === 206
    );
  } catch (_) {
    return false;
  }
}

/**
 * Radio provider health.
 */
export async function handleRadioHealth() {
  try {
    const endpoint =
      `${RADIO_BASE_URL}/stats`;

    const data =
      await fetchJson(
        endpoint,
      );

    return json({
      ok: true,

      type:
        "radio-health",

      provider:
        RADIO_SOURCE,

      providerStatus:
        data?.status ||
        "OK",

      stations:
        Number(
          data?.stations || 0,
        ),

      countries:
        Number(
          data?.countries || 0,
        ),

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "radio-health",

        provider:
          RADIO_SOURCE,

        error:
          "Radio provider unavailable",

        message:
          error?.message ||
          "Unknown error",

        backendVersion:
          BACKEND_VERSION,
      },
      502,
    );
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
