# SwiftUI v1 implementation

## Scope

Build a runnable iOS 18 app in `ios/Told.xcodeproj`, using the approved illustrated/monochrome direction and native navigation. Backend, OTP delivery, news research, and ElevenLabs are mocked. Audio playback uses bundled spoken fixtures so seeking, pause, speed, and resume can be exercised without API credentials. Recording simulation is explicitly labeled. No production auth or database changes.

## Work sequence

1. Define Codable domain models, repository protocols, fixture data, and persisted local demo state. Document request/response boundaries for the TypeScript API.
2. Generate standalone Daily brief, Technology, and Planet artwork; integrate approved transparent wordmark, semantic colors, and adaptive card components.
3. Build native shell, email/code flow, interests onboarding, Home, briefing detail, topic collections, story summary/transcript/source navigation.
4. Add one shared audio controller, mini/full player, seeking, speed, queue navigation, durable checkpoints, and Ask/Send/Answer/Follow-up/Continue with cancellation.
5. Add Search and explicit mocked research with sourced answers, saved interests/location/settings, sign-out, and demo controls for offline/failure/permission states.
6. Build and run in simulator. Test service/state invariants and major journeys with XCTest/XCUITest, inspect actual screenshots in dark/light and compact/large text configurations. Fix findings.
7. Document launch instructions, fixture code, service replacement points, verified flows, and remaining device/live-integration checks.

## Completion criteria

All visible actions route or work; loading/empty/error/retry paths are recoverable; sign-out clears private demo state; no duplicated playback; cancel rejects late answers; Continue restores the story; refreshing does not replace active queue. Build and tests pass. Screenshot review is separate from physical-device audio/performance review, which cannot be claimed from simulator tests.
