import { z } from "zod";

export const deliveryVersion = 1;
export const deliveryTones = [
  "calm",
  "warm",
  "curious",
  "thoughtful",
  "reassuring",
  "serious",
] as const;
export const deliveryPlan = z.object({
  tones: z.array(z.enum(deliveryTones)).min(1).max(40),
});
export const spokenStyle = `Write for one interested listener: gentle, attentive and quietly engaged. Use short spoken thoughts, contractions, and plain international English. Separate changes of thought with paragraph breaks so the voice has room to pause. Vary sentence length without rushing through lists. Let the meaning create emotion: curiosity for an explanation, measured concern for difficult news, warmth when appropriate. Avoid announcer energy, hype, forced empathy, invented personal feelings, and repeated filler. Output clean spoken words, without audio tags or stage directions; delivery is handled separately.`;

export function deliveryBlocks(text: string): string[] {
  // Prevent source/user brackets from becoming uncontrolled ElevenLabs directions.
  const plain = text.replaceAll("[", "(").replaceAll("]", ")");
  return plain
    .split(/\n\s*\n/)
    .map((s) => s.trim())
    .filter(Boolean);
}

export function directedText(
  blocks: string[],
  tones?: readonly string[],
): string {
  const valid = deliveryPlan.safeParse({ tones });
  const selected =
    valid.success && valid.data.tones.length === blocks.length
      ? valid.data.tones
      : undefined;
  const tags: Record<(typeof deliveryTones)[number], string> = {
    calm: "[calm]",
    warm: "[warmly]",
    curious: "[curious]",
    thoughtful: "[thoughtful]",
    reassuring: "[reassuring]",
    serious: "[serious]",
  };
  return blocks
    .map((block, i) => `${tags[selected?.[i] ?? "calm"]} [slow] ${block}`)
    .join("\n\n[short pause]\n\n");
}
