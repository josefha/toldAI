# Live implementation verification

Verified locally on 2026-10-18. Frontend snapshot committed first as `f8271ff`; the subsequent implementation replaces runtime fixtures with real service adapters.

## Passed

- TypeScript strict typecheck and production Docker build on Node 22.
- Six backend test cases: real local Supabase auth/profile/jobs/storage/RLS; real email OTP verification and refresh-token rotation; citation extraction; researched-script citation enforcement; configuration failure; ElevenLabs v4 WebSocket framing and playable MP3 assembly.
- The Supabase integration case also checks request idempotency, foreign-user access denial, queue completion, cancellation, private signed audio, server-owned follow-up history, atomic quota enforcement, forbidden public RPC invocation, and account deletion including personal audio removal.
- SQL inspection: RLS enabled on all six application tables; queue/cache/quota functions are SECURITY INVOKER and not executable by anon/authenticated roles. Owner and queue queries have corresponding indexes; claims use `FOR UPDATE SKIP LOCKED`.
- iPhone 16 Pro and iPhone SE (3rd generation), iOS 18: 13 unit/state tests and 2 signed-out UI tests on each, zero failures. Includes continuous-timeline insertion/scrubbing, follow-up truncation, cancellation, automatic continuation, paused branch restoration and large text sign-in layout.
- Docker runtime `/ready` returned HTTP 200 against real local Supabase with its worker disabled. This was a database/container check, not a paid generation test.
- Production npm dependency audit: zero reported vulnerabilities at verification time.
- Runtime source scan: no demo/mock/fixture paths in `ios/Told` or `backend/src`. Test audio and test repositories are outside the application target. `git diff --check` passes.

Local test artifacts: `/tmp/told-live-final.xcresult`, `/tmp/told-live-se-final.xcresult`, `/tmp/told-backend-final2.log`, `/tmp/told-docker-final.log`. These temporary files are not committed.

## Not yet verified

OpenAI and ElevenLabs paid calls, real provider quality/latency, external SMTP delivery, hosted infrastructure, physical-device microphone/audio routes, and App Store distribution. Provider contract tests use controlled responses and a local WebSocket server; they do not establish access to your paid accounts. OTP tests verify real local Supabase codes/refresh but do not establish external email deliverability.

Use the [deployment guide](DEPLOYMENT.md) and its opt-in paid smoke check after adding credentials. No cloud resources were provisioned and nothing was pushed or deployed during this implementation.

## Implementation boundaries

The research adapter, speech adapter, storage, job worker, HTTP API, and client repositories are separate modules. Current schema/API documentation describes what is implemented; the original architecture document remains a roadmap. Tradeoffs—including complete-clip downloads, interest-group editions, public sourcing, all-or-nothing daily generation and local playback history—are listed in the deployment guide.
