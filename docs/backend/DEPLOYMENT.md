# Deploy told.

The repository contains a live iOS client and containerized API/worker. No cloud deployment has been performed and no paid provider keys are checked in. Use Node 22+ and a persistent container host; generation does not fit a short-lived serverless request handler.

## 1. Supabase

Create a Supabase project in your chosen region. From the repository root:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push --dry-run
supabase db push
```

The migration creates profiles, listening sessions, answers, durable jobs, shared content cache, usage counters, owner-only read policies, service-only queue functions, and the private `told-audio` bucket. Writes pass through the authenticated API. Never expose the service-role key to iOS.

Configure Auth → Email for passwordless codes:

- Enable email sign-in and sign-up; use six-digit OTPs, a 600-second expiry and at least 60 seconds between sends.
- Copy `supabase/templates/login.html` into both **Confirm signup** and **Magic Link** email templates. It uses `{{ .Token }}`. Configure a valid site URL even though the app verifies codes directly.
- Configure a production SMTP provider and verified sender. Supabase's default email sender is not the production delivery setup for arbitrary users.
- Review email rate limits for your expected audience and test both a new address and a returning account.

Local `supabase/config.toml` settings do not automatically configure hosted Auth templates/SMTP when running `db push`.

## 2. Server secrets

Copy `backend/.env.example` to `backend/.env` (ignored by Git), or set the equivalent variables in your hosting secret manager:

| Variable | Purpose |
|---|---|
| `SUPABASE_URL` | Project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-only database/auth/storage access |
| `OPENAI_API_KEY` | Responses web search and transcription |
| `OPENAI_MODEL` | Research and script model; default `gpt-5-mini` |
| `OPENAI_TRANSCRIBE_MODEL` | Default `gpt-4o-mini-transcribe` |
| `ELEVENLABS_API_KEY` | Text-to-dialogue generation and model/voice access |
| `ELEVENLABS_VOICE_ID` | A voice your account can use with v4 and v4 Turbo |
| `NEWS_DOMAINS` | Optional comma-separated publisher domain allowlist |

The default profile uses v4 for episodes and v4 Turbo for answers. Both use ElevenLabs' text-to-dialogue WebSocket API, outputting MP3. The server collects a complete clip and measures its actual duration before publishing. It never silently substitutes another voice model.

`DAILY_JOB_LIMIT=12` applies separately to daily and podcast requests per user per UTC day; `QUESTION_JOB_LIMIT=40` and `TRANSCRIPTION_LIMIT=60` bound the other workloads. Failed attempts consume quota. Also configure spend limits in your provider accounts. Shared daily content uses date, sorted interests, model, voice and domain configuration as its cache key.

## 3. Verify access and launch

```sh
cd backend
npm ci
npm run build
node --env-file=.env dist/preflight.js
cd ..
docker compose up --build -d
curl --fail http://localhost:8080/ready
```

Preflight checks the database, private storage, configured OpenAI models, both Eleven models and voice access. It does not generate paid content or prove production latency. A missing model fails explicitly; update configuration only after confirming the provider/account capabilities.

Alternatively build `docker build -t told-api .` and deploy that image with the same environment variables. Terminate HTTPS at your host/load balancer, route port 8080, use `/ready` for health checks, and allow at least 30 seconds for graceful shutdown. The non-root image includes the worker; keep at least one replica running. Each replica processes one generation job at a time, coordinated through database leases. `WORKER_ENABLED=false` makes an API-only replica; keep workers enabled elsewhere.

The iOS app polls durable jobs, so HTTP requests need not stay open through research and synthesis. Provider keys and raw questions are not logged. Monitor queue age, failed jobs, database/storage capacity and provider spend in your hosting/provider dashboards.

## 4. iOS

Copy `ios/Config/Local.xcconfig.example` to `ios/Config/Local.xcconfig` and fill in the API HTTPS URL, Supabase HTTPS URL and **publishable key**. Follow the syntax in that file. Build/run `ios/Told.xcodeproj`. Use your Apple signing team and bundle ID for device distribution. Public connection settings may ship in the app; provider/service-role secrets must remain on the server.

## 5. Paid release smoke check

After configuration, use a disposable test account:

1. Receive a real email code, sign in, complete onboarding and wait for five stories. Verify sources, transcript and narration agree.
2. Play, pause, scrub, change speed and collapse/reopen the player.
3. Ask a voice question; verify the microphone permission, transcription and narrated answer. Interrupt it with a follow-up. Scrub across the inserted segments and confirm the original story continues at its checkpoint.
4. Start a standalone episode from Ask using typed input, then voice. Try both voice model settings.
5. Relaunch during a deep dive; verify paused restoration. Test headphones disconnect, background playback and interruption by a call on a physical iPhone.
6. Save preferences, sign out/in, and delete the disposable account. Confirm its personal rows/audio are removed.

An optional command-line smoke check uses an access token for an already onboarded test account. It **incurs generation charges**, creates a podcast and follow-up, and verifies audio downloads. Store `SMOKE_API_URL` and `SMOKE_ACCESS_TOKEN` in an ignored private environment file; do not paste tokens into logs or Git. Set `SMOKE_RECORDING` to a real M4A recording to exercise transcription and `SMOKE_DAILY=true` to include five-story generation.

```sh
cd backend
node --env-file=.env.smoke dist/smoke.js
```

Switch profile voice preferences and repeat to exercise both providers' model paths. `.env.smoke` must remain private (use a filename ending in `.env` outside the repository, or `.env.smoke` inside it).

## Optional daily preparation

Schedule `node dist/prewarm.js` once each day in a container using the server environment. It creates idempotent per-user daily jobs for onboarded profiles; workers share the expensive generation by interest group. Choose a time before your audience's morning. The app downloads the edition when opened; no background push/download is promised. On-demand generation still works if the schedule is absent. Do not enable the schedule until provider credentials and budgets are ready.

## Local verification

```sh
supabase start -x studio,postgres-meta,edge-runtime,logflare,vector,supavisor,realtime,imgproxy
npm ci --prefix backend
npm run --prefix backend check
bash backend/test/run-local.sh
```

Local ports are 55321 (API), 55322 (database), 55324 (mail inbox). Tests use real local Supabase auth, database, RLS and storage; only paid provider responses are replaced inside test code. Running `npm test --prefix backend` alone skips the two local integration tests when their environment is absent.

## Deliberate v1 tradeoffs

- Full clips before playback; no streaming or sentence-level alignment. Five-story generation may take several minutes, especially for a new interest group.
- Daily stories use interest groups and UTC dates. Location is saved for future country/local selection. On-demand questions can request a country or city explicitly.
- Public web discovery only. No premium-news licensing, paywall access, crawling pipeline or guaranteed publisher coverage is included. Citation URL checks prevent fabricated links, not every possible factual error.
- A daily edition is published when all five clips finish; a failed clip fails the job. The existing downloaded edition remains playable. Partial text-only publishing is deferred.
- Personal playback branches persist locally; account profiles and generated content persist on the server. No cross-device timeline sync yet.
- Shared audio and generated sessions currently have no automatic retention purge. Define retention before a broad launch; remove unused storage through the Storage API, never by deleting `storage.objects` rows directly. Account deletion removes personal generated clips; shared daily clips remain shared.
- App Store signing/icon/privacy metadata and real-device audio/accessibility checks remain release tasks. This is a deployable v1 implementation, not an App Store submission already approved or a verified paid-provider deployment.

Provider references: [OpenAI web search](https://developers.openai.com/api/docs/guides/tools-web-search), [transcription](https://developers.openai.com/api/docs/guides/speech-to-text), [ElevenLabs models](https://elevenlabs.io/docs/overview/models), [v4 text-to-dialogue WebSocket](https://elevenlabs.io/docs/eleven-api/guides/how-to/websockets/realtime-tdd), [Supabase email OTP](https://supabase.com/docs/guides/auth/auth-email-passwordless).
