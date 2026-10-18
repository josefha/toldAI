import { test, mock } from "node:test";
import assert from "node:assert/strict";
import { Providers } from "../src/providers.js";
import { quoteScript, contextSources } from "../src/routing.js";
import { readConfig } from "../src/config.js";
import { measured, withTiming } from "../src/timing.js";
const config = readConfig({
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "test-service-key-long",
  OPENAI_API_KEY: "test-openai-key",
  ELEVENLABS_API_KEY: "test-eleven-key",
  ELEVENLABS_VOICE_ID: "voice",
});
const source = {
  id: "1",
  name: "example.com",
  title: "Quote",
  url: "https://example.com/quote",
  note: "Retrieved quote",
};
const draft = {
  title: "A simple explanation",
  category: "science",
  summary: "A stable explanation of how this works.",
  script:
    "Think of the process as water flowing through a pipe. This is an analogy to explain the idea, rather than a claim about a new development.",
  sourceURLs: [],
};
const result = (value: any) =>
  Response.json({
    status: "completed",
    output: [
      {
        content: [
          {
            type: "output_text",
            text: typeof value === "string" ? value : JSON.stringify(value),
          },
        ],
      },
    ],
  });

test("general and context answers skip web search and allow no invented citations", async () => {
  for (const route of ["general", "context"]) {
    let calls = 0;
    const stub = mock.method(
      globalThis,
      "fetch",
      async (_url: any, options: any) => {
        calls++;
        const body = JSON.parse(options.body);
        assert.equal(body.tools, undefined);
        return result({ ...draft, route });
      },
    );
    try {
      const answer = await new Providers(config).answer(
        "Explain this simply",
        "",
        new AbortController().signal,
      );
      assert.equal(answer.sources.length, 0);
      assert.equal(calls, 1);
    } finally {
      stub.mock.restore();
    }
  }
});

test("current question searches beyond news allowlist and gives useful fallback without citations", async () => {
  let calls = 0;
  const stub = mock.method(
    globalThis,
    "fetch",
    async (_url: any, options: any) => {
      const body = JSON.parse(options.body);
      calls++;
      if (calls === 1) return result({ ...draft, route: "web", script: "" });
      if (calls === 2) {
        assert.equal(body.tool_choice, "required");
        assert.equal(body.tools[0].filters, undefined);
        assert.deepEqual(body.include, ["web_search_call.action.sources"]);
        return result("No current information verified.");
      }
      assert.match(body.input, /could not be verified/);
      assert.equal(body.text.format.schema.properties.sourceURLs.maxItems, 0);
      return result({
        ...draft,
        script:
          "I could not verify the latest information. I can explain the background, but I would not treat that as confirmation of what happened today.",
      });
    },
  );
  try {
    const answer = await new Providers({
      ...config,
      NEWS_DOMAINS: "news.example",
    }).answer("What changed today?", "", new AbortController().signal);
    assert.equal(answer.sources.length, 0);
    assert.match(answer.script, /could not verify/);
  } finally {
    stub.mock.restore();
  }
});

test("consulted web URLs remain usable when provider omits inline citations", async () => {
  let calls = 0;
  const stub = mock.method(globalThis, "fetch", async () => {
    calls++;
    if (calls === 1) return result({ ...draft, route: "web" });
    if (calls === 2)
      return Response.json({
        status: "completed",
        output: [
          {
            type: "web_search_call",
            action: { sources: [{ url: source.url, title: source.title }] },
          },
          { content: [{ type: "output_text", text: "Retrieved evidence." }] },
        ],
      });
    return result({ ...draft, sourceURLs: [source.url] });
  });
  try {
    const answer = await new Providers(config).answer(
      "Look that up",
      "",
      new AbortController().signal,
    );
    assert.equal(answer.sources[0]?.url, source.url);
  } finally {
    stub.mock.restore();
  }
});

test("market path never invents a number when lookup has no verified quote", async () => {
  let calls = 0;
  const stub = mock.method(globalThis, "fetch", async () =>
    ++calls === 1
      ? result({ ...draft, route: "market" })
      : result("No quote available"),
  );
  try {
    const answer = await new Providers(config).answer(
      "Nvidia price right now?",
      "",
      new AbortController().signal,
    );
    assert.equal(calls, 2);
    assert.match(answer.script, /couldn’t verify/);
    assert.equal(answer.sources.length, 0);
  } finally {
    stub.mock.restore();
  }
});

test("market quote validation requires a recent timestamp and a retrieved URL", () => {
  const now = Date.parse("2026-10-18T18:00:00Z");
  const quote = {
    symbol: "NVDA",
    currency: "USD",
    price: 100,
    asOf: "2026-10-16T20:00:00Z",
    session: "last_close",
    sourceURL: source.url,
  };
  assert.match(quoteScript(quote, [source], now)!.text, /last closing price/);
  for (const change of [
    { sourceURL: "https://invented.example" },
    { asOf: "2020-01-01T00:00:00Z" },
    { asOf: "2026-10-19T20:00:00Z" },
    { asOf: "unknown" },
    { price: -10 },
  ])
    assert.equal(quoteScript({ ...quote, ...change }, [source], now), null);
});

test("context source extraction deduplicates original story and prior turns", () => {
  assert.equal(
    contextSources(
      JSON.stringify({
        sources: [source],
        previousTurns: [{ sources: [source] }],
      }),
    ).length,
    1,
  );
  assert.deepEqual(contextSources("bad JSON"), []);
});

test("daily research still fails closed when no citations are available", async () => {
  const stub = mock.method(globalThis, "fetch", async () =>
    result("No verified news"),
  );
  try {
    await assert.rejects(
      new Providers(config).research(
        "Daily news",
        "",
        new AbortController().signal,
      ),
      /not enough sourced/,
    );
  } finally {
    stub.mock.restore();
  }
});

test("timings correlate stages and record failure duration without error contents", async () => {
  const events: any[] = [];
  const stub = mock.method(console, "log", (value: any) => {
    events.push(JSON.parse(value));
  });
  try {
    await withTiming({ jobID: "one" }, () =>
      measured("script", async () => 42),
    );
    await assert.rejects(
      withTiming({ jobID: "two" }, () =>
        measured("speech", async () => {
          throw Error("PRIVATE BODY");
        }),
      ),
    );
    assert(
      events.some(
        (x) =>
          x.jobID === "one" &&
          x.stage === "script" &&
          x.status === "completed" &&
          x.durationMs >= 0,
      ),
    );
    assert(
      events.some(
        (x) => x.jobID === "two" && x.status === "failed" && x.durationMs >= 0,
      ),
    );
    assert(!JSON.stringify(events).includes("PRIVATE BODY"));
  } finally {
    stub.mock.restore();
  }
});

test("a short clarification remains a valid spoken answer", async () => {
  const stub = mock.method(globalThis, "fetch", async () =>
    result({
      ...draft,
      route: "general",
      title: "Clarification",
      summary: "Clarifying your question.",
      script: "Which company do you mean?",
    }),
  );
  try {
    const answer = await new Providers(config).answer(
      "What about it?",
      "",
      new AbortController().signal,
    );
    assert.equal(answer.script, "Which company do you mean?");
  } finally {
    stub.mock.restore();
  }
});
