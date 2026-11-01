// Sa7bi AI Worker entry point for authenticated social features.
// It reuses the same Durable Object class and SQLite storage as the existing app.

import worker, {
  Sa7biCredits,
  Sa7biSocial as BaseSa7biSocial,
} from "./index.js";

import { handleSocialMessaging } from "./social_messaging.js";
import { handleSocialCommunity } from "./social_community.js";
import { handleSocialMatchmaking } from "./social_matchmaking.js";

export class Sa7biSocial extends BaseSa7biSocial {
  async fetch(request) {
    const matchmakingResponse = await handleSocialMatchmaking(request, this);
    if (matchmakingResponse) return matchmakingResponse;

    const communityResponse = await handleSocialCommunity(request, this);
    if (communityResponse) return communityResponse;

    const messagingResponse = await handleSocialMessaging(request, this);
    if (messagingResponse) return messagingResponse;

    return super.fetch(request);
  }

  async roomPayload(roomId, currentUserId) {
    const payload = await super.roomPayload(roomId, currentUserId);
    if (!payload || payload.state?.aiOpponent !== true) return payload;

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

export default worker;
