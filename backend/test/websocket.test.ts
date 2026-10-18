import { test } from "node:test";
import assert from "node:assert/strict";
import { WebSocketServer, WebSocket } from "ws";
import { readFile } from "node:fs/promises";
import { Providers } from "../src/providers.js";
import { readConfig } from "../src/config.js";
const config = readConfig({
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "test-only-secret-key",
  OPENAI_API_KEY: "test-only-openai",
  ELEVENLABS_API_KEY: "test-only-eleven",
  ELEVENLABS_VOICE_ID: "testvoice",
});
test("Eleven v4 wire protocol registers a voice, sends text, flushes, and collects final audio", async () => {
  const server = new WebSocketServer({ port: 0 });
  await new Promise<void>((resolve) => server.once("listening", resolve));
  const address = server.address();
  assert.equal(typeof address, "object");
  const port = (address as any).port;
  // Locally synthesized test recording encoded as MP3; never used by the app.
  const audio = await readFile(
    new URL("./fixtures/voice.mp3", import.meta.url),
  );
  const messages: any[] = [];
  server.on("connection", (socket) =>
    socket.on("message", (raw) => {
      const msg = JSON.parse(raw.toString());
      messages.push(msg);
      if (msg.close_socket)
        socket.send(
          JSON.stringify({ audio: audio.toString("base64"), is_final: true }),
        );
    }),
  );
  try {
    const provider = new Providers(config, (url, options) => {
      assert.match(url, /text-to-dialogue\/stream-input/);
      assert.match(url, /eleven_v4_turbo/);
      return new WebSocket(`ws://127.0.0.1:${port}`, options);
    });
    const result = await provider.speech(
      "A real script would be sent here.",
      "eleven_v4_turbo",
      new AbortController().signal,
    );
    assert.ok(result.duration > 0);
    assert.deepEqual(messages[0].voices, ["testvoice"]);
    assert.equal(messages[1].inputs[0].voice_id, "testvoice");
    assert.equal(messages[2].close_socket, true);
  } finally {
    for (const client of server.clients) client.terminate();
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});
