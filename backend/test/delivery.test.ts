import { test, mock } from "node:test";
import assert from "node:assert/strict";
import { deliveryBlocks, directedText } from "../src/delivery.js";
import { Providers } from "../src/providers.js";
import { readConfig } from "../src/config.js";
const config = readConfig({
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "test-only-secret-key",
  OPENAI_API_KEY: "test-only-openai",
  ELEVENLABS_API_KEY: "test-only-eleven",
  ELEVENLABS_VOICE_ID: "testvoice",
  OPENAI_SCRIPT_MODEL: "gpt-5.4-mini",
});
const text = "Here is the important detail.\n\nThe proposal is not final.";
test("delivery preserves narration and inserts only controlled cues; rejects malformed plans", () => {
  const blocks = deliveryBlocks(text);
  const directed = directedText(blocks, ["curious", "serious"]);
  assert.match(directed, /\[short pause\]/);
  assert.equal(
    directed
      .replace(/\[[^\]]+\]/g, "")
      .replace(/\s+/g, " ")
      .trim(),
    text.replace(/\s+/g, " "),
  );
  assert.ok(!directedText(blocks, ["shouts", "serious"]).includes("[shouts]"));
  assert.ok(directedText(blocks, ["warm"]).startsWith("[calm]"));
  assert.equal(deliveryBlocks("Quote [shouts] now.")[0], "Quote (shouts) now.");
});
test("expressive narration uses script model, keeps source text, and falls back on direction failures", async () => {
  const p = new Providers(config);
  let sent = "";
  let mode = "valid";
  const speech = mock.method(p, "speech", async (t: string) => {
    sent = t;
    return { audio: Buffer.from("audio"), duration: 3 };
  });
  const fetch = mock.method(
    globalThis,
    "fetch",
    async (_url: any, opts: any) => {
      const body = JSON.parse(opts.body);
      assert.equal(body.model, "gpt-5.4-mini");
      assert.deepEqual(JSON.parse(body.input).paragraphs, deliveryBlocks(text));
      if (mode === "failure") return new Response("", { status: 503 });
      return Response.json({
        status: "completed",
        output: [
          {
            content: [
              {
                type: "output_text",
                text: JSON.stringify({
                  tones:
                    mode === "malformed" ? ["warm"] : ["thoughtful", "serious"],
                }),
              },
            ],
          },
        ],
      });
    },
  );
  try {
    for (mode of ["valid", "malformed", "failure"]) {
      await p.expressiveSpeech(text, "eleven_v4", new AbortController().signal);
      assert.match(sent, mode === "valid" ? /\[thoughtful\]/ : /\[calm\]/);
      assert.match(sent, /The proposal is not final\./);
    }
    const c = new AbortController();
    c.abort();
    await assert.rejects(p.expressiveSpeech(text, "eleven_v4", c.signal));
  } finally {
    speech.mock.restore();
    fetch.mock.restore();
  }
});
