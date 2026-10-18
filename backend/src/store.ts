import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Config } from "./config.js";
import {
  PublicError,
  defaultProfile,
  type Profile,
  type Briefing,
  type Answer,
  type Story,
  type Job,
} from "./domain.js";
export function check(error: unknown) {
  if (error)
    throw new PublicError(
      503,
      "The service is temporarily unavailable. Please try again.",
    );
}
export class Store {
  readonly db: SupabaseClient;
  constructor(config: Config) {
    this.db = createClient(
      config.SUPABASE_URL,
      config.SUPABASE_SERVICE_ROLE_KEY,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
  }
  async profile(userID: string, email = ""): Promise<Profile> {
    const { data, error } = await this.db
      .from("profiles")
      .select("data")
      .eq("user_id", userID)
      .maybeSingle();
    check(error);
    return data?.data ?? defaultProfile(userID, email);
  }
  async saveProfile(userID: string, profile: Profile) {
    const { error } = await this.db
      .from("profiles")
      .upsert({
        user_id: userID,
        data: profile,
        updated_at: new Date().toISOString(),
      });
    check(error);
  }
  async job(id: string, userID: string): Promise<Job> {
    const { data, error } = await this.db
      .from("jobs")
      .select("*")
      .eq("id", id)
      .eq("user_id", userID)
      .maybeSingle();
    check(error);
    if (!data) throw new PublicError(404, "This request was not found.");
    return data;
  }
  async story(userID: string, id: string): Promise<Story> {
    const { data, error } = await this.db
      .from("listening_sessions")
      .select("data")
      .eq("user_id", userID)
      .contains("data", { stories: [{ id }] })
      .limit(1);
    check(error);
    const story = (data?.[0]?.data as Briefing | undefined)?.stories.find(
      (s) => s.id === id,
    );
    if (!story)
      throw new PublicError(
        404,
        "This story is no longer in your library. Start a new episode.",
      );
    return story;
  }
  async history(
    userID: string,
    storyID: string,
    ids: string[],
  ): Promise<Answer[]> {
    if (!ids.length) return [];
    const { data, error } = await this.db
      .from("answers")
      .select("data")
      .eq("user_id", userID)
      .eq("story_id", storyID)
      .in("id", ids)
      .order("created_at");
    check(error);
    if (data?.length !== ids.length)
      throw new PublicError(404, "Conversation history was not found.");
    return data.map((r) => r.data);
  }
  async upload(path: string, audio: Buffer) {
    const { error } = await this.db.storage
      .from("told-audio")
      .upload(path, audio, { contentType: "audio/mpeg", upsert: true });
    check(error);
    return path;
  }
  async hydrate(result: Briefing | Answer): Promise<Briefing | Answer> {
    const signed = async (path: string) => {
      const { data, error } = await this.db.storage
        .from("told-audio")
        .createSignedUrl(path, 3600);
      check(error);
      if (!data) throw new PublicError(503, "Audio is unavailable.");
      return data.signedUrl;
    };
    if ("stories" in result)
      return {
        ...result,
        stories: await Promise.all(
          result.stories.map(async (s) => ({
            ...s,
            audioResource: await signed(s.audioResource),
          })),
        ),
      };
    return { ...result, audioResource: await signed(result.audioResource) };
  }
  async limit(userID: string, bucket: string, maximum: number) {
    const { data, error } = await this.db.rpc("consume_usage", {
      owner_id: userID,
      bucket_name: bucket,
      maximum,
    });
    check(error);
    if (!data)
      throw new PublicError(
        429,
        "You’ve reached today’s limit. Please try again tomorrow.",
      );
  }
}
