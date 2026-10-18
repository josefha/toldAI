import { readConfig } from "./config.js";
import { Store, check } from "./store.js";
const config = readConfig();
const store = new Store(config);
const { error } = await store.db.from("jobs").select("id").limit(1);
check(error);
const { data: bucket, error: bucketError } =
  await store.db.storage.getBucket("told-audio");
check(bucketError);
if (bucket?.public) throw new Error("told-audio must be private.");
for (const model of [config.OPENAI_MODEL, config.OPENAI_TRANSCRIBE_MODEL]) {
  const response = await fetch(
    `https://api.openai.com/v1/models/${encodeURIComponent(model)}`,
    {
      headers: { Authorization: `Bearer ${config.OPENAI_API_KEY}` },
      signal: AbortSignal.timeout(15_000),
    },
  );
  if (!response.ok)
    throw new Error(
      `OpenAI model access check failed: ${model} (${response.status})`,
    );
}
const modelsResponse = await fetch("https://api.elevenlabs.io/v1/models", {
  headers: { "xi-api-key": config.ELEVENLABS_API_KEY },
  signal: AbortSignal.timeout(15_000),
});
if (!modelsResponse.ok)
  throw new Error(`ElevenLabs model check failed (${modelsResponse.status}).`);
const models: any = await modelsResponse.json();
for (const id of ["eleven_v4", "eleven_v4_turbo"])
  if (!models.some((m: any) => m.model_id === id))
    throw new Error(`ElevenLabs account does not list ${id}.`);
const voice = await fetch(
  `https://api.elevenlabs.io/v1/voices/${encodeURIComponent(config.ELEVENLABS_VOICE_ID)}`,
  {
    headers: { "xi-api-key": config.ELEVENLABS_API_KEY },
    signal: AbortSignal.timeout(15_000),
  },
);
if (!voice.ok)
  throw new Error(`ElevenLabs voice check failed (${voice.status}).`);
console.log(
  "Database, private storage, model IDs, and voice access checks passed. Run the paid live smoke test before release.",
);
