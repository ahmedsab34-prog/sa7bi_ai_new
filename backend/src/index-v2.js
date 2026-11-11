
// Sa7bi AI Worker entry point.
// Preserves existing social, messaging, matchmaking,
// invite links and tafsir-text routes.
// Adds authenticated R2-backed social reels.

import worker, {
  Sa7biCredits,
  Sa7biSocial as BaseSa7biSocial,
} from "./index.js";

import { handleSocialMessaging } from "./social_messaging.js";
import { handleSocialCommunity } from "./social_community.js";
import { handleSocialMatchmaking } from "./social_matchmaking.js";
import { handleSocialMedia } from "./social_media.js";

import {
  handleTafsirText,
  handleTafsirTextBooks,
} from "./content/tafsir-text.js";

const ANDROID_PACKAGE_NAME = "com.example.sa7bi_ai_new";

const ANDROID_SIGNING_FINGERPRINT =
  "8861F29093A09F80132873C09D3FD7F2252785AD7B8E6CF2241A60605CD254D9";

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "public, max-age=3600",
      "X-Content-Type-Options": "nosniff",
      ...extraHeaders,
    },
  });
}

function html(body, status = 200) {
  return new Response(body, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
      "Content-Security-Policy":
        "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    },
  });
}

function inviteLandingPage({
  title,
  description,
  codeLabel,
  code,
  deepLink,
}) {
  return `<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <title>${title} | صاحبي AI</title>
  <style>
    :root{color-scheme:dark;font-family:system-ui,-apple-system,"Segoe UI",sans-serif}
    body{margin:0;min-height:100vh;display:grid;place-items:center;background:#080b13;color:#f7f9ff;padding:22px;box-sizing:border-box}
    main{width:min(100%,430px);padding:26px;border:1px solid #26354b;border-radius:24px;background:linear-gradient(155deg,#151e30,#0d1320);box-shadow:0 18px 55px #0008;text-align:center}
    .logo{width:62px;height:62px;margin:0 auto 14px;border-radius:19px;display:grid;place-items:center;background:linear-gradient(135deg,#63e6ff,#9b83ff);color:#08111c;font-size:29px;font-weight:900}
    h1{font-size:23px;margin:0 0 10px}p{color:#c4cede;line-height:1.8;margin:0 0 18px}
    a{display:block;padding:14px 16px;border-radius:14px;background:#63e6ff;color:#07111e;text-decoration:none;font-weight:900}
    small{display:block;color:#93a2b8;margin-top:16px;line-height:1.7}
    code{direction:ltr;unicode-bidi:embed;display:inline-block;padding:5px 9px;border-radius:8px;background:#070b13;color:#ffd76a;word-break:break-all}
  </style>
</head>
<body>
  <main>
    <div class="logo">ص</div>
    <h1>${title}</h1>
    <p>${description}</p>
    <a href="${deepLink}">فتح الدعوة في تطبيق صاحبي AI</a>
    <small>${codeLabel}: <code>${code}</code><br>لو التطبيق غير مثبت، ثبّت أحدث نسخة من صاحبي AI ثم افتح الرابط مرة أخرى.</small>
  </main>
</body>
</html>`;
}

function handleGameInviteLanding(url) {
  const code = (url.searchParams.get("code") || "")
    .trim()
    .toUpperCase();

  if (!/^[A-Z0-9]{6}$/.test(code)) {
    return html(
      "<!doctype html><html lang=ar dir=rtl><meta charset=utf-8><title>دعوة غير صالحة</title><body>رمز دعوة المباراة غير صالح.</body></html>",
      400,
    );
  }

  const deepLink =
    `sa7bi://game/invite?code=${encodeURIComponent(code)}`;

  return html(inviteLandingPage({
    title: "دعوة للعب",
    description:
      "صديقك دعاك للعب على صاحبي AI. افتح التطبيق للانضمام إلى المباراة.",
    codeLabel: "رمز المباراة",
    code,
    deepLink,
  }));
}

function handleGroupInviteLanding(url) {
  const groupId = (url.searchParams.get("groupId") || "")
    .trim()
    .toLowerCase();

  if (!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(groupId)) {
    return html(
      "<!doctype html><html lang=ar dir=rtl><meta charset=utf-8><title>دعوة غير صالحة</title><body>رابط دعوة المجموعة غير صالح.</body></html>",
      400,
    );
  }

  const deepLink =
    `sa7bi://community/group?groupId=${encodeURIComponent(groupId)}`;

  return html(inviteLandingPage({
    title: "دعوة للانضمام إلى مجموعة",
    description:
      "تمت دعوتك إلى مجموعة عامة في صاحبي AI. افتح التطبيق للانضمام والمشاركة.",
    codeLabel: "معرّف المجموعة",
    code: groupId,
    deepLink,
  }));
}

function handleAndroidAssetLinks() {
  return json([
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: ANDROID_PACKAGE_NAME,
        sha256_cert_fingerprints: [ANDROID_SIGNING_FINGERPRINT],
      },
    },
  ]);
}

export class Sa7biSocial extends BaseSa7biSocial {
  async fetch(request) {
    const mediaResponse =
      await handleSocialMedia(request, this);

    if (mediaResponse) return mediaResponse;

    const matchmakingResponse =
      await handleSocialMatchmaking(request, this);

    if (matchmakingResponse) return matchmakingResponse;

    const communityResponse =
      await handleSocialCommunity(request, this);

    if (communityResponse) return communityResponse;

    const messagingResponse =
      await handleSocialMessaging(request, this);

    if (messagingResponse) return messagingResponse;

    return super.fetch(request);
  }

  async roomPayload(roomId, currentUserId) {
    const payload = await super.roomPayload(roomId, currentUserId);

    if (!payload || payload.state?.aiOpponent !== true) {
      return payload;
    }

    const mark = payload.game === "chess"
      ? "black"
      : payload.game === "rock_paper_scissors"
          ? "player_2"
          : "O";

    return {
      ...payload,
      guest: {
        id: "sa7bi-ai",
        username: "صاحبي AI",
        mark,
      },
      aiOpponent: true,
    };
  }
}

export {
  Sa7biCredits,
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    if (
      request.method === "GET" &&
      path === "/.well-known/assetlinks.json"
    ) {
      return handleAndroidAssetLinks();
    }

    if (
      request.method === "GET" &&
      path === "/game/invite"
    ) {
      return handleGameInviteLanding(url);
    }

    if (
      request.method === "GET" &&
      path === "/groups/invite"
    ) {
      return handleGroupInviteLanding(url);
    }

    if (
      request.method === "GET" &&
      path === "/v1/tafsir-text/books"
    ) {
      return handleTafsirTextBooks(request);
    }

    if (
      request.method === "GET" &&
      path === "/v1/tafsir-text"
    ) {
      return handleTafsirText(request);
    }

    return worker.fetch(request, env, ctx);
  },
};
