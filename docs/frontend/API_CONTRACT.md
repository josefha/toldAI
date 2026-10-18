# Live API and frontend contract

Implemented in `backend/src/domain.ts`, `backend/src/api.ts`, and `ios/Told/Models/Domain.swift`. All `/v1` routes require `Authorization: Bearer <Supabase access token>`. The API validates identity with Supabase; client-supplied user IDs never determine ownership. JSON responses use camelCase domain fields, UUID identifiers, seconds for durations, and ISO-8601 UTC timestamps.

## Routes

| Route | Behavior |
|---|---|
| `GET /health` | Process liveness |
| `GET /ready` | Database connectivity |
| `GET /v1/me` | Profile, or defaults for a new authenticated account |
| `PATCH /v1/me` | Validate and save profile; identity/email come from auth |
| `DELETE /v1/me` | Cancel work, delete personal audio, delete auth user and cascading personal rows |
| `POST /v1/jobs` | Durable generation, HTTP 202 `{id,status}` |
| `GET /v1/jobs/:id` | Owner-only `{id,status,error,result}`; completed audio links are signed for one hour |
| `DELETE /v1/jobs/:id` | Best-effort cancellation of queued/running work, HTTP 204 |
| `POST /v1/transcriptions` | Multipart field `file`, M4A audio, ≤8 MiB → `{text}` |

Auth uses Supabase `/auth/v1/otp`, `/verify`, `/token?grant_type=refresh_token`, and `/logout` directly. Use a six-digit email template. The client serializes refresh requests and stores credentials in Keychain.

## Job input and result

```json
{"kind":"daily","requestID":"UUID"}
{"kind":"podcast","requestID":"UUID","question":"What happened in Swedish politics in the last 24 hours?"}
{"kind":"question","requestID":"UUID","question":"Why does that matter?","storyID":"UUID","previousAnswerIDs":["UUID"]}
```

Daily/podcast results are `Briefing`; question results are `ResearchAnswer`. A request ID is idempotent for the same owner and input; reuse with different input returns 409. Question history is read from server-owned answers, never accepted as arbitrary transcript evidence. At most 12 prior answer IDs are accepted.

States: `queued`, `running`, `completed`, `failed`, `cancelled`. iOS polls every two seconds for up to 15 minutes. Workers use two-minute leases renewed every ten seconds, at most three claims, and a 14-minute generation timeout. Cancelled or stale client responses cannot start playback.

Errors use `{error: "Readable explanation"}`. Validation returns 400; auth 401; inaccessible resources 404; onboarding/idempotency conflicts 409; oversized recordings 413; insufficient evidence 422; quotas 429. Generation failures appear on the job. The UI preserves existing content and offers retry; no fixture fallback exists.

## Domain

- `UserProfile`: userID, email, name, interests[], location, language (`en`), playbackSpeed, briefingVoiceModel, answerVoiceModel, completedOnboarding.
- Interest IDs: `technology`, `planet`, `science`, `culture`, `business`.
- Voice IDs: `eleven_v4`, `eleven_v4_turbo`; configured voice identity is server-side.
- `NewsSource`: id, name, title, url, note. URLs must come from retrieved OpenAI web-search citations. V1 does not persist a separate article evidence archive or structured publication dates.
- `Story`: id, title, category, summary, transcript, sources[], artworkID, audioResource, duration.
- `Briefing`: id, title, generatedAt, artworkID, stories[]. Daily generation requires five sourced stories; the whole job fails if a required clip cannot be prepared.
- `ResearchAnswer`: id, question, text, sources[], audioResource.

The API returns signed URLs in `audioResource`. The client downloads them and replaces that field with a local UUID filename before publishing content to views. Narration uses the exact stored transcript/answer text.

## Client boundaries and timeline

`AppModel.live()` injects one `LiveBackend` through AuthRepository, ProfileRepository, and NewsRepository. Views depend on these interfaces, not Supabase rows or provider response formats. LocalStore caches non-secret content; AudioCache stores downloaded MP3 files excluded from backup.

PlaybackController derives one ordered timeline by splitting stories at deep-dive insertion offsets. Interrupted answers retain their heard duration. Later story content shifts forward; scrubbing resolves session time to an audio file and offset. Branch markers and a legend supplement color. Natural answer completion holds for 1.4 seconds before continuing; pause, seek, skip, a new question, or sign-out cancels that transition.

The paused checkpoint includes the briefing, deep-dive history, active answer, answer offset, original story offset, and speed. It restores locally after relaunch. Cross-device playback sync and transcript-level alignment are deferred.
