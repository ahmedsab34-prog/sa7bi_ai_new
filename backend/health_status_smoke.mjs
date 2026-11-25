import assert from "node:assert/strict";

import {
  handleServiceStatus,
} from "./src/health.js";

const expectedServices = [
  "ai",
  "news",
  "audio",
  "quran",
  "hadith",
  "tafsir",
  "radio",
  "podcasts",
  "shorts",
  "downloads",
  "credits",
  "rewardedAds",
];

async function readStatus(env) {
  const response = await handleServiceStatus(env);

  assert.equal(response.status, 200);

  return response.json();
}

const unconfigured = await readStatus({});

assert.equal(unconfigured.ok, true);

assert.equal(
  unconfigured.status,
  "not_checked",
);

assert.equal(
  unconfigured.checkMode,
  "configuration_only_no_live_upstream_probes",
);

assert.equal(
  unconfigured.summary.total,
  expectedServices.length,
);

assert.equal(
  unconfigured.summary.checked,
  0,
);

assert.equal(
  unconfigured.summary.notChecked,
  expectedServices.length,
);

assert.equal(
  unconfigured.summary.available,
  null,
);

for (const name of expectedServices) {
  assert.equal(
    unconfigured.services[name],
    null,
    `${name} must remain unknown until a live health probe exists`,
  );

  assert.equal(
    unconfigured.serviceDetails[name].routeRegistered,
    true,
  );

  assert.equal(
    unconfigured.serviceDetails[name].available,
    null,
  );

  assert.equal(
    unconfigured.serviceDetails[name].availability,
    "not_checked",
  );

  assert.ok(
    unconfigured.serviceDetails[name].endpoints.length > 0,
  );
}

assert.equal(
  unconfigured.serviceDetails.ai.configured,
  false,
);

assert.equal(
  unconfigured.serviceDetails.credits.configured,
  false,
);

assert.equal(
  unconfigured.serviceDetails.rewardedAds.configured,
  false,
);

assert.equal(
  unconfigured.serviceDetails.news.configured,
  null,
);

const configured = await readStatus({
  AI: {
    run: async () => ({
      answer: "mock",
    }),
  },

  SA7BI_CREDITS: {},

  ADMOB_REWARDED_AD_UNIT_ID: "test-ad-unit",
});

assert.equal(
  configured.serviceDetails.ai.configured,
  true,
);

assert.equal(
  configured.serviceDetails.credits.configured,
  true,
);

assert.equal(
  configured.serviceDetails.rewardedAds.configured,
  true,
);

// Configuration is not a runtime health probe.
// Availability must remain unknown.
assert.equal(
  configured.services.ai,
  null,
);

assert.equal(
  configured.serviceDetails.ai.available,
  null,
);

assert.equal(
  configured.serviceDetails.credits.available,
  null,
);

console.log(
  "service status smoke test: PASS (no unverified availability claims)",
);
