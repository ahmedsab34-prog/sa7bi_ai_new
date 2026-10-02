// backend/src/monetization.js
// Sa7bi AI - Dynamic Monetization Configuration
//
// This module controls shopping / affiliate / sponsored
// advertising configuration from the Cloudflare Worker.
//
// IMPORTANT:
// - No affiliate credentials belong in Flutter.
// - No API keys belong here.
// - Affiliate URLs are supplied through Worker environment variables.
// - Public store URLs are used only as non-monetized fallbacks.
// - A store is marked monetized=true only when a valid server-side
//   affiliate URL is configured.

import { json } from "./utils.js";

/* =========================================================
   DEFAULT SHOPPING URLS
   ========================================================= */

const DEFAULT_STORES = [
  {
    id: "amazon",
    title: "Amazon",
    subtitle: "تسوق أونلاين",
    icon: "shopping_cart",
    accent: "#FFA726",
    fallbackUrl: "https://www.amazon.eg/",
    affiliateEnv: "SA7BI_AMAZON_AFFILIATE_URL",
  },
  {
    id: "jumia",
    title: "Jumia",
    subtitle: "عروض ومنتجات",
    icon: "shopping_bag",
    accent: "#8E6BFF",
    fallbackUrl: "https://www.jumia.com.eg/",
    affiliateEnv: "SA7BI_JUMIA_AFFILIATE_URL",
  },
  {
    id: "noon",
    title: "Noon",
    subtitle: "تسوق سريع",
    icon: "storefront",
    accent: "#FFD76A",
    fallbackUrl: "https://www.noon.com/egypt-ar/",
    affiliateEnv: "SA7BI_NOON_AFFILIATE_URL",
  },
  {
    id: "facebook",
    title: "Facebook",
    subtitle: "Marketplace",
    icon: "facebook",
    accent: "#63B3FF",
    fallbackUrl: "https://www.facebook.com/marketplace/",
    affiliateEnv: null,
  },
];

/* =========================================================
   URL VALIDATION
   ========================================================= */

function safeHttpUrl(value) {
  if (
    typeof value !== "string" ||
    !value.trim()
  ) {
    return "";
  }

  const raw = value.trim();

  try {
    const url = new URL(raw);

    if (
      url.protocol !== "https:" &&
      url.protocol !== "http:"
    ) {
      return "";
    }

    return url.toString();
  } catch {
    return "";
  }
}

/* =========================================================
   AFFILIATE URL RESOLUTION
   ========================================================= */

function resolveStore(store, env) {
  const configuredUrl =
    store.affiliateEnv
      ? safeHttpUrl(
          env?.[store.affiliateEnv] || "",
        )
      : "";

  const fallbackUrl =
    safeHttpUrl(
      store.fallbackUrl,
    );

  const monetized =
    Boolean(configuredUrl);

  return {
    id: store.id,
    title: store.title,
    subtitle: store.subtitle,
    icon: store.icon,
    accent: store.accent,

    url:
      configuredUrl ||
      fallbackUrl,

    monetized,

    linkType:
      monetized
        ? "affiliate"
        : "shopping",
  };
}

/* =========================================================
   SPONSORED ADS
   ========================================================= */

function getSponsoredAds(env) {
  const raw =
    typeof env?.SA7BI_SPONSORED_ADS_JSON ===
      "string"
      ? env.SA7BI_SPONSORED_ADS_JSON.trim()
      : "";

  if (!raw) {
    return [];
  }

  try {
    const parsed =
      JSON.parse(raw);

    if (!Array.isArray(parsed)) {
      return [];
    }

    return parsed
      .slice(0, 10)
      .map((item) => {
        if (
          !item ||
          typeof item !== "object"
        ) {
          return null;
        }

        const url =
          safeHttpUrl(
            item.url,
          );

        if (!url) {
          return null;
        }

        const title =
          typeof item.title === "string"
            ? item.title.trim().substring(0, 120)
            : "";

        const subtitle =
          typeof item.subtitle === "string"
            ? item.subtitle.trim().substring(0, 240)
            : "";

        if (!title) {
          return null;
        }

        return {
          id:
            typeof item.id === "string" &&
            item.id.trim()
              ? item.id.trim().substring(0, 80)
              : `sponsored-${Math.random()
                  .toString(36)
                  .slice(2, 10)}`,

          title,

          subtitle,

          imageUrl:
            typeof item.imageUrl === "string"
              ? safeHttpUrl(item.imageUrl)
              : "",

          url,

          active:
            item.active !== false,
        };
      })
      .filter(Boolean)
      .filter(
        (item) =>
          item.active !== false,
      );
  } catch {
    return [];
  }
}

/* =========================================================
   MAIN HANDLER
   ========================================================= */

export function handleMonetization(env) {
  const stores =
    DEFAULT_STORES.map(
      (store) =>
        resolveStore(
          store,
          env,
        ),
    );

  const monetizedStores =
    stores.filter(
      (store) =>
        store.monetized,
    ).length;

  const sponsoredAds =
    getSponsoredAds(env);

  return json({
    ok: true,

    backendVersion:
      "6.3.1",

    monetization: {
      dynamic: true,

      serverControlled: true,

      affiliateEnabled:
        monetizedStores > 0,

      sponsoredAdsEnabled:
        sponsoredAds.length > 0,

      monetizedStores,

      stores,

      sponsoredAds,
    },
  });
}
