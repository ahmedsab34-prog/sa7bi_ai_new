import assert from "node:assert/strict";

import {
  runTextOrVisionWithFallback,
  getAIStatus,
} from "./src/ai/ai-router.js";

import { MOONDREAM_VISION_MODEL } from "./src/ai/moondream-vision.js";

const imageOne = "data:image/jpeg;base64,YWJj";
const imageTwo = "data:image/png;base64,ZGVm";
const calls = [];

const env = {
  AI: {
    async run(model, input) {
      calls.push({ model, input });
      assert.equal(model, MOONDREAM_VISION_MODEL);
      assert.equal(input.task, "query");
      assert.ok(input.image.startsWith("data:image/"));
      assert.ok(input.question.includes("حدد النص الظاهر"));
      return { answer: `نتيجة تجريبية للصورة رقم ${calls.length}` };
    },
  },
};

const request = new Request("https://worker.test/v1/chat", {
  method: "POST",
  headers: { "X-Sa7bi-Force-Fallback": "1" },
});

// 1) Multiple-image analysis uses the configured Moondream model.
const result = await runTextOrVisionWithFallback({
  request,
  env,
  instructions: "التزم بوصف ما يظهر فقط.",
  messages: [
    { role: "user", content: "حلل الصورة وحدد النص الظاهر فيها." },
  ],
  imageDataUrls: [imageOne, imageTwo],
  imagePrompt: "لا تكرر هذا الطلب إذا كانت الرسالة موجودة بالفعل.",
});

assert.equal(calls.length, 2, "Each image must invoke the vision model once.");
assert.equal(calls[0].input.image, imageOne);
assert.equal(calls[1].input.image, imageTwo);
assert.equal(result.provider, "cloudflare-workers-ai");
assert.equal(result.fallback, true);
assert.equal(result.model, MOONDREAM_VISION_MODEL);
assert.equal(result.raw.imageCount, 2);
assert.equal(result.raw.analyzedImages, 2);
assert.match(result.answer, /الصورة 1:/);
assert.match(result.answer, /الصورة 2:/);

const status = getAIStatus(env);
assert.equal(status.workersAI.models.vision, MOONDREAM_VISION_MODEL);

// 2) A text-provider failure must be normalized to the one code that
//    index.js handles by releasing the reserved credit operation.
const textFailureRequest = new Request(
  "https://worker.test/v1/chat",
  {
    method: "POST",
    headers: { "X-Sa7bi-Force-Fallback": "1" },
  },
);

const failingTextEnv = {
  AI: {
    async run() {
      throw new Error("mock provider failure");
    },
  },
};

await assert.rejects(
  () => runTextOrVisionWithFallback({
    request: textFailureRequest,
    env: failingTextEnv,
    messages: [
      { role: "user", content: "رسالة اختبار" },
    ],
  }),
  (error) => {
    assert.equal(error.code, "ALL_AI_PROVIDERS_FAILED");
    assert.equal(
      error.cause?.message,
      "WORKERS_TEXT_REQUEST_FAILED",
    );
    return true;
  },
);

// 3) An empty fallback answer is an explicit provider failure too.
const emptyTextEnv = {
  AI: {
    async run() {
      return { response: "" };
    },
  },
};

await assert.rejects(
  () => runTextOrVisionWithFallback({
    request: textFailureRequest,
    env: emptyTextEnv,
    messages: [
      { role: "user", content: "رسالة اختبار" },
    ],
  }),
  (error) => {
    assert.equal(error.code, "ALL_AI_PROVIDERS_FAILED");
    assert.equal(
      error.cause?.message,
      "WORKERS_TEXT_EMPTY",
    );
    return true;
  },
);

console.log(
  "AI vision + safe-retry routing smoke test passed (mocked env.AI; live provider not called).",
);
