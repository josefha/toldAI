# Podcast narration trial

Daily stories now use a dedicated editorial prompt in `backend/src/editorial.ts`. Each opens with a conversational topic introduction, explains the development and its relevance, selects two or three essential facts, and ends with a grounded takeaway. Five stories target roughly ten minutes total: 260–290 words each, with shorter scripts when the evidence is thin. This is a writing target, not an enforced audio-duration guarantee. Follow-ups remain direct answers and can supply more depth.

Stories are independently playable and reorderable, so openings must not assume which story came before. Queue-specific transitions and a separate show intro/outro are not implemented. Never invent market moves, reactions or stakes to make a hook. Preserve uncertainty and attribution. Existing saved episodes retain their original audio.

`OPENAI_SCRIPT_MODEL` optionally selects the model for the script stage. Research, routing/direct answers and quote extraction continue to use `OPENAI_MODEL`. With the setting omitted, behavior falls back to the main model. Cache version 2 includes the script model and the existing voice ID, avoiding reuse of old-style cached clips for new generation.

Local trial configuration on 2026-10-18: GPT-5.4 mini for scripts, current GPT-6.1 sol for research/routing, Sarah (`EXAVITQu4vr4xnSDxMaL`) for narration. Existing profile settings still decide between Eleven v4 and v4 Turbo. Comparison samples use v4 Turbo. No profile or saved episode is overwritten.

Two existing story transcripts were reused as evidence, without a new web search, to isolate writing latency. Initial matched-prompt calls took 13.58 and 14.62 seconds on GPT-6.1 sol, versus 2.20 and 2.18 seconds on GPT-5.4 mini. These are two observations, not a benchmark or end-to-end generation time. The opening instruction was then strengthened and two final Sarah samples generated. The reused evidence is thin, so these samples are shorter than the two-minute target. Fresh research should gather enough useful context; do not pad scripts to satisfy a clock.

Local listening artifacts: `/tmp/told-podcast-comparison/story-1-sarah.mp3`, `story-2-sarah.mp3`, `results.json` (initial model comparison), and `final-results.json` (final scripts and audio timings). Temporary artifacts are not committed. Official model capabilities: https://developers.openai.com/api/docs/models/gpt-5.4-mini

Validation: TypeScript check; 16 backend tests including local database integration, citation enforcement, and separate research/script model selection; real provider script and MP3 generation. Voice preference and performance remain listening-review decisions.
