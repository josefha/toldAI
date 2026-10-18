import { z } from "zod";
export const interests = [
  "technology",
  "planet",
  "science",
  "culture",
  "business",
] as const;
export const voice = z.enum(["eleven_v4", "eleven_v4_turbo"]);
export const profileInput = z.object({
  name: z.string().trim().max(80),
  interests: z.array(z.enum(interests)).min(1).max(5),
  location: z.string().trim().max(120),
  language: z.literal("en"),
  playbackSpeed: z.number().min(0.75).max(2),
  briefingVoiceModel: voice,
  answerVoiceModel: voice,
  completedOnboarding: z.boolean(),
});
export type Profile = z.infer<typeof profileInput> & {
  userID: string;
  email: string;
};
export type Source = {
  id: string;
  name: string;
  title: string;
  url: string;
  note: string;
};
export type Story = {
  id: string;
  title: string;
  category: (typeof interests)[number];
  summary: string;
  transcript: string;
  sources: Source[];
  artworkID: string;
  audioResource: string;
  duration: number;
};
export type Briefing = {
  id: string;
  title: string;
  generatedAt: string;
  artworkID: string;
  stories: Story[];
};
export type Answer = {
  id: string;
  question: string;
  text: string;
  sources: Source[];
  audioResource: string;
};
export const jobInput = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("daily"), requestID: z.string().uuid() }),
  z.object({
    kind: z.literal("podcast"),
    requestID: z.string().uuid(),
    question: z.string().trim().min(3).max(1200),
  }),
  z.object({
    kind: z.literal("question"),
    requestID: z.string().uuid(),
    question: z.string().trim().min(1).max(1200),
    storyID: z.string().uuid(),
    previousAnswerIDs: z.array(z.string().uuid()).max(12).default([]),
  }),
]);
export type JobInput = z.infer<typeof jobInput>;
export type Job = {
  id: string;
  user_id: string;
  kind: JobInput["kind"];
  input: JobInput;
  status: string;
  worker_id: string;
  result: Briefing | Answer | null;
  error: string | null;
  attempts: number;
};
export class PublicError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}
export const defaultProfile = (id: string, email: string): Profile => ({
  userID: id,
  email,
  name: "",
  interests: ["technology", "planet"],
  location: "",
  language: "en",
  playbackSpeed: 1,
  briefingVoiceModel: "eleven_v4",
  answerVoiceModel: "eleven_v4_turbo",
  completedOnboarding: false,
});
