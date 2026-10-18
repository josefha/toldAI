# told. for iPhone

Native SwiftUI, iOS 18+, Xcode 16+. The app uses the real backend only.

## Configure

1. Follow [backend deployment](../docs/backend/DEPLOYMENT.md).
2. Copy `ios/Config/Local.xcconfig.example` to `ios/Config/Local.xcconfig`.
3. Set the HTTPS API URL, Supabase URL, and Supabase **publishable** key. Preserve the `https:/$()/` syntax: xcconfig treats a literal double slash as a comment.
4. Open `ios/Told.xcodeproj`, select Told and an iPhone simulator, then Run.

Never put service-role, OpenAI, or ElevenLabs secrets in the app. Tokens are stored in Keychain. The signed-in profile, downloaded edition, audio, and paused timeline are cached locally; signing out clears them. Source URLs open in the system browser.

Debug builds default to email-and-password sign-in for confirmed test accounts while SMTP is pending. Use the credentials in the ignored local `backend/.env.test-account` file. This is real Supabase authentication and the same backend/session flow; passwords are not stored by the app. “Use an email code” switches back to OTP. Release builds contain only the email-code interface and exclude the password-login implementation. Keep Docker running (`docker compose up -d`) when the simulator uses `localhost:8080`.

For a device/archive, choose your signing team and a unique bundle identifier (the checked-in development identifier is `com.toldai.preview`). Configure the public connection settings for Release as well. App Store icon, privacy disclosures, distribution signing, and store metadata remain account/release setup tasks.

## Flows

- Real email OTP → interests → daily five.
- Ask records up to 60 seconds, transcribes, researches, and inserts a narrated answer. The adjacent message button opens typed input.
- Follow-up questions cut the active answer at the current position and insert another deep dive. Scrubbing uses one timeline; completed answers hold briefly before narration continues.
- Ask tab starts a sourced episode from a typed or spoken question.
- Profile saves interests, optional location, playback speed, and separate v4/v4 Turbo preferences for briefings and answers. English is the first supported language. Location is saved but does not yet filter the shared daily edition.
- Account deletion removes authentication and personal database records, plus personal generated audio. Shared daily audio is not owned by one account.

## Build and test

From the repository root:

```sh
xcodebuild -project ios/Told.xcodeproj -scheme Told \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/told-derived test CODE_SIGNING_ALLOWED=NO
```

Unit tests inject test repositories and audio from the **test bundle**. UI tests cover signed-out layouts without bypassing authentication. Paid authenticated journeys are covered by the deployment smoke checklist after credentials are configured.

`ruby ios/scripts/generate_project.rb` regenerates the checked-in project when adding files (requires the `xcodeproj` Ruby gem). Keep project changes in that script. `--dark` and `--large-type` are layout-check launch arguments; neither changes service behavior.

## Code map

- `Models/Domain.swift`: transport-independent Codable models and timeline segments.
- `Services/Repositories.swift`: injected auth/news/profile interfaces and local cache.
- `Services/LiveBackend.swift`: Supabase OTP/refresh, Keychain, authenticated job API, private audio download.
- `Services/MicrophoneRecorder.swift`: native permission, AAC recording and cleanup.
- `Services/PlaybackController.swift`: queue, continuous timeline, branches, seek, speed, checkpoints and audio interruptions.
- `App/AppModel.swift`: composition, profile/feed coordination and question lifecycle.
- `Features/`: sign-in, onboarding, Home, player, Ask and profile.

See [verification and remaining device checks](../docs/backend/VERIFICATION.md).
