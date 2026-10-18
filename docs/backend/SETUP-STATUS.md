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

Email delivery and paid end-to-end generation have not been verified. Run the real sign-in and audio smoke checks in `DEPLOYMENT.md` after SMTP setup. The backend is running locally; it has not been deployed to a public host.

Secrets remain in ignored local configuration. The backend uses the project's legacy server-only service-role key, which passed validation; the newer secret key returned by the CLI failed validation. Never copy either server credential into the iOS configuration.
