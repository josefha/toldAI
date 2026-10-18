# Answer routing and timing

Daily five generation still requires sourced news. Both standalone Ask episodes and player follow-ups now choose a route using the question and the original story/previous answers:

- `context`: explain, simplify, recap or reason from existing material. No web lookup.
- `general`: stable knowledge, ideas and hypothetical examples. No forced news citations.
- `web`: fresh/changing facts, explicit searches and uncertain specialized questions. Searches broadly; the daily news domain allowlist does not restrict these answers.
- `market`: look up a timestamped market quote. The extraction must supply a positive price, currency, symbol, quote timestamp and retrieved source URL. Missing, future or older-than-seven-days quotes produce a spoken limitation instead of an invented price. Quotes are labeled last-close, delayed or latest-available, never guaranteed live.

Routing and direct-answer generation share one model call. Web/market routes add lookup and composition/extraction calls. This uses the configured OpenAI model; it does not silently change model quality settings. Market lookup uses OpenAI web search, not a separate licensed market-data API. Therefore quote availability and freshness are not guaranteed.

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

Compare the same questions and models across repeated runs before drawing latency conclusions. Fresh web research, shared caches, output length and provider load affect results. Full clips are still generated before playback; streaming and a separate low-latency answer model remain future optimizations.

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
