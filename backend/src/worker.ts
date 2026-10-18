import { createHash, randomUUID } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";
import type { Config } from "./config.js";
import { Providers, type Script } from "./providers.js";
import { Store, check } from "./store.js";
import {
  PublicError,
  type Answer,
  type Briefing,
  type Job,
  type Profile,
  type Story,
} from "./domain.js";
export class Worker {
  private stopped = false;
  private current?: AbortController;
  readonly id = randomUUID();
  constructor(
    private store: Store,
    private providers: Providers,
    private config: Config,
    private log: (message: string) => void = console.error,
  ) {}
  stop() {
    this.stopped = true;
    this.current?.abort();
  }
  async run() {
    while (!this.stopped) {
      try {
        await this.store.db
          .from("jobs")
          .update({
            status: "failed",
            error: "Generation was interrupted repeatedly. Please try again.",
          })
          .eq("status", "running")
          .lt("lease_until", new Date().toISOString())
          .gte("attempts", 3);
        const { data, error } = await this.store.db.rpc("claim_job", {
          worker: this.id,
        });
        check(error);
        const job = data?.[0] as Job | undefined;
        if (job) await this.process(job);
        else await delay(1000);
      } catch {
        this.log("Worker iteration failed; retrying.");
        await delay(3000);
      }
    }
  }
  private async render(
    script: Script,
    id: string,
    model: string,
    signal: AbortSignal,
  ): Promise<Story> {
    signal.throwIfAborted();
    const speech = await this.providers.speech(script.script, model, signal);
    signal.throwIfAborted();
    const audioResource = await this.store.upload(`${id}.mp3`, speech.audio);
    return {
      id,
      title: script.title,
      category: script.category,
      summary: script.summary,
      transcript: script.script,
      sources: script.sources,
      artworkID:
        script.category === "planet"
          ? "planet"
          : script.category === "technology" || script.category === "science"
            ? "technology"
            : "daily",
      audioResource,
      duration: speech.duration,
    };
  }
  private async daily(
    profile: Profile,
    signal: AbortSignal,
  ): Promise<Briefing> {
    const key = createHash("sha256")
      .update(
        JSON.stringify({
          day: new Date().toISOString().slice(0, 10),
          interests: [...new Set(profile.interests)].sort(),
          model: this.config.OPENAI_MODEL,
          voice: profile.briefingVoiceModel,
          voiceID: this.config.ELEVENLABS_VOICE_ID,
          domains: this.config.NEWS_DOMAINS,
          version: 1,
        }),
      )
      .digest("hex");
    while (true) {
      signal.throwIfAborted();
      const { data, error } = await this.store.db
        .from("content_cache")
        .select("data,expires_at")
        .eq("key", key)
        .maybeSingle();
      check(error);
      if (data?.data && Date.parse(data.expires_at) > Date.now())
        return data.data;
      const { data: claimed, error: claimError } = await this.store.db.rpc(
        "claim_cache",
        { cache_key: key, worker: this.id },
      );
      check(claimError);
      if (claimed) break;
      await delay(2000, undefined, { signal });
    }
    try {
      const stories: Story[] = [];
      for (let i = 0; i < 5; i++) {
        const category = profile.interests[i % profile.interests.length]!;
        const script = await this.providers.research(
          `Choose one important, distinct news development from the last 24 hours about ${category}. If coverage is thin, extend to the last 72 hours and say the date. Do not repeat these already selected topics: ${stories.map((s) => s.title).join("; ")}.`,
          "",
          signal,
        );
        stories.push(
          await this.render(
            script,
            randomUUID(),
            profile.briefingVoiceModel,
            signal,
          ),
        );
      }
      const result: Briefing = {
        id: randomUUID(),
        title: "Your daily five",
        generatedAt: new Date().toISOString(),
        artworkID: "daily",
        stories,
      };
      const { error } = await this.store.db
        .from("content_cache")
        .update({
          data: result,
          expires_at: new Date(Date.now() + 20 * 3600_000).toISOString(),
          lease_until: null,
        })
        .eq("key", key)
        .eq("owner", this.id);
      check(error);
      return result;
    } catch (error) {
      await this.store.db
        .from("content_cache")
        .update({ lease_until: null })
        .eq("key", key)
        .eq("owner", this.id);
      throw error;
    }
  }
  async process(job: Job) {
    const controller = new AbortController();
    this.current = controller;
    const signal = AbortSignal.any([
      controller.signal,
      AbortSignal.timeout(14 * 60_000),
    ]);
    const heartbeat = setInterval(() => {
      void (async () => {
        const { data, error } = await this.store.db
          .from("jobs")
          .update({
            lease_until: new Date(Date.now() + 120_000).toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", job.id)
          .eq("worker_id", this.id)
          .eq("status", "running")
          .select("id");
        if (error || !data?.length) controller.abort();
      })();
    }, 10_000);
    try {
      const profile = await this.store.profile(job.user_id);
      let result: Briefing | Answer;
      if (job.input.kind === "question") {
        const story = await this.store.story(job.user_id, job.input.storyID);
        const history = await this.store.history(
          job.user_id,
          story.id,
          job.input.previousAnswerIDs,
        );
        const script = await this.providers.research(
          job.input.question,
          JSON.stringify({
            story: story.transcript,
            sources: story.sources,
            previousTurns: history.map((a) => ({
              question: a.question,
              answer: a.text,
            })),
          }),
          signal,
        );
        const rendered = await this.render(
          script,
          job.id,
          profile.answerVoiceModel,
          signal,
        );
        result = {
          id: job.id,
          question: job.input.question,
          text: script.script,
          sources: script.sources,
          audioResource: rendered.audioResource,
        };
        signal.throwIfAborted();
        const { error } = await this.store.db
          .from("answers")
          .upsert({
            id: job.id,
            user_id: job.user_id,
            story_id: story.id,
            data: result,
          });
        check(error);
      } else {
        if (job.input.kind === "daily")
          result = await this.daily(profile, signal);
        else {
          const script = await this.providers.research(
            job.input.question,
            "",
            signal,
          );
          const story = await this.render(
            script,
            job.id,
            profile.briefingVoiceModel,
            signal,
          );
          result = {
            id: job.id,
            title: script.title,
            generatedAt: new Date().toISOString(),
            artworkID: story.artworkID,
            stories: [story],
          };
        }
        // Each user owns their session even when the underlying daily content is shared.
        result = { ...result, id: job.id };
        signal.throwIfAborted();
        const { error } = await this.store.db
          .from("listening_sessions")
          .upsert({ id: job.id, user_id: job.user_id, data: result });
        check(error);
      }
      signal.throwIfAborted();
      const { data: completed, error } = await this.store.db
        .from("jobs")
        .update({
          status: "completed",
          result,
          lease_until: null,
          updated_at: new Date().toISOString(),
        })
        .eq("id", job.id)
        .eq("worker_id", this.id)
        .eq("status", "running")
        .select("id");
      check(error);
      if (!completed?.length) throw new DOMException("Cancelled", "AbortError");
    } catch (error) {
      const message =
        error instanceof PublicError
          ? error.message
          : signal.aborted
            ? "The request was interrupted. Please try again."
            : "Could not prepare this episode. Please try again.";
      await this.store.db
        .from("jobs")
        .update({
          status: "failed",
          error: message,
          lease_until: null,
          updated_at: new Date().toISOString(),
        })
        .eq("id", job.id)
        .eq("worker_id", this.id)
        .eq("status", "running");
      if (job.kind !== "daily")
        await this.store.db.storage
          .from("told-audio")
          .remove([`${job.id}.mp3`]);
      this.log(
        `Generation ${job.id} failed (${error instanceof PublicError ? error.status : "internal"}).`,
      );
    } finally {
      clearInterval(heartbeat);
      this.current = undefined;
    }
  }
}
