// backend/src/fallback.js
//
// Sa7bi AI - Stateless Network Fallback
//
// FINAL ARCHITECTURE
// ------------------
// Flutter
//    ↓
// Fallback Worker
//    ↓
// Service Binding
//    ↓
// Primary Worker
//
// هذا Worker ليس Backend ثانيًا.
// لا يحتوي:
// - Gemini
// - Workers AI
// - Credits
// - Durable Objects
// - API Keys
//
// وظيفته الوحيدة:
// استقبال طلب التطبيق من hostname بديل
// وتمريره داخليًا إلى الـWorker الأساسي.
//
// مهم:
// الاتصال بين الـFallback والـPrimary يتم من خلال
// Cloudflare Service Binding وليس عبر workers.dev.
// لذلك لا يعتمد على DNS أو Internet routing بين الـWorkers.
//

const HOP_BY_HOP_HEADERS = new Set([
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
  "host",
  "content-length",
]);

function buildHeaders(request) {
  const headers = new Headers();

  for (const [key, value] of request.headers) {
    if (
      HOP_BY_HOP_HEADERS.has(
        key.toLowerCase(),
      )
    ) {
      continue;
    }

    headers.set(key, value);
  }

  headers.set(
    "X-Sa7bi-Network-Fallback",
    "1",
  );

  headers.set(
    "X-Sa7bi-Fallback-Target",
    "sa7bi-ai-new",
  );

  return headers;
}

function withFallbackHeaders(response) {
  const responseHeaders = new Headers(
    response.headers,
  );

  responseHeaders.set(
    "X-Sa7bi-Network-Fallback",
    "1",
  );

  responseHeaders.set(
    "X-Sa7bi-Fallback-Target",
    "sa7bi-ai-new",
  );

  return new Response(
    response.body,
    {
      status: response.status,
      statusText: response.statusText,
      headers: responseHeaders,
    },
  );
}

function errorResponse(error) {
  return new Response(
    JSON.stringify({
      ok: false,
      error: "FALLBACK_PROXY_ERROR",
      message:
        error?.message ||
        "Fallback proxy failed.",
    }),
    {
      status: 502,
      headers: {
        "Content-Type":
          "application/json; charset=utf-8",
        "Access-Control-Allow-Origin":
          "*",
        "X-Sa7bi-Network-Fallback":
          "1",
        "X-Sa7bi-Fallback-Target":
          "sa7bi-ai-new",
      },
    },
  );
}

export default {
  async fetch(
    request,
    env,
  ) {
    try {
      if (
        request.method ===
        "OPTIONS"
      ) {
        return new Response(
          null,
          {
            status: 204,
            headers: {
              "Access-Control-Allow-Origin":
                "*",
              "Access-Control-Allow-Methods":
                "GET,POST,PUT,PATCH,DELETE,OPTIONS",
              "Access-Control-Allow-Headers":
                "*",
              "Access-Control-Max-Age":
                "86400",
            },
          },
        );
      }

      if (
        !env ||
        !env.PRIMARY_WORKER ||
        typeof env.PRIMARY_WORKER.fetch !==
          "function"
      ) {
        return errorResponse(
          new Error(
            "PRIMARY_WORKER service binding is not configured.",
          ),
        );
      }

      const headers =
        buildHeaders(
          request,
        );

      const forwardedRequest =
        new Request(
          request,
          {
            headers,
          },
        );

      /*
       * Service Binding:
       *
       * لا يوجد هنا fetch إلى:
       * https://sa7bi-ai-new.ahmedsab34.workers.dev
       *
       * Cloudflare ينفذ الطلب مباشرة داخل
       * الـPrimary Worker المرتبط بالخدمة.
       */
      const response =
        await env.PRIMARY_WORKER.fetch(
          forwardedRequest,
        );

      return withFallbackHeaders(
        response,
      );
    } catch (error) {
      return errorResponse(
        error,
      );
    }
  },
};
