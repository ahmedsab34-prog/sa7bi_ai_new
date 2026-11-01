// Sa7bi AI Worker entry point with authenticated social invitations and DMs.
// The original Worker router and all existing services remain unchanged.

import worker, {
  Sa7biCredits,
  Sa7biSocial as BaseSa7biSocial,
} from "./index.js";

import {
  handleSocialMessaging,
} from "./social_messaging.js";

// Keep the same Durable Object export name so the existing binding and
// SQLite migration remain attached to the same Sa7biSocial class identity.
export class Sa7biSocial extends BaseSa7biSocial {
  async fetch(request) {
    const messagingResponse = await handleSocialMessaging(request, this);

    if (messagingResponse) {
      return messagingResponse;
    }

    return super.fetch(request);
  }
}

export {
  Sa7biCredits,
};

export default worker;
