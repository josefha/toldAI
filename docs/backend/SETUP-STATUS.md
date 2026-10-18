# Hosted setup — 2026-10-18

- Linked Supabase project `vpahalndclyfzxiukgch`.
- Applied and verified migration `20261018112401_initial_backend`.
- Hosted public-schema lint passed.
- Provider preflight passed for the configured OpenAI models, ElevenLabs v4/v4 Turbo, voice, database, and private audio bucket.
- Local Docker API/worker started; `http://localhost:8080/ready` returned ready.
- Ignored iOS configuration points to this hosted Supabase project and the local API for simulator use. Public-key access was verified. Physical-device testing still needs a reachable HTTPS backend.
- Corrected transcription requests to send `languages[]` with `gpt-transcribe`; older models retain `language`. Backend build and five unit/provider tests passed; two local integration tests were skipped in this run.

## Remaining setup

Supabase rejected the custom email templates because this free project uses its default email provider. The attempted Auth update did not complete. Configure custom SMTP, then apply the six-digit code settings (600-second expiry) and the confirmation/magic-link templates in `supabase/templates/login.html`. Preserve unrelated hosted Auth settings when applying configuration; the local config includes development defaults.

Email delivery has not been verified. Run the real email sign-in and physical-device checks in `DEPLOYMENT.md` after SMTP setup. The backend is running locally; it has not been deployed to a public host.

## Paid live flow verified

Created a disposable confirmed account through the Supabase admin API, authenticated it, and saved onboarding through the application API. No email was sent and production email verification behavior was not changed.

- Real M4A transcription of a synthesized spoken question passed through the authenticated endpoint.
- OpenAI researched a sourced solar-energy podcast; ElevenLabs v4 narrated it. Generation: 69.1 seconds; audio: 85.3 seconds.
- First follow-up used ElevenLabs v4 Turbo. Generation: 35.4 seconds; audio: 53.1 seconds.
- Five-story daily edition completed in 226 seconds; all five clips downloaded and parsed successfully.
- A second follow-up supplied the first answer ID as history and correctly explained the solar-export uncertainty with a hypothetical example. Generation: 27.1 seconds; audio: 47.1 seconds.
- All eight completed clips were downloaded from signed storage URLs and checked for valid MP3 duration. Unauthenticated API access and public bucket access were rejected.
- The initial daily attempt failed closed on a source URL mismatch. Constrained structured output to retrieved source URLs and reran successfully. Also fixed duplicate citation IDs caused by repeated research citations; all post-fix daily and follow-up source IDs were unique.
- Expanded the reusable smoke test with conversation-history coverage, MP3 parsing, source-ID checks, and elapsed time reporting.

These are backend integration results, not a physical-iPhone microphone/playback or editorial accuracy review. The 27–35 second answer latency still needs improvement for a conversational experience. Test account ID: `83c1d61d-c191-4014-b832-dc9bd8c09cbd`; its local access token is in ignored `backend/.env.smoke`. Audio and the detailed run report are in `/tmp/told-live-smoke` on this machine.

Secrets remain in ignored local configuration. The backend uses the project's legacy server-only service-role key, which passed validation; the newer secret key returned by the CLI failed validation. Never copy either server credential into the iOS configuration.
