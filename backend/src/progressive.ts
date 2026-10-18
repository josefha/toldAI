/** Split only at a complete sentence: the opening must stand on its own. */
export function answerPassages(text: string): string[] {
  const sentences = [
    ...new Intl.Segmenter("en", { granularity: "sentence" }).segment(text),
  ].map((s) => s.segment);
  if (sentences.length < 2 || text.trim().split(/\s+/).length <= 25)
    return [text];
  let boundary = 1;
  while (
    boundary < sentences.length &&
    sentences.slice(0, boundary).join("").trim().split(/\s+/).length < 8
  ) boundary++;
  const first = sentences.slice(0, boundary).join("").trim();
  const rest = sentences.slice(boundary).join("").trim();
  return rest.split(/\s+/).length >= 8 ? [first, rest] : [text];
}
