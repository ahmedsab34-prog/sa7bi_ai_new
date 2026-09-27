// backend/src/media/radio.js
// Sa7bi AI Backend - Radio Module
// Version: 6.0.0

import {
  json,
  normalizeArabic,
  fetchJson,
} from "../utils.js";

const BACKEND_VERSION = "6.0.0";

const RADIO_BASE_URL =
  "https://de1.api.radio-browser.info/json";

/**
 * Normalize a Radio Browser station into the
 * structure expected by the Flutter application.
 */
function normalizeStation(station, index = 0) {
  if (!station || typeof station !== "object") {
    return null;
  }

  const streamUrl =
    station.url_resolved ||
    station.url ||
    null;

  if (!streamUrl) {
    return null;
  }

  return {
    id:
      station.stationuuid ||
      station.stationId ||
      `${index + 1}`,

    name:
      station.name ||
      "Radio Station",

    country:
      station.country ||
      "",

    countryCode:
      station.countrycode ||
      "",

    language:
      station.language ||
      "",

    codec:
      station.codec ||
      "",

    bitrate:
      Number(station.bitrate || 0),

    favicon:
      station.favicon ||
      null,

    streamUrl,

    homepage:
      station.homepage ||
      null,

    tags:
      station.tags ||
      "",

    votes:
      Number(station.votes || 0),

    source:
      "Radio Browser",
  };
}

/**
 * Search radio stations.
 *
 * Supported query parameters:
 *
 * /v1/audio?type=radio
 * /v1/audio?type=radio&q=Egypt
 * /v1/radio?country=Egypt
 * /v1/radio?countrycode=EG
 */
export async function handleRadioSearch(request) {
  try {
    const url = new URL(request.url);

    const query = normalizeArabic(
      url.searchParams.get("q") || ""
    );

    const country =
      url.searchParams.get("country") || "";

    const countryCode = (
      url.searchParams.get("countrycode") ||
      url.searchParams.get("countryCode") ||
      ""
    ).toUpperCase();

    const language =
      url.searchParams.get("language") || "";

    const limitRaw = Number(
      url.searchParams.get("limit") || 30
    );

    const limit = Math.min(
      Math.max(limitRaw, 1),
      100
    );

    const params = new URLSearchParams();

    params.set(
      "hidebroken",
      "true"
    );

    params.set(
      "order",
      "votes"
    );

    params.set(
      "reverse",
      "true"
    );

    params.set(
      "limit",
      String(limit)
    );

    if (countryCode) {
      params.set(
        "countrycode",
        countryCode
      );
    } else if (country) {
      params.set(
        "country",
        country
      );
    }

    if (language) {
      params.set(
        "language",
        language
      );
    }

    if (query) {
      params.set(
        "name",
        query
      );
    }

    const endpoint =
      `${RADIO_BASE_URL}/stations/search?${params.toString()}`;

    const data = await fetchJson(endpoint);

    const rawStations =
      Array.isArray(data)
        ? data
        : [];

    let stations = rawStations
      .map((station, index) =>
        normalizeStation(
          station,
          index
        )
      )
      .filter(Boolean);

    /**
     * Radio Browser's name search can sometimes
     * return fewer useful Arabic matches.
     *
     * If the user searched without country filters,
     * perform a second broader search and merge
     * unique stations.
     */
    if (
      query &&
      stations.length < 5 &&
      !country &&
      !countryCode
    ) {
      try {
        const fallbackParams =
          new URLSearchParams();

        fallbackParams.set(
          "hidebroken",
          "true"
        );

        fallbackParams.set(
          "order",
          "votes"
        );

        fallbackParams.set(
          "reverse",
          "true"
        );

        fallbackParams.set(
          "limit",
          String(limit)
        );

        const fallbackEndpoint =
          `${RADIO_BASE_URL}/stations/byname/${encodeURIComponent(query)}`;

        const fallbackData =
          await fetchJson(
            fallbackEndpoint
          );

        if (
          Array.isArray(
            fallbackData
          )
        ) {
          const existingIds =
            new Set(
              stations.map(
                (item) => item.id
              )
            );

          for (
            let i = 0;
            i < fallbackData.length;
            i++
          ) {
            const normalized =
              normalizeStation(
                fallbackData[i],
                i
              );

            if (
              normalized &&
              !existingIds.has(
                normalized.id
              )
            ) {
              stations.push(
                normalized
              );

              existingIds.add(
                normalized.id
              );
            }

            if (
              stations.length >= limit
            ) {
              break;
            }
          }
        }
      } catch (_) {
        // Keep the first successful search.
      }
    }

    stations =
      stations.slice(0, limit);

    return json({
      ok: true,

      type: "radio",

      query,

      country,

      countryCode,

      language,

      count:
        stations.length,

      items:
        stations,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type: "radio",

        items: [],

        error:
          "Radio provider unavailable",

        message:
          error?.message ||
          "Unknown error",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/**
 * Get radio stations by country.
 *
 * This is kept separate because the Flutter
 * application can use it to populate a country
 * selector before requesting individual stations.
 */
export async function handleRadioCountries() {
  try {
    const endpoint =
      `${RADIO_BASE_URL}/countries?order=stationcount&reverse=true`;

    const data =
      await fetchJson(endpoint);

    const countries =
      Array.isArray(data)
        ? data.map((item) => ({
            name:
              item.name ||
              "",

            iso3166:
              item.iso_3166_1 ||
              "",

            stationCount:
              Number(
                item.stationcount || 0
              ),
          }))
        : [];

    return json({
      ok: true,

      type: "radio-countries",

      count:
        countries.length,

      items:
        countries,

      backendVersion:
        BACKEND_VERSION,
    });
  } catch (error) {
    return json(
      {
        ok: false,

        type:
          "radio-countries",

        items: [],

        error:
          "Unable to load radio countries",

        message:
          error?.message ||
          "Unknown error",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/**
 * Get stations for one country.
 */
export async function handleRadioByCountry(
  countryCode,
  limit = 50
) {
  const normalizedCode =
    String(
      countryCode || ""
    )
      .trim()
      .toUpperCase();

  if (!normalizedCode) {
    return json(
      {
        ok: false,
        error:
          "countryCode is required",
        backendVersion:
          BACKEND_VERSION,
      },
      400
    );
  }

  try {
    const safeLimit =
      Math.min(
        Math.max(
          Number(limit) || 50,
          1
        ),
        100
      );

    const params =
      new URLSearchParams();

    params.set(
      "hidebroken",
      "true"
    );

    params.set(
      "order",
      "votes"
    );

    params.set(
      "reverse",
      "true"
    );

    params.set(
      "limit",
      String(safeLimit)
    );

    const endpoint =
      `${RADIO_BASE_URL}/stations/bycountrycodeexact/${encodeURIComponent(normalizedCode)}?${params.toString()}`;

    const data =
      await fetchJson(endpoint);

    const stations =
      Array.isArray(data)
        ? data
            .map((station, index) =>
              normalizeStation(
                station,
                index
              )
            )
            .filter(Boolean)
            .slice(
              0,
              safeLimit
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

      backendVersion:
        BACKEND_VERSION,
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

        error:
          "Unable to load radio stations",

        message:
          error?.message ||
          "Unknown error",

        backendVersion:
          BACKEND_VERSION,
      },
      502
    );
  }
}

/**
 * Check whether a radio stream is reachable.
 *
 * This does not guarantee that a stream will remain
 * available, but it allows the backend to reject
 * obviously dead URLs before presenting them.
 */
export async function checkRadioStream(
  streamUrl
) {
  if (
    !streamUrl ||
    typeof streamUrl !== "string"
  ) {
    return false;
  }

  try {
    const response =
      await fetch(
        streamUrl,
        {
          method: "HEAD",
          redirect: "follow",
        }
      );

    return response.ok;
  } catch (_) {
    return false;
  }
}

/**
 * Simple radio health endpoint.
 */
export async function handleRadioHealth() {
  return json({
    ok: true,

    type: "radio-health",

    provider:
      "Radio Browser",

    backendVersion:
      BACKEND_VERSION,
  });
}

export default {
  handleRadioSearch,
  handleRadioCountries,
  handleRadioByCountry,
  checkRadioStream,
  handleRadioHealth,
};
