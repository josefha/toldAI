# Live implementation

Frontend snapshot committed as f8271ff before backend work.

1. Real Supabase email OTP, Keychain refresh tokens, profile persistence and account deletion.
2. TypeScript API + durable Postgres jobs, ownership, bounded generation, cancellation, private audio URLs.
3. OpenAI web-search evidence → structured script → Eleven v4/v4 Turbo audio. Public reporting only; no paywall bypass. Source verification rejects invented URLs.
4. Daily five cached by date/interests/voice; on-demand podcasts and follow-up questions use the same pipeline and player.
5. Native microphone → server transcription → real question. No fixture runtime.
6. Local Supabase/auth/RLS integration, backend contract tests, Swift tests/build, deployment manifest and credential preflight.

Tradeoff: complete audio segments are downloaded before playback; true streaming and sentence-aligned return transitions are future enhancements. Live provider quality/latency cannot be verified until real keys and voice access are supplied. No fake fallback is used when a provider fails.
