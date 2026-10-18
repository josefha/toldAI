# Answer routing and timing

Daily five generation still requires sourced news. Both standalone Ask episodes and player follow-ups now choose a route using the question and the original story/previous answers:

- `context`: explain, simplify, recap or reason from existing material. No web lookup.
- `general`: stable knowledge, ideas and hypothetical examples. No forced news citations.
- `web`: fresh/changing facts, explicit searches and uncertain specialized questions. Searches broadly; the daily news domain allowlist does not restrict these answers.
- `market`: look up a timestamped market quote. The extraction must supply a positive price, currency, symbol, quote timestamp and retrieved source URL. Missing, future or older-than-seven-days quotes produce a spoken limitation instead of an invented price. Quotes are labeled last-close, delayed or latest-available, never guaranteed live.

Routing and direct-answer generation share one model call. Web/market routes add lookup and composition/extraction calls. Routing/direct answers use `OPENAI_ANSWER_MODEL`; composition uses `OPENAI_SCRIPT_MODEL`. Both fall back to `OPENAI_MODEL`, which still handles research. Market lookup uses OpenAI web search, not a separate licensed market-data API. Therefore quote availability and freshness are not guaranteed.

If a conversational search returns no usable sources, the answer states the verification limitation and can offer stable background or clarification. It does not reuse uncited current claims as verified evidence. Transport/model failures can still produce an error. General answers may have an empty source list. Daily news continues to fail closed when evidence is missing.

## Backend logs

From the project root:

```sh
docker compose logs -f --tail 200 api
```

Timing entries are JSON with `event: "timing"`. Follow a generation using its `jobID`; transcription uses the API `requestID`. Stages include:

- `job_queued`, `job` and `worker_elapsed`: lifecycle, queue wait and total worker processing time.
- `profile_load`, `story_context`: database context loading.
- `routing_and_direct_answer`, `route_selected`: model routing/answer time and selected route.
- `web_search`, `market_lookup`, `script`, `quote_extraction`, `quote_validation`: lookup, writing and quote validation.
- `speech_first_audio`: provider time to first audio chunk, **not** time to audible playback.
- `speech`, `audio_ready`: full synthesis time, actual audio seconds and bytes.
- `storage_upload`, `job_persist`, `signed_audio_urls`: delivery preparation.
- `transcription`: model duration and recording size.
- `daily_cache`, `daily_story`: cache hit/miss and per-story generation. `storyIndex` correlates daily stages.
- `model_usage`: model and token counts for cost comparison.

Measured stages emit started/completed/failed records and `durationMs`. Timestamps are UTC. Logs exclude question text, transcripts, source URLs, provider response bodies, credentials, and signed audio URLs. Operational IDs are included for correlation. Logs live in Docker's normal local log storage; no remote monitoring service was added.

## iOS logs

The Xcode console or macOS Console can filter subsystem `com.toldai.preview`, category `Timing`. It records `client_job` (queue, polling and server wait), `client_transcription` and `audio_download` (including local cache hits). These client logs require rebuilding the app. A client job is not time-to-audible-playback: recording time, user interaction and the player starting are not measured by it.

For a booted simulator:

```sh
xcrun simctl spawn booted log stream --level info --predicate 'subsystem == "com.toldai.preview" AND category == "Timing"'
```

Compare the same questions and models across repeated runs before drawing latency conclusions. Fresh web research, shared caches, output length and provider load affect results. Player follow-ups now support passage-level playback and a separate answer model, described below. Daily and standalone episodes still wait for complete clips.

## First live routing check — October 18, 2026

All four requests completed through the real authenticated API, worker, OpenAI, ElevenLabs and private audio download. These are single-run observations, not benchmarks. Model: configured `gpt-6.1-sol`; narration: v4 for standalone episodes, v4 Turbo for follow-ups.

| Route | Ready including polling/download | Routing/direct answer | Lookup | Script/extraction | Full speech | Upload |
|---|---:|---:|---:|---:|---:|---:|
| Context explanation | 16.4s | 7.9s | — | — | 4.1s | 0.5s |
| General knowledge | 22.6s | 8.4s | — | — | 11.4s | 0.3s |
| Market quote | 20.4s | 1.8s | 9.8s | 3.0s | 2.0s | 0.2s |
| Fresh web research | 46.3s | 2.2s | 15.5s | 12.4s | 13.0s | 0.7s |

The context example simplified an existing solar story without searching; general knowledge explained rainbows without citations; market lookup returned a dated NVDA quote with its source and a non-live caveat; fresh research returned a sourced episode. All four MP3 downloads parsed successfully. The context answer's first audio arrived from ElevenLabs in 232ms, although full synthesis took 4.1s. The app still waits for full audio.

Sixteen backend tests passed, including local Supabase integration, routing fallbacks, quote validation, privacy of timing logs and short clarifying answers. iOS build passed. Original raw run artifacts are local at `/tmp/told-routing-results.json` and `/tmp/told-routing-server.log`.

## Progressive follow-ups — October 18, 2026

The iOS client submits `progressiveAudio: true` for player questions and polls every 500ms. A running question job can expose an owner-authorized partial Answer with `audioParts` and `audioComplete: false`. The first part is stored in answer history before publication so another question can reference it. Completion supplies the remaining part; the client reuses the first download and updates the existing timeline segment. Older clients omit the flag and receive one complete clip. No schema migration is required: these fields live in existing JSON payloads.

Scripts are validated before synthesis. Only the audio generation/download is overlapped with listening. Short answers stay as one part; longer answers split after an initial complete thought, with a maximum of two parts. Parts use independently signed private-storage URLs. Account deletion includes their storage paths.

New timings: `answer_first_passage_ready` on the worker, `client_first_passage_ready` after the first download, and `client_answer_playing` when AVAudioPlayer starts (including the cue delay). This last measurement is a playback-start proxy, not an acoustic microphone measurement.

A real simulator context question on the Meta story ("What does scraping mean here? Explain it simply.") yielded first passage ready at **6.270s**, playback at **7.122s**, and completed job at **7.143s**, with the remaining download finishing 281ms later. The answer lasted approximately 25 seconds. This single observation is not a benchmark; fresh web research still adds lookup latency. Configured answer/script model: `gpt-6-luna`; ElevenLabs and Eryn retained.

If the first part finishes before the rest arrives, the player waits in the same deep dive. Pause prevents automatic continuation. Asking again cuts the previous segment at the heard position. Failed continuation stops waiting and offers retry/continue. Restoring an interrupted app session retains available audio as complete; it does not reconnect to an unfinished generation job.

Validation: 20 backend tests (including real local database authorization, partial publication, continuation and storage cleanup), plus 21 passing Swift unit tests including playback handoff, seeking, pause, failure and interrupting a pending passage. Real provider API and simulator playback checked separately.

## Transcription latency trial

The local configuration now uses `gpt-4o-mini-transcribe` (already the repository default). Three alternating calls per model on the same short synthetic English question returned identical text. Mini took 734/726/534ms; `gpt-transcribe` took 958/782/1673ms. These are provider request timings, excluding phone upload and answer generation; real microphone, accent and noise accuracy still needs listening tests. Raw local results: `/tmp/told-transcription-comparison.json`.

Both player and Ask voice input submit a successful transcript immediately, without a text-confirmation step. Finish & Ask ends recording; the 60-second recording limit also submits automatically in both flows. Cancel discards the request. Repeated finish taps are ignored once transcription starts. This remains push-to-ask, not automatic silence detection or continuous microphone streaming.

Official supported file transcription models: https://developers.openai.com/api/docs/guides/speech-to-text
