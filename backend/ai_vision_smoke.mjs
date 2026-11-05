
import assert from "node:assert/strict";

import {
  runTextOrVisionWithFallback,
} from "./src/ai/ai-router.js";

const imageOne = "data:image/jpeg;base64,YWJj";
const imageTwo = "data:image/png;base64,ZGVm";
const calls = [];

const env = {
  // Mock Workers AI locally: no Cloudflare or paid API call.
  AI: {
    async run(model, request) {
      calls.push({ model, request });

      assert.equal(
        model,
        "@cf/meta/llama-3.2-11b-vision-instruct",
      );

      assert.ok(
        typeof request.image === "string" &&
        request.image.startsWith("data:image/"),
        "Vision requests must include the original data URL in the image field.",
      );

      assert.ok(
        Array.isArray(request.messages),
        "Vision requests must use a messages array.",
      );

      return {
        response: `mock vision result ${calls.length}`,
      };
    },
  },
  WORKERS_VISION_MODEL:
    "@cf/meta/llama-3.2-11b-vision-instruct",
};

const request = new Request(
  "https://sa7bi-ai-test.local/v1/chat",
  {
    method: "POST",
    headers: {
      "X-Sa7bi-Force-Fallback": "1",
    },
  },
);

const result = await runTextOrVisionWithFallback({
  request,
  env,
  instructions: "تعليمات اختبار محلية فقط.",
  messages: [
    {
      role: "user",
      content: "حلل الصورة المرفقة وحدد النص الظاهر فيها.",
    },
  ],
  imageDataUrls: [imageOne, imageTwo],
  imagePrompt:
    "هذا النص العام لا يجب إلحاقه مرة ثانية إذا كان المستخدم أرسل تعليماته.",
});

assert.equal(calls.length, 2, "Each image should be analyzed once.");
assert.equal(calls[0].request.image, imageOne);
assert.equal(calls[1].request.image, imageTwo);
assert.equal(result.provider, "cloudflare-workers-ai");
assert.equal(result.fallback, true);
assert.equal(result.raw.imageCount, 2);
assert.equal(result.raw.analyzedImages, 2);
assert.match(result.answer, /الصورة 1:/);
assert.match(result.answer, /الصورة 2:/);

for (const call of calls) {
  const userMessages = call.request.messages.filter(
    (message) => message.role === "user",
  );

  assert.equal(
    userMessages.length,
    1,
    "The original user prompt must not be duplicated by a second generic prompt.",
  );

  assert.equal(
    userMessages[0].content,
    "حلل الصورة المرفقة وحدد النص الظاهر فيها.",
  );
}

console.log(
  "AI vision smoke test passed (mocked Workers AI; no live API call).",
);
