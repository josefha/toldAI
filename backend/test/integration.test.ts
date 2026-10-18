import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import { readConfig } from "../src/config.js";
import { Store } from "../src/store.js";
import { createAPI } from "../src/api.js";
import { Providers } from "../src/providers.js";
import { Worker } from "../src/worker.js";
const enabled = Boolean(
  process.env.TEST_SUPABASE_URL &&
    process.env.TEST_SUPABASE_SERVICE_KEY &&
    process.env.TEST_SUPABASE_ANON_KEY,
);
test(
  "real Supabase auth, API ownership, queue completion, signed audio and RLS",
  { skip: !enabled },
  async () => {
    const config = readConfig({
      SUPABASE_URL: process.env.TEST_SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY: process.env.TEST_SUPABASE_SERVICE_KEY,
      OPENAI_API_KEY: "test-only-openai",
      ELEVENLABS_API_KEY: "test-only-eleven",
      ELEVENLABS_VOICE_ID: "testvoice",
    });
    const store = new Store(config);
    const users: string[] = [];
    const audioFiles: string[] = [];
    class TestProviders extends Providers {
      override async research() {
        return {
          title: "Test report",
          category: "science" as const,
          summary: "A sourced summary used only by tests.",
          script: "A test script used only by the isolated integration test.",
          sourceURLs: ["https://example.com/report"],
          sources: [
            {
              id: "1",
              name: "example.com",
              title: "Report",
              url: "https://example.com/report",
              note: "Test citation",
            },
          ],
        };
      }
      override async answer() {
        return this.research();
      }
      override async speech() {
        return { audio: Buffer.from("test audio bytes"), duration: 12 };
      }
    }
    const providers = new TestProviders(config);
    const app = await createAPI(config, store, providers);
    async function user() {
      const email = `told-test-${randomUUID()}@example.com`;
      const password = randomUUID() + "Aa1!";
      const { data, error } = await store.db.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      });
      assert.ifError(error);
      users.push(data.user!.id);
      const client = createClient(
        config.SUPABASE_URL,
        process.env.TEST_SUPABASE_ANON_KEY!,
        { auth: { persistSession: false, autoRefreshToken: false } },
      );
      const signed = await client.auth.signInWithPassword({ email, password });
      assert.ifError(signed.error);
      return {
        id: data.user!.id,
        client,
        headers: {
          authorization: `Bearer ${signed.data.session!.access_token}`,
        },
      };
    }
    try {
      const a = await user();
      const b = await user();
      assert.equal(
        (await app.inject({ method: "GET", url: "/v1/me" })).statusCode,
        401,
      );
      assert.equal(
        (
          await app.inject({
            method: "GET",
            url: "/v1/me",
            headers: { authorization: "Bearer invalid" },
          })
        ).statusCode,
        401,
      );
      const profile = (
        await app.inject({ method: "GET", url: "/v1/me", headers: a.headers })
      ).json();
      profile.completedOnboarding = true;
      assert.equal(
        (
          await app.inject({
            method: "PATCH",
            url: "/v1/me",
            headers: a.headers,
            payload: profile,
          })
        ).statusCode,
        200,
      );
      const foreign = await b.client
        .from("profiles")
        .select("*")
        .eq("user_id", a.id);
      assert.ifError(foreign.error);
      assert.deepEqual(foreign.data, []);
      const write = await b.client
        .from("profiles")
        .insert({ user_id: a.id, data: {} });
      assert.ok(write.error);
      const id = randomUUID();
      audioFiles.push(`${id}.mp3`);
      const input = {
        kind: "podcast",
        requestID: id,
        question: "What happened in science?",
      };
      assert.equal(
        (
          await app.inject({
            method: "POST",
            url: "/v1/jobs",
            headers: a.headers,
            payload: input,
          })
        ).statusCode,
        202,
      );
      assert.equal(
        (
          await app.inject({
            method: "POST",
            url: "/v1/jobs",
            headers: a.headers,
            payload: input,
          })
        ).statusCode,
        202,
      );
      assert.equal(
        (
          await app.inject({
            method: "POST",
            url: "/v1/jobs",
            headers: a.headers,
            payload: { ...input, question: "Different request" },
          })
        ).statusCode,
        409,
      );
      assert.equal(
        (
          await app.inject({
            method: "GET",
            url: `/v1/jobs/${id}`,
            headers: b.headers,
          })
        ).statusCode,
        404,
      );
      const worker = new Worker(store, providers, config);
      const claimed = await store.db.rpc("claim_job", { worker: worker.id });
      assert.ifError(claimed.error);
      assert.equal(claimed.data[0].id, id);
      await worker.process(claimed.data[0]);
      const response = await app.inject({
        method: "GET",
        url: `/v1/jobs/${id}`,
        headers: a.headers,
      });
      assert.equal(response.statusCode, 200);
      const result = response.json();
      assert.equal(result.status, "completed");
      assert.match(result.result.stories[0].audioResource, /token=/);
      const denied = await b.client.from("listening_sessions").select("*");
      assert.deepEqual(denied.data, []);
      const questionID = randomUUID();
      assert.equal(
        (
          await app.inject({
            method: "POST",
            url: "/v1/jobs",
            headers: a.headers,
            payload: {
              kind: "question",
              requestID: questionID,
              question: "Why?",
              storyID: id,
              previousAnswerIDs: [],
            },
          })
        ).statusCode,
        202,
      );
      assert.equal(
        (
          await app.inject({
            method: "DELETE",
            url: `/v1/jobs/${questionID}`,
            headers: a.headers,
          })
        ).statusCode,
        204,
      );
      assert.equal((await store.job(questionID, a.id)).status, "cancelled");
      const usage = await Promise.all(
        Array.from({ length: 4 }, () =>
          store.db.rpc("consume_usage", {
            owner_id: a.id,
            bucket_name: "concurrent-test",
            maximum: 2,
          }),
        ),
      );
      assert.equal(usage.filter((r) => r.data === true).length, 2);
      assert.ok(
        (await a.client.rpc("claim_job", { worker: randomUUID() })).error,
      );
      const followUpID = randomUUID();
      audioFiles.push(`${followUpID}.mp3`);
      await app.inject({
        method: "POST",
        url: "/v1/jobs",
        headers: a.headers,
        payload: {
          kind: "question",
          requestID: followUpID,
          question: "Explain the implications",
          storyID: id,
          previousAnswerIDs: [],
        },
      });
      const followUp = await store.db.rpc("claim_job", { worker: worker.id });
      assert.equal(followUp.data[0].id, followUpID);
      await worker.process(followUp.data[0]);
      const completedAnswer = (
        await app.inject({
          method: "GET",
          url: `/v1/jobs/${followUpID}`,
          headers: a.headers,
        })
      ).json();
      assert.equal(completedAnswer.status, "completed");
      assert.equal(completedAnswer.result.question, "Explain the implications");
      assert.equal((await store.history(a.id, id, [followUpID])).length, 1);
      await assert.rejects(store.history(b.id, id, [followUpID]));
      assert.equal(
        (
          await app.inject({
            method: "DELETE",
            url: "/v1/me",
            headers: a.headers,
          })
        ).statusCode,
        204,
      );
      assert.equal(
        (await app.inject({ method: "GET", url: "/v1/me", headers: a.headers }))
          .statusCode,
        401,
      );
      const remaining = await store.db
        .from("answers")
        .select("id")
        .eq("user_id", a.id);
      assert.deepEqual(remaining.data, []);
      const deletedAudio = await store.db.storage
        .from("told-audio")
        .download(`${followUpID}.mp3`);
      assert.ok(deletedAudio.error);
    } finally {
      await app.close();
      if (audioFiles.length)
        await store.db.storage.from("told-audio").remove(audioFiles);
      for (const id of users) await store.db.auth.admin.deleteUser(id);
    }
  },
);
