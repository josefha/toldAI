import { z } from "zod";
import type { Source } from "./domain.js";

export const routes = ["context", "general", "web", "market"] as const;
export type Route = (typeof routes)[number];
export const routeResult = z.object({
  route: z.enum(routes),
  title: z.string(),
  category: z.enum(["technology", "planet", "science", "culture", "business"]),
  summary: z.string(),
  script: z.string(),
  sourceURLs: z.array(z.string()),
});
export function contextSources(context: string): Source[] {
  try {
    const data = JSON.parse(context);
    const schema = z.object({
      id: z.string(),
      name: z.string(),
      title: z.string(),
      url: z.string().url(),
      note: z.string(),
    });
    const values = [
      ...(data.sources ?? []),
      ...(data.previousTurns ?? []).flatMap((turn: any) => turn.sources ?? []),
    ];
    const unique = new Map<string, Source>();
    for (const item of values) {
      const parsed = schema.safeParse(item);
      if (parsed.success && /^https?:\/\//.test(parsed.data.url))
        unique.set(parsed.data.url, parsed.data);
    }
    return [...unique.values()].map((s, i) => ({ ...s, id: String(i + 1) }));
  } catch {
    return [];
  }
}
export const quoteSchema = z.object({
  symbol: z.string().min(1).max(25),
  currency: z.string().regex(/^[A-Z]{3}$/),
  price: z.number().positive(),
  asOf: z.string().datetime({ offset: true }),
  session: z.enum(["last_close", "delayed", "latest_available"]),
  sourceURL: z.string().url(),
});
export function quoteScript(
  value: unknown,
  sources: Source[],
  now = Date.now(),
) {
  const parsed = quoteSchema.safeParse(value);
  if (!parsed.success) return null;
  const quote = parsed.data;
  const source = sources.find((s) => s.url === quote.sourceURL);
  const timestamp = Date.parse(quote.asOf);
  // No unsupported live quote, future timestamp, or stale price presented as current.
  if (!source || timestamp > now + 300_000 || timestamp < now - 7 * 86400_000)
    return null;
  const date = new Date(timestamp)
    .toISOString()
    .replace("T", " at ")
    .replace(/\.\d{3}Z$/, " UTC");
  const label =
    quote.session === "last_close"
      ? "last closing price"
      : quote.session === "delayed"
        ? "delayed quote"
        : "latest available quote";
  return {
    quote,
    source,
    text: `The ${label} I found for ${quote.symbol} is ${quote.price} ${quote.currency}, as of ${date}, according to ${source.name}. This is a timestamped quote, not a guaranteed live price; it may differ from the price available when you trade.`,
  };
}
