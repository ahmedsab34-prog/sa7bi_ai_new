import assert from "node:assert/strict";

import {
  handleRadioSearch,
  handleRadioByCountry,
  handleRadioStationClick,
} from "./src/media/radio.js";

const originalFetch = globalThis.fetch;

function jsonResponse(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

const sampleStations = [
  {
    stationuuid: "https-station",
    name: "HTTPS station",
    url: "https://stream.example.com/live",
    url_resolved: "https://stream.example.com/live",
    countrycode: "EG",
    lastcheckok: 1,
  },
  {
    stationuuid: "https-fallback",
    name: "HTTPS original fallback",
    url: "https://original.example.com/live",
    url_resolved: "http://resolved.example.com/live",
    countrycode: "EG",
    lastcheckok: 1,
  },
  {
    stationuuid: "http-only",
    name: "HTTP only station",
    url: "http://stream.example.com/live",
    url_resolved: "http://stream.example.com/live",
    countrycode: "EG",
    lastcheckok: 1,
  },
];

try {
  // The app requests a country list. The Worker must request HTTPS-only
  // results upstream, and must still validate the returned URLs itself.
  globalThis.fetch = async (url) => {
    const requested = new URL(String(url));

    assert.equal(requested.pathname, "/json/stations/search");
    assert.equal(requested.searchParams.get("countrycode"), "EG");
    assert.equal(requested.searchParams.get("is_https"), "true");

    return jsonResponse(sampleStations);
  };

  const searchResponse = await handleRadioSearch(
    new Request(
      "https://worker.test/v1/radio/stations?country=EG&limit=10",
    ),
  );
  const searchBody = await searchResponse.json();

  assert.equal(searchResponse.status, 200);
  assert.equal(searchBody.ok, true);
  assert.equal(searchBody.count, 2);
  assert.deepEqual(
    searchBody.stations.map((station) => station.stationUuid),
    ["https-station", "https-fallback"],
  );
  assert.equal(
    searchBody.stations[1].streamUrl,
    "https://original.example.com/live",
  );

  // Keep the separate country endpoint HTTPS-only too.
  globalThis.fetch = async (url) => {
    const requested = new URL(String(url));
    assert.equal(requested.pathname, "/json/stations/search");
    assert.equal(requested.searchParams.get("countrycode"), "EG");
    assert.equal(requested.searchParams.get("is_https"), "true");
    return jsonResponse(sampleStations);
  };

  const countryResponse = await handleRadioByCountry("EG", 10);
  const countryBody = await countryResponse.json();

  assert.equal(countryResponse.status, 200);
  assert.equal(countryBody.count, 2);

  // Station-click resolution must reject an HTTP URL even if the
  // directory returns one unexpectedly.
  globalThis.fetch = async () => jsonResponse({
    ok: true,
    name: "Unsafe stream",
    url: "http://stream.example.com/live",
  });

  const httpClick = await handleRadioStationClick("http-station");
  assert.equal(httpClick.status, 404);
  assert.equal(
    (await httpClick.json()).error,
    "Station HTTPS stream unavailable",
  );

  // And preserve a valid HTTPS stream returned by the click endpoint.
  globalThis.fetch = async () => jsonResponse({
    ok: true,
    name: "Safe stream",
    url: "https://stream.example.com/live",
  });

  const httpsClick = await handleRadioStationClick("https-station");
  const httpsClickBody = await httpsClick.json();

  assert.equal(httpsClick.status, 200);
  assert.equal(httpsClickBody.ok, true);
  assert.equal(
    httpsClickBody.streamUrl,
    "https://stream.example.com/live",
  );

  console.log("radio provider smoke test: PASS");
} finally {
  globalThis.fetch = originalFetch;
}
