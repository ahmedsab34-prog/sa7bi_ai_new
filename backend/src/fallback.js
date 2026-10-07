// backend/src/fallback.js
//
// Sa7bi AI - Stateless Network Fallback
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
// وتمريره إلى الـWorker الأساسي.
//
// الهدف:
// معالجة الحالات التي يفشل فيها الوصول إلى hostname الأساسي
// من شبكة معينة.
//
// المصدر الحقيقي للبيانات والـAI يظل:
// https://sa7bi-ai-new.ahmedsab34.workers.dev

const PRIMARY_WORKER =
  "https://sa7bi-ai-new.ahmedsab34.workers.dev";

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

function buildTargetUrl(request) {
  const incoming =
    new URL(request.url);

  const target =
    new URL(
      PRIMARY_WORKER,
    );

  target.pathname =
    incoming.pathname;

  target.search =
    incoming.search;

  return target;
}

function buildHeaders(request) {
  const headers =
    new Headers();

  for (const [
    key,
    value,
  ] of request.headers) {
    if (
      HOP_BY_HOP_HEADERS.has(
        key.toLowerCase(),
      )
    ) {
      continue;
    }

    headers.set(
      key,
      value,
    );
  }

  headers.set(
    "X-Sa7bi-Network-Fallback",
    "1",
  );

  return headers;
}

function withFallbackHeaders(
  response,
) {
  const headers =
    new Headers(
      response.headers,
    );

  headers.set(
    "X-Sa7bi-Network-Fallback",
    "1",
  );

  headers.set(
    "X-Sa7bi-Fallback-Target",
    "sa7bi-ai-new",
  );

  return new Response(
    response.body,
    {
      status:
        response.status,
      statusText:
        response.statusText,
      headers,
    },
  );
}

export default {
  async fetch(
    request,
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
            },
          },
        );
      }

      const target =
        buildTargetUrl(
          request,
        );

      const headers =
        buildHeaders(
          request,
        );

      const init = {
        method:
          request.method,
        headers,
        redirect:
          "follow",
      };

      if (
        request.method !==
          "GET" &&
        request.method !==
          "HEAD"
      ) {
        init.body =
          request.body;
      }

      const response =
        await fetch(
          target.toString(),
          init,
        );

      return withFallbackHeaders(
        response,
      );
    } catch (error) {
      return new Response(
        JSON.stringify({
          ok: false,
          error:
            "FALLBACK_PROXY_ERROR",
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
          },
        },
      );
    }
  },
};
