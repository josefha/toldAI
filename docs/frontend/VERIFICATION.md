# Historical frontend verification

These results describe the earlier fixture-backed frontend. See [live implementation verification](../backend/VERIFICATION.md) for the current application and backend.

2026-10-18 · Xcode 16.0 · iOS 18.0 simulators.

## Results

- Copy cleanup: all 8 service/state tests and 5 UI journeys passed after removing development wording and regenerating narration (`/tmp/told-copy-tests.xcresult`). Previously captured screenshots below predate this copy cleanup.

- iPhone 16 Pro: 8 XCTest service/state tests and 5 XCUITest journeys passed, 0 failures (`/tmp/told-tests-6.xcresult`).
- iPhone SE (3rd generation): 2 targeted XCUITest journeys passed, 0 failures, after final accessibility layout and background-audio configuration changes (`/tmp/told-compact2.xcresult`).
- Simulator build succeeds without signing or external dependencies. Final built Info.plist contains `UIBackgroundModes = audio`.
- `git diff --check` passes. New frontend documentation links and asset catalogs checked.

The earlier compact command selected zero tests because its filter omitted the class name; it is not counted as verification. The corrected run executed both selected tests. Earlier UI failures from field/confirmation/toggle selectors were repaired and rerun. Large-text screenshot review prompted a real layout change: card text moves below artwork, and the player sheet explicitly inherits Dynamic Type.

## Automated coverage

Service/state tests: wrong and reused OTP, expired OTP, offline recovery, profile ownership and persistence, Codable round-trip, canceled request rejecting a late answer, answer-to-story checkpoint restoration, denied-microphone fallback, failed question retry, paused playback restoration and seek clamping, refresh preserving the active queue, and sign-out clearing local demo state.

UI journeys:

1. Email → code → interests → Home → Play → typed question → answer → Continue → collapse → profile.
2. Search → research result → profile editor → save.
3. Briefing detail → story → sources → player → simulated recording → answer → Continue → sign-out confirmation → email screen.
4. Enable offline/denied microphone → play downloaded audio → typed fallback → failed request → Continue.
5. Relaunch with accessibility5 text → Home → player → Ask → Continue. Repeated with the core listening journey on compact iPhone SE.

## Visual review

Inspected actual simulator screenshots, not the generated concept: light Home, dark Home/player, mini-player, and compact standard/large-text layouts. Native tab/navigation bars and sheets remain intact. Artwork and wordmark render in both appearances. In large text, cards expand on opaque surfaces and player links stack; scrolling keeps actions reachable.

Representative screenshots:

- [Dark Home](screenshots/home-dark.png)
- [Dark player](screenshots/player-dark.png)
- [Light Home](screenshots/home.png)
- [Mini-player](screenshots/mini-player.png)
- [Sources](screenshots/sources-dark.png)
- [Answer](screenshots/answer-dark.png)
- [Offline fallback](screenshots/offline-question.png)
- [Compact player](screenshots/compact-player.png)
- [Compact large-text Home](screenshots/compact-home-accessibility.png)
- [Compact large-text player](screenshots/compact-player-accessibility.png)

## Limits and follow-up

No live Supabase/OTP mail, web research, transcription, or ElevenLabs calls were made. Recording is simulated. Development labels are intentionally absent from the product UI; the mock behavior remains documented here and in the run guide. Voice settings persist configuration for v4/v4 Turbo; bundled local audio does not change model. Source links are example destinations, not evidence for current reporting. One asset per initial artwork family is bundled; rotating variants are future additions.

Physical-device tests for microphone integration, headphones, phone-call interruptions, background audio, lock-screen controls, VoiceOver navigation/focus, haptics, and Instruments performance remain pending. No claim of measured frame pacing or complete accessibility certification is made. Real microphone and streaming adapters, production auth, app icon, signing, and release account-management flows remain integration/release work.

Computer Use was unavailable in this session, so validation used Xcode's native test runner and simulator screenshots rather than manual desktop interaction.

## Continuous listening and Ask tab

The revised player and Ask tab passed 10 service/state tests and 5 UI journeys on iPhone 16 Pro (`/tmp/told-flow-final.xcresult`). Coverage includes interrupted deep dives retaining the original checkpoint, automatic resumption on answer completion, independent podcast sessions, Ask-to-shared-player navigation, direct voice entry, separate typing, offline fallback, and large text. The initial duplicate Ask-control accessibility identifier was fixed and the full suite rerun successfully.

The following final refinements are checked separately on iPhone SE: shorter answer previews with full text in Transcript, and advancing rather than restarting when a deep dive returns to an already-completed story. The service layer remains mocked: arbitrary prompts select bundled topic content, voice input supplies a fixed question, and answer speech is a fixed clip. Branch history is retained while the app runs; relaunch restores the original story paused.

Final small-screen verification: 10 service/state tests plus the player/sign-out and largest-text journeys passed on iPhone SE (`/tmp/told-flow-compact.xcresult`). The typed Ask journey exposed a keyboard reachability issue; after adding the keyboard Done action, that journey passed on rerun (`/tmp/told-ask-keyboard.xcresult`). Reviewed Ask, player, and deep-dive screenshots.

## Unified session timeline

12 service/state tests and 5 UI journeys passed on iPhone 16 Pro (`/tmp/told-timeline-tests.xcresult`). After final accessibility, title spacing, and endpoint refinements, all 12 service/state tests and the player/sign-out and largest-text UI journeys passed on iPhone SE (`/tmp/told-timeline-final.xcresult`). Tests cover duration growth, story splitting, seeking into and out of answers, playback across inserted boundaries, elapsed-time continuity after automatic return, and canceling the delayed return. Reviewed the deep-dive timeline screenshot; purple ranges and boundary markers remain in the same track as the story. Branch history still resets on process relaunch as documented in the API contract.
