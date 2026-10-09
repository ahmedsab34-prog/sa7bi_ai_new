// backend/src/social.js
// Sa7bi AI — Social Chat foundation
// This module is intentionally separate from the existing AI and credits services.
//
// Planned API:
// POST /v1/social/register
// POST /v1/social/login
// GET  /v1/social/me
// GET  /v1/social/users/search?q=...
// GET  /v1/social/conversations
// POST /v1/social/conversations
// GET  /v1/social/messages?conversationId=...
// POST /v1/social/messages
//
// Security requirements for the integrated implementation:
// - Passwords must be hashed; never stored as plaintext.
// - Every private conversation must be authorized server-side.
// - Message history must be stored server-side.
// - Session tokens must be signed and expire.
// - Social data must remain separate from AI credits.
//
// Do not expose these endpoints until persistent storage,
// authentication, authorization, and request validation are connected.

export const SOCIAL_API_PREFIX = "/v1/social";

export function socialNotConfigured() {
  return new Response(
    JSON.stringify({
      ok: false,
      error: "SOCIAL_SERVICE_NOT_CONFIGURED",
      message:
        "Social chat is not enabled until persistent storage and authentication are configured.",
    }),
    {
      status: 503,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
        "Access-Control-Allow-Origin": "*",
      },
    },
  );
}
