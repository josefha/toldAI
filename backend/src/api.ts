import Fastify from "fastify";
import { isDeepStrictEqual } from "node:util";
import multipart from "@fastify/multipart";
import helmet from "@fastify/helmet";
import { z } from "zod";
import type { Config } from "./config.js";
import { Store, check } from "./store.js";
import { Providers } from "./providers.js";
import { PublicError, profileInput, jobInput } from "./domain.js";
export async function createAPI(
  config: Config,
  store = new Store(config),
  providers = new Providers(config),
) {
  const app = Fastify({
    bodyLimit: 64 * 1024,
    logger: {
      redact: ["req.headers.authorization", "req.headers.apikey"],
      level: "info",
    },
    disableRequestLogging: true,
  });
  await app.register(helmet);
  await app.register(multipart, {
    limits: { fileSize: 8 * 1024 * 1024, files: 1, fields: 0 },
  });
  app.setErrorHandler((error: any, _request, reply) => {
    if (error instanceof z.ZodError)
      return reply
        .code(400)
        .send({ error: "Please check the request and try again." });
    if (error instanceof PublicError)
      return reply.code(error.status).send({ error: error.message });
    app.log.error({ code: error.code }, "Request failed");
    return reply
      .code(error.statusCode === 413 ? 413 : 500)
      .send({
        error:
          error.statusCode === 413
            ? "Recording is too large. Please ask a shorter question."
            : "The request could not finish. Please try again.",
      });
  });
  app.get("/health", () => ({ status: "ok" }));
  app.get("/ready", async () => {
    const { error } = await store.db.from("jobs").select("id").limit(1);
    check(error);
    return { status: "ready" };
  });
  app.register(
    async (routes) => {
      routes.addHook("preHandler", async (request) => {
        const token =
          request.headers.authorization?.match(/^Bearer (.+)$/)?.[1];
        if (!token) throw new PublicError(401, "Please sign in to continue.");
        const { data, error } = await store.db.auth.getUser(token);
        if (error || !data.user)
          throw new PublicError(
            401,
            "Your session has expired. Please sign in again.",
          );
        (request as any).user = {
          id: data.user.id,
          email: data.user.email ?? "",
        };
      });
      routes.get("/me", async (request) => {
        const user = (request as any).user;
        return {
          ...(await store.profile(user.id, user.email)),
          email: user.email,
        };
      });
      routes.patch("/me", async (request) => {
        const user = (request as any).user;
        const data = profileInput.parse(request.body);
        const profile = {
          ...data,
          interests: [...new Set(data.interests)],
          userID: user.id,
          email: user.email,
        };
        await store.saveProfile(user.id, profile);
        return profile;
      });
      routes.post("/jobs", async (request, reply) => {
        const user = (request as any).user;
        const input = jobInput.parse(request.body);
        const { data: existing, error: lookupError } = await store.db
          .from("jobs")
          .select("*")
          .eq("id", input.requestID)
          .eq("user_id", user.id)
          .maybeSingle();
        check(lookupError);
        if (existing) {
          if (!isDeepStrictEqual(existing.input, input))
            throw new PublicError(409, "This request ID is already in use.");
          return reply
            .code(202)
            .send({ id: existing.id, status: existing.status });
        }
        const profile = await store.profile(user.id, user.email);
        if (!profile.completedOnboarding)
          throw new PublicError(409, "Choose your interests before starting.");
        if (input.kind === "question")
          await store.story(user.id, input.storyID);
        await store.limit(
          user.id,
          input.kind,
          input.kind === "question"
            ? config.QUESTION_JOB_LIMIT
            : config.DAILY_JOB_LIMIT,
        );
        const { error } = await store.db
          .from("jobs")
          .insert({
            id: input.requestID,
            user_id: user.id,
            kind: input.kind,
            input,
          });
        if (error?.code === "23505")
          throw new PublicError(409, "This request ID is already in use.");
        check(error);
        return reply.code(202).send({ id: input.requestID, status: "queued" });
      });
      routes.get("/jobs/:id", async (request) => {
        const { id } = z
          .object({ id: z.string().uuid() })
          .parse(request.params);
        const job = await store.job(id, (request as any).user.id);
        return {
          id: job.id,
          status: job.status,
          error: job.error,
          result:
            job.status === "completed" && job.result
              ? await store.hydrate(job.result)
              : null,
        };
      });
      routes.delete("/jobs/:id", async (request, reply) => {
        const { id } = z
          .object({ id: z.string().uuid() })
          .parse(request.params);
        const user = (request as any).user;
        await store.job(id, user.id);
        const { error } = await store.db
          .from("jobs")
          .update({ status: "cancelled", updated_at: new Date().toISOString() })
          .eq("id", id)
          .eq("user_id", user.id)
          .in("status", ["queued", "running"]);
        check(error);
        return reply.code(204).send();
      });
      routes.post("/transcriptions", async (request) => {
        const user = (request as any).user;
        await store.limit(user.id, "transcription", config.TRANSCRIPTION_LIMIT);
        const file = await request.file();
        if (
          !file ||
          !["audio/mp4", "audio/x-m4a", "audio/m4a"].includes(file.mimetype)
        )
          throw new PublicError(400, "Please send an M4A recording.");
        const buffer = await file.toBuffer();
        if (file.file.truncated)
          throw new PublicError(413, "Please ask a shorter question.");
        return {
          text: await providers.transcribe(buffer, AbortSignal.timeout(65_000)),
        };
      });
      routes.delete("/me", async (request, reply) => {
        const user = (request as any).user;
        const { error: cancelError } = await store.db
          .from("jobs")
          .update({ status: "cancelled" })
          .eq("user_id", user.id)
          .in("status", ["queued", "running"]);
        check(cancelError);
        const { data: sessions, error: sessionError } = await store.db
          .from("listening_sessions")
          .select("id")
          .eq("user_id", user.id);
        check(sessionError);
        const { data: answers, error: answerError } = await store.db
          .from("answers")
          .select("id")
          .eq("user_id", user.id);
        check(answerError);
        // Daily cache audio is shared; only user-specific generation uses job IDs.
        const files = [...(sessions ?? []), ...(answers ?? [])].map(
          (row) => `${row.id}.mp3`,
        );
        if (files.length) {
          const { error } = await store.db.storage
            .from("told-audio")
            .remove(files);
          check(error);
        }
        const { error } = await store.db.auth.admin.deleteUser(user.id);
        check(error);
        return reply.code(204).send();
      });
    },
    { prefix: "/v1" },
  );
  return app;
}
