# SwiftUI foundation and interaction plan

Implementation contract for the [approved brand book](BRAND_BOOK.md). Build the central listening flow before secondary screens or a broad component library.

## Native component decisions

| Experience | Native foundation | Custom treatment |
|---|---|---|
| Main destinations | TabView: Home, Search, You; NavigationStack per tab | Monochrome tint, persistent selected destination |
| Home collections | ScrollView and adaptive LazyVGrid | Illustrated cards, spacing, native text overlays |
| Briefing/story detail | List and NavigationLink | Clear typography, small art, source metadata |
| Play, Ask, Continue | Button and Label with SF Symbols | Capsule style with visible pressed/disabled/loading states |
| Seek | Slider | Monochrome track; VoiceOver adjustable value |
| Speed/options | Menu and Picker | Familiar choices and selected value |
| Player | Native large sheet with its own NavigationStack | Spacious artwork and branded controls; visible collapse button |
| Summary, sources, transcript | Push within player NavigationStack | Native scrolling, selectable readable text, source links |
| Question input | Inline player conversation state; TextField/TextEditor alternative | Keyboard-aware layout, explicit Send and Cancel |
| Search | Native searchable input and result list | Image cards only where browsing benefits |
| Preferences | Form, Toggle, Picker | System layout and monochrome identity |
| Permissions, sharing, external links | System dialogs, ShareLink, system browser | Preserve platform behavior |

Keep one presented player sheet; push source/transcript detail inside it instead of stacking sheets. Return restores player context. Player collapse does not stop ordinary audio. If a native sheet cannot accommodate the full flow, evaluate full-screen presentation during the spike rather than building a custom gesture container first. Exact floating-tab geometry from the concept is not a requirement.

## Screen and action contract

Home card body opens briefing detail. A distinct Play control starts/resumes that briefing and opens the player. Implement separate hit regions, never nested buttons. Tapping an interest opens its collection without modifying playback. Show the current mini-player above the tabs with safe-area spacing; its title opens the player and its pause button acts independently.

The player provides previous/next buttons, a separate within-story seek slider, speed, Sources, Summary, Transcript, and Ask. Tiny story segments are indicators, not the only way to navigate. Start without a custom horizontal story-swipe gesture; add it only if native paging proves useful and does not conflict with seeking or back navigation.

Browsing another briefing does not replace the queue. An explicit Play does. Preserve the previous session checkpoint. Refresh makes a new daily brief available without replacing one currently playing.

## Conversation state contract

| State/event | UI and audio behavior | Recovery |
|---|---|---|
| Ask | Save story ID, offset, speed and prior transport state; pause immediately | Keep the checkpoint until Continue or explicit queue change |
| Permission pending | Explain microphone request; never display “Recording” yet | Denial offers typed question and Continue |
| Recording | Show real capture state, elapsed time, Send, Cancel, typing alternative | Cancel stops capture and discards draft; story remains paused |
| Send | Stop capture; submit once; show actual Transcribing/Checking sources state | Cancel invalidates request and stops any answer audio |
| Answer ready | Play answer if the submitted turn is still active; retain transcript and sources | Pause answer or ask a follow-up |
| Answer finished | Show Follow-up and Continue; no automatic briefing resume | Continue restores saved story and position |
| Failure | Brief explanation, Retry, Continue | Retry uses retained submitted input, not a silently restarted microphone |
| Next story | Cancel conversation, stop capture/answer, advance queue intentionally | Never let late answer audio start |

Ask is tap-to-record and explicit Send, not hold-to-talk or automatic endpointing. Typed input follows the same submission flow. Do not animate a fake recording signal in fixture mode; label the simulation.

Collapsing the player, changing tabs, or leaving an active conversation cancels capture/research/answer and retains the briefing checkpoint paused. Ordinary story audio continues through navigation. Returning to the app restores a saved session paused; it never reactivates the microphone.

An audio interruption pauses playback/capture. On return, offer explicit resume; a microphone interruption discards the unfinished recording with a short message. Unplugged headphones pause. Background ordinary playback follows the configured audio session; backgrounding cancels a voice turn for v1. Preserve position if the app is terminated.

## Gesture and motion ownership

Use native sheet dismissal and ScrollView arbitration first. Avoid adding a competing vertical DragGesture to the whole player. A visible collapse control always works. Dismissal cancels an active voice turn only when dismissal commits, not when a drag starts.

The Slider owns seeking; push-navigation retains native edge-back. Scroll does not skip stories. Use stable view identities and artwork asset IDs through transitions. Matched artwork movement is optional polish after native presentation passes cancellation, scrolling, and accessibility checks.

Reduce Motion uses simple fades; no parallax or perpetual background motion. System components retain native animation timing. Custom press/state/transition values in tokens.json are tuning starting points, not blanket overrides. Haptics are brief and tied to meaningful events, not every animation frame.

## Architecture boundaries

| Layer | Owns |
|---|---|
| Theme | Semantic color assets, Dynamic Type roles, spacing and radius |
| Primitives | Button styles, card surfaces and labels; no service calls |
| Patterns | Artwork card, mini-player, transport, progress indicators; state and callbacks only |
| Features | Home, Search, You, Player presentation content |
| Presentation coordinator | Tab paths, one player presentation and its detail routes |
| Playback controller | One audio session, queue, position, transport and interruptions |
| Conversation coordinator | Capture/submission lifecycle, request identity, answer and checkpoint |
| Services | Audio, microphone, network, repositories and artwork cache |

Separate transport, conversation, and presentation state. No view owns a second audio player. Obsolete request IDs cannot update the current turn or emit audio. Artwork selection happens in the presentation model/repository, not in view rendering.

## Build sequence and acceptance

1. Render a small native theme gallery with one bundled illustration, native buttons, type and cards in both appearances. Verify composited contrast and large text.
2. Build Home → briefing detail → player with five fixture stories and local sample audio. Prove transport and persistence before a conversation simulation.
3. Add Ask → simulated submission → answer → Continue, including permission-denial and cancellation fixtures. Keep recording simulation labeled.
4. Test on a physical iPhone: interrupted drags, rapid Ask/Cancel, seeking, scrolling transcript, collapse/reopen, tab changes, midnight refresh, missing art, offline playback, long headlines and audio interruptions. Inspect animation hitches with Instruments.
5. Review VoiceOver order/focus restoration, largest Dynamic Type, narrow screen, Reduce Motion/Transparency and Increased Contrast. Controls remain reachable with the keyboard open; sources remain accessible.
6. Extract patterns from the reviewed flow, then build Search, profile, onboarding and connect live services. Custom shows and broader discovery remain later work.

Performance decisions: decode/cache artwork before transition, avoid full-screen blur layers, keep frequently updating time labels from invalidating the whole screen, and use stable assets during playback. Measure on device; simulator appearance alone cannot establish smoothness.
