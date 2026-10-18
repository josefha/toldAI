# Frontend service contract · v1

Source of truth for the running mock: `ios/Told/Models/Domain.swift` and `Services/Repositories.swift`. Swift Codable types define the frontend schema before any database tables are created. Supabase tables can later implement these contracts without making screens depend on database rows.

## Boundaries

| Interface | Operations | Live replacement |
|---|---|---|
| AuthRepository | sendCode(email), verifyCode(email, code), signOut | Supabase Swift email OTP adapter; configure token email template and production SMTP |
| ProfileRepository | load(userID), save(profile) | Authenticated profile API / Supabase with owner RLS |
| NewsRepository | dailyBriefing(interests), search(query), research(request) | TypeScript API adapter with authenticated requests |
| PlaybackController | start/pause/seek/speed/skip, checkpoint, answer, restore | Keep playback client-side; replace bundled audio loader with downloaded/streamed assets |
| LocalStore | Codable demo session/profile/briefing/checkpoint | Cache remains local; real session credentials must use Keychain, not UserDefaults |

All repositories are injected into AppModel. Views do not instantiate the mock or call the network. AppModel.demo() is the current composition root. The mocks are asynchronous, cancellation-aware and can fail/offline/return empty content. They use local fixtures; source links do not represent fetched evidence.

## Domain fields

- UserProfile: userID, email, name, interests[], optional location (empty string in mock), language `en`, playbackSpeed, briefingVoiceModel, answerVoiceModel, completedOnboarding.
- Interest: stable category ID; title/artwork mapping is client presentation data.
- NewsSource: id, name, title, url, note. Live service should additionally expose publication/retrieval timestamps and evidence/access classification once backend policy is implemented.
- Story: id, title, category, summary, transcript, sources[], artworkID, audioResource, duration in seconds.
- Briefing: id, title, generatedAt, artworkID, ordered stories[], isDemo. Zero stories is a valid empty result; cached editions remain usable on request failure.
- QuestionRequest: requestID UUID (idempotency/cancellation correlation), question, optional storyID, previousTurns[]. Live API should accept server-owned conversation IDs rather than trusting client history as evidence.
- ResearchAnswer: id, question, text, sources[], audioResource, isDemo.
- PlaybackCheckpoint: full cached briefing, index, position seconds, speed. Live persistence may store IDs plus versions; the downloaded queue must remain resolvable offline.

`audioResource` is deliberately a bundle name in this prototype. Before live integration replace it with an AudioAsset descriptor (ID/version, authenticated URL or stream descriptor, duration, MIME type, optional timing metadata). Likewise resolve artworkID through a versioned manifest. Keep transport-specific URLs out of view code.

## Proposed HTTP mapping

These routes are a proposed backend contract, not implemented endpoints. Use JSON, ISO-8601 UTC timestamps, stable string IDs, and explicit seconds units. Configure JSONDecoder date strategy in the live adapter; local demo cache currently uses Foundation's native date encoding.

- GET /v1/me → UserProfile; PATCH /v1/me → validated UserProfile.
- GET /v1/briefings/today → Briefing; server selects by authenticated profile. No untrusted userID override.
- POST /v1/podcasts { question } → Briefing. This replaces the Search tab’s story-list query; the Ask tab opens the result in the shared player. A live implementation researches the topic and produces an opening chapter before returning playable audio.
- POST /v1/questions → question request; use requestID as idempotency key. Initially return ResearchAnswer asynchronously; a job/SSE adapter can later emit truthful research and audio states.
- Auth operations use Supabase directly, not a parallel password database.

Error envelope: { code, message, retryable, requestID, retryAfterSeconds? }. Distinguish unauthenticated, rate-limited, offline/network, insufficient evidence, and service failure. Do not expose provider credentials or raw internal errors. Cancel URLSession work and invalidate the local request ID so late responses cannot start audio. Server cancellation is best-effort and separate from immediately stopping client playback.

## Integration checklist

Replace mocks one interface at a time. Use one verified auth identity and ownership checks. Keep service role, OpenAI and ElevenLabs credentials on backend only. Test Eleven v4 and v4 Turbo independently; current dropdowns persist model preferences but bundled sample audio does not change voice. Real microphone capture/transcription remains a separate service implementation; the current voice flow is simulated behind the same controls used by typing.

No live Supabase configuration, SQL migration, email, paid generation, or web search is performed by this app.

## Evolving listening session

The shared PlaybackController owns the original story checkpoint and an ordered DeepDive history (answer, story ID, insertion position, heard duration, interruption status). A follow-up stops the active answer without changing the original return point. Answer completion automatically restores that point and resumes narration; Back to Story does so immediately. Collapsing the player preserves answer playback. A new session clears the previous session's branches.

AppModel owns ConversationModel so player presentation does not create a separate conversation. Input cancellation invalidates outstanding requests. Ask input uses NewsRepository.podcast(question:) and only replaces the current listening session after successful generation. Production needs stable segment IDs, parent segment/offset, persisted session history, and audio/transcript timing. Current branch history is in memory; relaunch restores the original story checkpoint paused. Mock podcast generation uses bundled topic audio, not live news or prompt-specific speech.

## Continuous timeline

`ListeningSegment` describes a playable range of a story or answer. The player derives one chronological session timeline by splitting each story at its deep-dive insertion offsets. Interrupted answers retain only their heard duration; later content shifts forward as answers are inserted. Scrubbing uses session time and resolves it to the appropriate audio resource and source offset. Segment boundaries also drive playback, including replay of inserted answers.

Natural deep-dive completion holds the answer and end marker for 1.4 seconds with a continuation label before starting the next story range. Pause, new questions, seeking, skipping, sign-out and session replacement invalidate that pending transition. Session durations exclude this silent UI transition. The native accessibility adjustable action seeks the same timeline in 15-second increments; branch markers and a legend supplement color.
