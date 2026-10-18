import { z } from "zod";
const schema = z.object({
  PORT: z.coerce.number().int().positive().default(8080),
  HOST: z.string().default("0.0.0.0"),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(16),
  OPENAI_API_KEY: z.string().min(10),
  OPENAI_MODEL: z.string().default("gpt-5-mini"),
  OPENAI_ANSWER_MODEL: z.string().min(1).optional(),
  OPENAI_SCRIPT_MODEL: z.string().min(1).optional(),
  OPENAI_TRANSCRIBE_MODEL: z.string().default("gpt-4o-mini-transcribe"),
  ELEVENLABS_API_KEY: z.string().min(10),
  ELEVENLABS_VOICE_ID: z.string().min(5),
  DAILY_JOB_LIMIT: z.coerce.number().int().min(1).default(12),
  QUESTION_JOB_LIMIT: z.coerce.number().int().min(1).default(40),
  TRANSCRIPTION_LIMIT: z.coerce.number().int().min(1).default(60),
  NEWS_DOMAINS: z.string().default(""),
  WORKER_ENABLED: z.enum(["true", "false"]).default("true"),
});
export type Config = z.infer<typeof schema>;
export function readConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const result = schema.safeParse(env);
  if (!result.success)
    throw new Error(
      `Missing or invalid configuration: ${result.error.issues.map((i) => i.path.join(".")).join(", ")}`,
    );
  return result.data;
}
