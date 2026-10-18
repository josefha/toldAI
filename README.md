# told.

An illustrated, conversational news briefing for iPhone. Five stories matched to your interests, with room to pause, ask, and continue.

## Frontend v1

Open [ios/Told.xcodeproj](ios/Told.xcodeproj) in Xcode 16+, select **Told** and an iOS 18 iPhone simulator, and Run. The entire frontend works with local mock services and bundled spoken audio. No backend configuration or API keys are needed.

**Demo sign-in:** any valid-shaped email address, code **123456**. No email is sent.

[Run instructions and feature guide](ios/README.md) · [Implementation plan](docs/frontend/IMPLEMENTATION_PLAN.md) · [API/data contract](docs/frontend/API_CONTRACT.md) · [Verification](docs/frontend/VERIFICATION.md)

## Design and architecture

- [Brand book](docs/design/BRAND_BOOK.md) and [approved concept](docs/design/card-direction-v2.png)
- [Native UI interactions](docs/design/UI_FOUNDATION.md)
- [Artwork system](docs/design/ARTWORK_SYSTEM.md)
- [Backend architecture](BACKEND_ARCHITECTURE.md)

The preview labels sample news and prepared answers. Live email authentication, sourcing, transcription, and Eleven v4/v4 Turbo synthesis are the next integration layer, behind the injected service contracts. Custom shows, calendar, weather, and email inbox integrations are not part of this v1 frontend.
