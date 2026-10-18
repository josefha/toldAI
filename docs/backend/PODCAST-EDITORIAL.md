# Podcast narration trial

Daily stories now use a dedicated editorial prompt in `backend/src/editorial.ts`. Each opens with a conversational topic introduction, explains the development and its relevance, selects two or three essential facts, and ends with a grounded takeaway. Five stories target roughly ten minutes total: 260–290 words each, with shorter scripts when the evidence is thin. This is a writing target, not an enforced audio-duration guarantee. Follow-ups remain direct answers and can supply more depth.

Stories are independently playable and reorderable, so openings must not assume which story came before. Queue-specific transitions and a separate show intro/outro are not implemented. Never invent market moves, reactions or stakes to make a hook. Preserve uncertainty and attribution. Existing saved episodes retain their original audio.

`OPENAI_SCRIPT_MODEL` optionally selects the model for the script stage. Research, routing/direct answers and quote extraction continue to use `OPENAI_MODEL`. With the setting omitted, behavior falls back to the main model. Cache version 2 includes the script model and the existing voice ID, avoiding reuse of old-style cached clips for new generation.

Local trial configuration on 2026-10-18: GPT-5.4 mini for scripts, current GPT-6.1 sol for research/routing, Sarah (`EXAVITQu4vr4xnSDxMaL`) for narration. Existing profile settings still decide between Eleven v4 and v4 Turbo. Comparison samples use v4 Turbo. No profile or saved episode is overwritten.

Two existing story transcripts were reused as evidence, without a new web search, to isolate writing latency. Initial matched-prompt calls took 13.58 and 14.62 seconds on GPT-6.1 sol, versus 2.20 and 2.18 seconds on GPT-5.4 mini. These are two observations, not a benchmark or end-to-end generation time. The opening instruction was then strengthened and two final Sarah samples generated. The reused evidence is thin, so these samples are shorter than the two-minute target. Fresh research should gather enough useful context; do not pad scripts to satisfy a clock.

Local listening artifacts: `/tmp/told-podcast-comparison/story-1-sarah.mp3`, `story-2-sarah.mp3`, `results.json` (initial model comparison), and `final-results.json` (final scripts and audio timings). Temporary artifacts are not committed. Official model capabilities: https://developers.openai.com/api/docs/models/gpt-5.4-mini

Validation: TypeScript check; 16 backend tests including local database integration, citation enforcement, and separate research/script model selection; real provider script and MP3 generation. Voice preference and performance remain listening-review decisions.

## Expressive delivery (2026-10-18)

Eryn (`dMyQqiVXTU80dDl2eNK8`) is the configured local voice. Daily scripts now aim at 240–270 words to leave more room for an unhurried delivery; the ten-minute total is approximate. All generated prose, including direct answers, uses the same relaxed spoken-writing guidance.

Before every story or answer is rendered, `Providers.expressiveSpeech` asks the script model to choose one restrained tone per paragraph. The model can return only an allowlisted tone array; it cannot rewrite the narration. `delivery.ts` adds tone and slow-delivery cues plus short pauses between paragraphs. These are ElevenLabs interpretation cues, not exact pause lengths or a guaranteed words-per-minute control. Source text brackets are converted to parentheses so they cannot inject arbitrary audio directions. The saved/displayed transcript remains the original clean script.

The optional direction request has an eight-second deadline. Failure, invalid output or a mismatched paragraph count falls back to calm delivery; cancellation of the generation still propagates. Timing events include `delivery_direction`, `delivery_fallback` and `delivery_ready`, without transcript content. Daily cache version 3 includes the delivery version.

This is an expressive delivery layer in told's existing OpenAI-agent → ElevenLabs v4/v4 Turbo pipeline. It is **not** a hosted ElevenLabs Agent or its Expressive Mode switch. Hosted Agents also manage conversational state/turn taking and would require a separate integration decision. We continue to use press-to-ask, the existing research and citation rules, and recorded clips in the shared timeline. We do not currently infer emotions from the user's raw voice.

Documentation: https://elevenlabs.io/docs/help-center/product/core-capabilities/text-to-speech/how-do-audio-tags-work-with-eleven-v3-and-v4 and https://elevenlabs.io/docs/eleven-agents/customization/voice/expressive-mode

## Player cues

The iOS player synthesizes its own quiet felt-bell tones locally: two notes over 0.65 seconds before a new story, or one note over 0.38 seconds before an answer, followed by 0.3 seconds before narration. Automatic changes between stories first wait one second. Returning from a deep dive to the same story retains the 1.4-second breathing pause without a new-story cue. Pause/resume and timeline scrubbing do not replay cues. Manual story skips use the cue without the inter-story wait.

Cues play only after local narration audio has loaded. Pausing, asking, skipping, clearing the session, audio interruption or headphone removal cancels pending cue playback. Cue failure falls through to speech. Voice & Playback includes a local, immediately saved Transition sounds toggle; turning it off silences cues while retaining breathing pauses. Cues are outside the story timeline and do not change narration positions or deep-dive checkpoints.
