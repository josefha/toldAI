// Opt-in paid provider check. Use a disposable, onboarded test account.
import { randomUUID } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";
import { readFile } from "node:fs/promises";
const base = process.env.SMOKE_API_URL;
const token = process.env.SMOKE_ACCESS_TOKEN;
if (!base || !token)
  throw new Error(
    "Set SMOKE_API_URL and SMOKE_ACCESS_TOKEN for an onboarded test account. This check incurs provider charges.",
  );
async function api(path: string, body?: object) {
  const response = await fetch(`${base}/v1/${path}`, {
    method: body ? "POST" : "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(90_000),
  });
  if (!response.ok)
    throw new Error(`${path.split("/")[0]} failed (${response.status}).`);
  return response.json() as Promise<any>;
}
async function generate(input: object) {
  const { id } = await api("jobs", { ...input, requestID: randomUUID() });
  for (let i = 0; i < 450; i++) {
    const job = await api(`jobs/${id}`);
    if (job.status === "completed") return job.result;
    if (["failed", "cancelled"].includes(job.status))
      throw new Error(job.error ?? "Generation failed.");
    await delay(2000);
  }
  throw new Error("Generation exceeded 15 minutes. Inspect the job queue.");
}
async function audio(url: string) {
  const response = await fetch(url, { signal: AbortSignal.timeout(60_000) });
  if (
    !response.ok ||
    !(response.headers.get("content-type") ?? "").startsWith("audio/") ||
    (await response.arrayBuffer()).byteLength < 100
  )
    throw new Error("Audio download failed.");
}
const profile = await api("me");
if (!profile.completedOnboarding)
  throw new Error("Complete onboarding in the app first.");
let question = "What changed in renewable energy news in the last 24 hours?";
if (process.env.SMOKE_RECORDING) {
  const form = new FormData();
  form.set(
    "file",
    new Blob([new Uint8Array(await readFile(process.env.SMOKE_RECORDING))], {
      type: "audio/mp4",
    }),
    "question.m4a",
  );
  const response = await fetch(`${base}/v1/transcriptions`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
    body: form,
    signal: AbortSignal.timeout(90_000),
  });
  if (!response.ok)
    throw new Error(`Transcription failed (${response.status}).`);
  question = ((await response.json()) as { text: string }).text;
  console.log("Recording transcribed.");
}
const episode = await generate({ kind: "podcast", question });
if (!episode.stories?.[0]?.sources?.length)
  throw new Error("Episode has no sources.");
await audio(episode.stories[0].audioResource);
console.log("Sourced podcast and audio passed.");
const answer = await generate({
  kind: "question",
  question: "Why does this matter, and what remains uncertain?",
  storyID: episode.stories[0].id,
  previousAnswerIDs: [],
});
if (!answer.sources?.length) throw new Error("Answer has no sources.");
await audio(answer.audioResource);
console.log("Follow-up and audio passed.");
if (process.env.SMOKE_DAILY === "true") {
  const daily = await generate({ kind: "daily" });
  if (daily.stories.length !== 5)
    throw new Error("Daily edition did not contain five stories.");
  for (const story of daily.stories) await audio(story.audioResource);
  console.log("Daily five passed.");
}
console.log(
  "Live smoke test passed. Check the app on a real device for microphone, audio routes, and perceived latency.",
);
