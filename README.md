# told.

An illustrated, conversational news briefing for iPhone. Five stories matched to your interests, with room to pause, ask, and continue.

SwiftUI iOS 18 app + TypeScript API and worker + Supabase Auth/Postgres/Storage. OpenAI researches public reporting and transcribes questions; ElevenLabs v4 and v4 Turbo narrate the results. The application has no mock mode or bundled sample audio. Test doubles live only in test targets.

## Run and deploy

Start with the [deployment guide](docs/backend/DEPLOYMENT.md). Configure Supabase, server credentials, and the three public iOS connection settings, then open `ios/Told.xcodeproj` in Xcode 16+.

- [iOS setup and flows](ios/README.md)
- [API contract](docs/frontend/API_CONTRACT.md)
- [Implementation and verification](docs/backend/VERIFICATION.md)
- [Brand book](docs/design/BRAND_BOOK.md) · [Approved concept](docs/design/card-direction-v2.png)
- [Native interactions](docs/design/UI_FOUNDATION.md) · [Artwork system](docs/design/ARTWORK_SYSTEM.md)
- [Longer-term architecture](BACKEND_ARCHITECTURE.md)

Email sign-in uses a real six-digit code. Voice questions record the microphone, pause narration, and insert a sourced answer into the same continuous timeline. The Ask tab creates a new episode using the same player. Daily editions are shared by interest group and cached locally after download.

The implementation is ready to configure and deploy. Paid provider calls and external email delivery still need verification with your accounts. Audio currently downloads as complete clips; streaming, location-specific sourcing, licensed premium feeds, and lock-screen transport controls are deferred. Calendar and weather are outside the product scope.
