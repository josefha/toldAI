import { AsyncLocalStorage } from "node:async_hooks";
import { performance } from "node:perf_hooks";

type Fields = Record<string, string | number | boolean>;
const context = new AsyncLocalStorage<Fields>();
export function withTiming<T>(fields: Fields, run: () => T): T {
  return context.run({ ...context.getStore(), ...fields }, run);
}
export function timing(stage: string, fields: Fields = {}) {
  // Only operational metadata: never prompts, transcripts, URLs, tokens or provider bodies.
  console.log(
    JSON.stringify({
      event: "timing",
      time: new Date().toISOString(),
      ...context.getStore(),
      stage,
      ...fields,
    }),
  );
}
export async function measured<T>(
  stage: string,
  run: () => Promise<T>,
  fields: Fields = {},
): Promise<T> {
  const start = performance.now();
  timing(stage, { ...fields, status: "started" });
  try {
    const result = await run();
    timing(stage, {
      ...fields,
      status: "completed",
      durationMs: Math.round(performance.now() - start),
    });
    return result;
  } catch (error) {
    timing(stage, {
      ...fields,
      status: "failed",
      durationMs: Math.round(performance.now() - start),
      errorType: error instanceof Error ? error.name : "unknown",
    });
    throw error;
  }
}
