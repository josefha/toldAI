# told. — SwiftUI frontend

Native iPhone preview, iOS 18+, Xcode 16+. Open `Told.xcodeproj`, select the **Told** scheme and an iPhone simulator, then Run. No API keys, package downloads, Supabase project, or backend are required.

## Try it

1. Enter any valid-shaped email address. No email is sent. Use demo code **123456**.
2. Choose interests and optionally enter your name.
3. Play the daily briefing. Audio is bundled spoken sample content, not ElevenLabs.
4. Try pause, seeking, speed, next/previous, Sources, Summary, Transcript, and collapse/reopen.
5. Press Ask to listen, or the message icon to type. Send inserts a deep dive; a follow-up interrupts that answer. Playback automatically returns to the story afterward. The primary Ask button is simulated and does not access the microphone.
6. Open Ask and choose a prompt, type, or use voice input to start a podcast in the shared player. Results and voice transcription remain fixtures.
7. In You, edit profile/interests/location, save voice-model preferences, or, when launched with `--developer-tools`, open Developer Tools (offline, next-request failure, empty feed, denied microphone).
8. Sign Out clears local demo identity, profile, briefing and playback checkpoint. OTP is one-time within a running demo instance; expired/invalid paths are tested.

The edition, profile and paused listening position survive relaunch. Artwork stays pinned to the cached edition. All source links are example reference destinations, not citations for current news.

## Build and tests

```sh
xcodebuild -project ios/Told.xcodeproj -scheme Told \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/told-derived build CODE_SIGNING_ALLOWED=NO

xcodebuild -project ios/Told.xcodeproj -scheme Told \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/told-derived test CODE_SIGNING_ALLOWED=NO
```

Commands above run from the repository root. On a physical device choose your own signing team and unique bundle identifier. The default bundle ID is `com.toldai.preview`; this is not an App Store release configuration.

Launch arguments: `--reset-demo` clears this app's demo data; `--ui-testing` shortens mock delays and exposes Developer Tools. `--developer-tools` exposes those controls without changing timing. UI tests use both and include simulator screenshot attachments.

The checked-in Xcode project is ready to open. `ruby ios/scripts/generate_project.rb` regenerates it when adding files (requires the `xcodeproj` Ruby gem, already available on the development machine). Regeneration replaces project metadata, so keep custom project changes in that script.

## Code map

- `Models/Domain.swift`: Codable data contracts.
- `Services/Repositories.swift`: auth/news/profile interfaces, cancellation-aware async mocks and isolated demo persistence.
- `Services/Fixtures.swift`: five fixture stories and example reference links.
- `Services/PlaybackController.swift`: one AVAudioPlayer owner, queue, speed, seek, checkpoints and interruption handling.
- `App/AppModel.swift`: composition root, session/feed coordination and question lifecycle.
- `Design/Components.swift`: semantic colors, wordmark, illustrated cards, standard button styles.
- `Features/`: native sign-in, onboarding, Home/details, player/conversation, Ask/podcast and profile screens.

See `docs/frontend/API_CONTRACT.md` for backend replacement boundaries. Real credentials must use Keychain; this preview stores only fake sessions and local demo data in UserDefaults. The app does not make auth, research or speech API calls. Opening an explicit source link uses the system browser.

## Current release boundaries

One illustration per initial art family is bundled; additional rotating variants can be added through the artwork manifest later. Science/business/culture currently reuse the initial family. The production app icon and vector logo master remain future brand deliverables. Custom shows, live news, real OTP delivery, microphone/transcription, ElevenLabs output, streaming, lock-screen remote controls and production account deletion are outside this mocked frontend slice.

Simulator verification does not replace real-device audio-route, background playback, VoiceOver, energy and performance checks. See `docs/frontend/VERIFICATION.md` for actual results.

The middle Ask tab starts a question-led podcast in the shared player. Example prompts, voice input, and typed questions use the same mock podcast boundary. Source discovery and transcription remain mocked.
