import { test, mock } from "node:test";
import assert from "node:assert/strict";
import { Providers, citations } from "../src/providers.js";
import { readConfig } from "../src/config.js";
const config = readConfig({
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "test-only-secret-key",
  OPENAI_API_KEY: "test-only-openai",
  ELEVENLABS_API_KEY: "test-only-eleven",
  ELEVENLABS_VOICE_ID: "testvoice",
});
test("citations reject malformed and non-web URLs and deduplicate", () => {
  const result = citations({
    output: [
      {
        content: [
          {
            annotations: [
              { type: "url_citation", url: "javascript:alert(1)" },
              {
                type: "url_citation",
                url: "https://example.com/report",
                title: "Report",
              },
              {
                type: "url_citation",
                url: "https://example.com/report",
                title: "Report",
              },
            ],
          },
        ],
      },
    ],
  });
  assert.equal(result.length, 1);
  assert.equal(result[0]?.name, "example.com");
});
test("research requires actual retrieved citations and rejects fabricated script links", async () => {
  let calls = 0;
  const stub = mock.method(
    globalThis,
    "fetch",
    async (_url: any, options: any) => {
      calls++;
      const body = JSON.parse(options.body);
      if (calls % 2 === 1) {
        assert.equal(body.tools[0].type, "web_search");
        assert.equal(body.tool_choice, "required");
        return Response.json({
          status: "completed",
          output: [
            {
              content: [
                {
                  type: "output_text",
                  text: "Evidence from public reporting.",
                  annotations: [
                    {
                      type: "url_citation",
                      url: "https://example.com/report",
                      title: "Report",
                    },
                  ],
                },
              ],
            },
          ],
        });
      }
      assert.equal(body.text.format.strict, true);
      return Response.json({
        status: "completed",
        output: [
          {
            content: [
              {
                type: "output_text",
                text: JSON.stringify({
                  title: "A reported development",
                  category: "science",
                  summary: "A concise synopsis grounded in reporting.",
                  script:
                    "The reporting describes a change and the evidence behind it. Further observations are needed to establish its longer term implications.",
                  sourceURLs: [
                    calls === 2
                      ? "https://invented.example/report"
                      : "https://example.com/report",
                  ],
                }),
              },
            ],
          },
        ],
      });
    },
  );
  try {
    const provider = new Providers(config);
    await assert.rejects(
      provider.research("What happened?", "", new AbortController().signal),
      /Source verification failed/,
    );
    const result = await provider.research(
      "What happened?",
      "",
      new AbortController().signal,
    );
    assert.equal(result.sources[0]?.url, "https://example.com/report");
  } finally {
    stub.mock.restore();
  }
});
test("missing configuration fails closed without printing values", () => {
  assert.throws(() => readConfig({}), /Missing or invalid configuration/);
});
