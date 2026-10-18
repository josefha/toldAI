# toldAI UI build plan

Build a mobile-first conversational audio app with a visual structure and core interactions closely informed by Huxe: a personalized home screen, topic discovery, custom shows, and an audio player that lets the listener join the conversation. Use the approved illustrated-card concept and native platform behavior. Huxe is a reference for atmosphere and hierarchy, not a pixel-level requirement.

Updated MVP scope, 2026-10-18: English text and voice input/output; saved interests, language, and optional location; daily refreshed briefings. Five stories matched to the listener's interests, short summaries with source links, press-to-ask conversations, and on-demand research about a specific topic. The broader screen inventory below is a roadmap. Prioritize Home, the player, interests, source links, and questions before custom shows and the full discovery experience. See [Backend architecture](BACKEND_ARCHITECTURE.md) for module boundaries and implementation slices.

Build the visual prototype alongside a text-first sourcing prototype so we can assess story quality early. Add speech once the evidence and selection are reviewable.

Platform decision, 2026-10-18: native iPhone app in SwiftUI with a TypeScript backend, Supabase, OpenAI, and ElevenLabs. Use the installed Apple design skill for design reviews. Begin in the iOS simulator with fixture data, then connect live services. Proposed minimum deployment target: iOS 18, compatible with the currently installed Xcode 16 toolchain; confirm device compatibility before implementation.

## Visual and interaction foundation

Approved direction: [illustrated concept](docs/design/card-direction-v2.png), monochrome UI, spacious image cards, native tabs and controls. The brand book and interaction contract below supersede conflicting older roadmap details. Build the central native listening flow before a component library or secondary screens. Custom shows and Library are later scope, not required for the first prototype. Category artwork rotates per edition and stays pinned during playback; see [artwork system](docs/design/ARTWORK_SYSTEM.md).

Before production components, follow the [brand book](docs/design/BRAND_BOOK.md) and [SwiftUI foundation plan](docs/design/UI_FOUNDATION.md). Review the visual direction, then build one native Home/player interaction spike and extract the component patterns that prove reliable. Tokens, playback state, and presentation state remain separate.

## Reference and design decisions

Use the [Huxe reference pack](huxe_ui_reverse_engineering.md) as the screen inventory. Its six App Store screenshots form the initial visual baseline. Treat the May 2026 screenshots as additional behavior references; where versions differ, choose one approach explicitly instead of combining incompatible layouts.

Review these videos before finalizing the player and onboarding behavior:

- [Huxe launch video](https://vimeo.com/1123634465).
- [Huxe hands-on walkthrough in Japanese](https://www.youtube.com/watch?v=DGMD5lbJ588), with the [creator's chapter guide](https://yokotashurin.com/etc/huxe.html).

For each important screen, record the reference URL, video timestamp if applicable, visible layout, interaction observed, and any proposed toldAI changes. A screenshot establishes appearance; transitions and edge cases we cannot observe must be treated as our own product decisions.

### What should feel similar

| Area | Design target |
|---|---|
| Home | Personalized greeting, prominent daily brief, modular recommendations, and a keep-listening section |
| Discover | Search, category filters, and a browsable collection of stations or shows |
| Show detail | Artwork, title, description, episodes, edit, and generate actions |
| Player | Large changing story cards, clear transport controls, and a prominent Ask action |
| Conversation | Clear listening and answering feedback while keeping the current story visible |
| Create | A focused prompt composer with research and supplied-source options |
| Navigation | Persistent main navigation and a mini player that preserves listening context |

Exact colors, type sizes, spacing, and corner radii should be extracted during the reference pass and stored as design tokens. Do not guess these independently on each screen. Source attribution and explicit resume behavior are toldAI requirements even when the reference does not establish them.

## Scope and delivery stages

| Stage | Included | Completion gate |
|---|---|---|
| A — UI prototype | Onboarding, Home, Discover, show detail, Create, Library, settings, mini player, full player, and simulated voice turns | A user can complete the main journeys without dead ends |
| B — Working audio | Recorded sample audio, real playback position, seeking, speed, and navigation persistence | UI and audible playback stay synchronized |
| C — Live news and voice | Story ingestion, generated briefings, spoken questions, answers, and reliable resume | A user can listen, interrupt, ask, and continue using real services |
| D — Extended Huxe functions | Broader research shows, more source types, country/local-news controls, multilingual input/output, live stations, and additional voices | Each extension has its own scope and working integration |

The first Stage A milestone contains Home, briefing detail, player, sources, and simulated conversation; custom-show UI follows after the native listening flow is validated. Simulated behavior is labeled in the prototype. Stage C includes news briefings, follow-up web research, and standalone topic queries. Persistent research shows, multilingual support, and geographic news filtering belong to Stage D. Calendar, email, and weather integrations are outside the product scope.

## Primary journeys

1. **First visit:** Welcome → email → verify emailed code → choose interests → save profile with optional location and English language → ready → Home → play daily brief.
2. **Returning listener:** Home → keep listening → restored story and playback position.
3. **Ask while listening:** Player → Ask → record and submit a question → hear an answer → ask follow-ups or press Continue → resume the same story.
4. **Find a show:** Discover → search or category → show detail → play an episode or follow the show.
5. **Create a show:** Create → describe a topic → optionally add sources → save → generation status → show detail → play.
6. **Research a topic:** Enter a specific question → research progress → answer with sources → optional audio → follow-up questions.
7. **Manage preferences:** Library or profile → interests, optional location, language (English in v1), sources, and playback settings → save → return.

## Screen requirements

| Screen | Required content and actions | Required alternate states |
|---|---|---|
| Welcome | Product explanation and start action | Returning user can bypass onboarding |
| Interests | Selectable topic chips, add a topic, continue | No selection, selected topics, validation |
| Sources | Show story source links in MVP; a searchable publisher picker is a later proposed enhancement, not verified Huxe onboarding | Unavailable source, access limitation |
| Ready | Brief preparation feedback and enter Home | Preparing, ready, retry |
| Home | Greeting, date, daily five-story brief, last refreshed time, keep listening | First visit, ready, refreshing, previous cached brief, unavailable brief |
| Discover | Search, category chips, show cards | Default, filtered, no results, loading |
| Show detail | Artwork, description, follow, episode list, play | Followed, no episodes, generating, failed generation; edit for owned shows |
| Create and edit | Topic prompt, research/source mode, source URLs, save | Empty prompt, invalid source, saving, saved, failure |
| Topic research | Text query or press-to-speak, progress, answer, sources, follow-up | Searching, answering, insufficient evidence, cancel, retry |
| Full player | Current story, sources, chapters, transcript, transport, Ask | Idle, playing, paused, buffering, listening, thinking, answering, error, finished |
| Library | Followed shows, custom shows, recent briefings | Empty library, populated library |
| Preferences | Saved interests, optional location, English language, sources, speed, voice presentation | Saved, unsaved changes, validation; unavailable voices disabled |

Persist the profile and listening progress across sessions. Use a verified Supabase user identity from passwordless email OTP for personalized live retrieval. No Apple/Google login or passwords in v1. Do not request calendar, email, weather, or device-location access. Location is optional manual country/city input, stored for future geographic features. Language is English in v1; additional languages are not selectable yet.

## Small implementation tasks

Each task should produce one reviewable result. Keep visual changes small enough to compare with a specific reference and behavioral changes small enough to demonstrate with a short journey.

| Task | Build | Acceptance criteria | Depends on |
|---|---|---|---|
| 01 | Reference inventory | Choose baseline screenshots; annotate Home, Discover, show detail, Create, and player; identify observed versus proposed interactions | — |
| 02 | Visual foundation | Define typography, palette, spacing, surfaces, radii, icons, and phone frame; review a component sample against references | 01 |
| 03 | App shell | Main destinations, back navigation, safe-area spacing, and persistent mini-player slot work without content overlap | 02 |
| 04 | Shared components | Buttons, topic chips, cards, episode rows, source labels, sheets, inputs, and loading/empty/error components exist in a preview | 02 |
| 05 | Fixture content and state | Five coherent stories, multiple shows and episodes, source links, transcripts, and user preferences are available to all screens | 03 |
| 06 | Home | Daily brief, keep listening, and recommendations match the agreed hierarchy; every visible action has a destination | 04, 05 |
| 07 | Player layout | Story card, chapter navigation, transcript/source views, and transport fit the phone viewport | 04, 05 |
| 08 | Player behavior | Simulated play, pause, seek, next, previous, speed, completion, and mini-player expansion share one session state | 06, 07 |
| 09 | Join conversation | Scripted question and answer demonstrate listening → thinking → answering → resume; cancel and failure preserve position | 08 |
| 10 | Discover | Search and category filters change results; cards open the correct show | 04, 05 |
| 11 | Show detail and follow | Episodes open the player; following changes Library; owned shows expose edit and generate actions | 08, 10 |
| 12 | Create and edit a show | Validate prompt/source fields; save a local show; simulate generation and retry; edits update the existing show | 11 |
| 13 | Onboarding | New users can choose interests and reach Home; returning users skip setup | 06 |
| 14 | Library and preferences | Followed/created shows and recent briefs appear; preferences persist through reload | 11, 12, 13 |
| 15 | UI review and repairs | Complete all primary journeys; review reference comparisons, responsive layouts, keyboard access, and edge states | 09–14 |
| 16 | Real sample audio | Audio element drives time, seeking, completion, and speed; navigation does not restart playback | 15 |
| 17 | Real briefing data | Replace fixture feed with ingestion and generation services; show progress, stale content, and recoverable failures | 16 |
| 18 | Real voice conversation | Microphone permission, turn submission, spoken answer, cancellation, and resume work with live services | 17 |

Build Home and the player before secondary screens. They establish most of the visual language and prove the central interaction early. Onboarding can then reuse stable components.

## Player behavior contract

Keep a single playback session outside individual screens. Opening Discover, expanding the player, or navigating back must not create a second session or reset the current one.

The session stores the briefing ID, story ID, position, duration, speed, transport state, conversation state, and a resume checkpoint. Store durable preferences and listening progress separately from temporary microphone state. After reload, restore the position in a paused state.

```text
idle → buffering → playing ↔ paused
playing or paused → listening → thinking → answering → resume checkpoint
listening / thinking / answering → cancel or recoverable error → resume checkpoint
playing → next story → buffering → playing
last story completed → finished
```

These arrows summarize behavior; transport and conversation should be modeled separately so the UI cannot accidentally play a story and an answer at the same time.

### Ask and resume rules

1. Ask records the current story ID, exact playback offset, and whether the story was playing; it then pauses story audio.
2. The story card and its source stay visible during the voice turn. The question uses that story as context.
3. Listening, processing, and answering each have distinct feedback and a cancel action.
4. When the answer ends, remain in the conversation so another explicit follow-up is possible. Continue resumes the briefing at a sentence boundary when timing metadata is available, or at the saved offset otherwise.
5. Cancel, denied microphone permission, and a failed answer preserve the checkpoint and offer a clear route back to playback.
6. Asking a question never marks the story complete. An explicit next-story action advances the queue and cancels any active voice turn.
7. Navigating away cancels an active voice turn and restores the checkpoint in a paused state; ordinary story playback continues through navigation.

Prototype the turn with a visible demo-question control before microphone integration. Real microphone capture is a later task; an animated listening indicator alone must not imply recording is working.

## Shared content model

| Entity | Minimum fields |
|---|---|
| Source | ID, name, website URL, optional feed URL |
| Story | ID, title, summary, topic, publication time, source references, transcript, audio reference |
| Briefing or episode | ID, title, ordered story IDs, total duration, generation status |
| Show | ID, name, description, artwork reference, prompt, source IDs, episode IDs, ownership |
| Preferences | Selected topics, optional country/city, input/output language (English), selected source IDs, playback speed, followed show IDs |
| Playback session | Briefing ID, story ID, offset, speed, transport state, conversation state, resume checkpoint |

Use one fixture dataset throughout the prototype. A title, source, chapter, and transcript must describe the same story wherever they appear. Use original or appropriately licensed artwork, and make sample content visibly identifiable as demo content.

## How to review each task

For each task, record the relevant reference, the implemented screens/states, a short demonstration path, any deliberate differences, and the remaining issues. Compare screenshots at the same viewport before judging spacing or proportions.

Review on a standard and a compact iPhone simulator, then a larger iPhone. Use native points, safe areas, and Dynamic Type rather than web viewport assumptions. Include long titles, Dynamic Type, VoiceOver, reduced motion, labeled controls, and touch targets of at least 44 by 44 points as project acceptance criteria.

Automate the behavior that is easy to regress: checkpoint restoration after a voice turn, next-story navigation, one active audio session, saved preferences, and create/edit validation. Use visual review for spacing and layout. Stage C also needs live audio/microphone checks on physical iPhones chosen for release, including headphones and background playback.

## First review milestone

Complete tasks 01–09 before expanding the rest of the app. The demonstration should let a user open Home, start a five-story briefing, switch between cards and transcript, open a source, skip a story, ask a simulated follow-up, and continue at the saved position. Collapsing and reopening the player must preserve that session.

Approve the visual direction and listening interaction at this milestone. Then complete Discover, custom shows, onboarding, Library, and preferences using the same components, followed by real audio and service integrations.

## Daily briefing delivery

The backend refreshes research daily for shared interest groups, then selects each listener's stories using their profile and listening history. The app fetches the prepared briefing and caches its cards and downloaded audio locally for quick reopening and playback. Display its generation time; keep the previous briefing usable during refresh. Offline access covers downloaded material; new research and questions require connectivity.

Country of news coverage and output language are separate future controls: a Swedish-news briefing could be spoken in English. V1 supports English input/output and stores optional location without promising local coverage. Local-news collection and country-specific feeds remain future work.


## Confirmed sign-in and voice adjustments

Use the approved **told.** wordmark. Native sign-in is email → Send Code → code entry → Continue, with one field supporting paste and one-time-code AutoFill. Include Edit Email, resend with server-enforced cooldown, loading, wrong/expired code, delivery failure, and retry states. Use native keyboard and focus behavior; avoid six separate focus-trapping boxes. A successful send is not a signed-in state. Returning valid sessions bypass sign-in. Provide Sign Out in You.

Evaluate Eleven v4 and Eleven v4 Turbo, initially assigning v4 to prepared briefs and Turbo to interactive answers. Both remain configurable until the listening/latency comparison in BACKEND_ARCHITECTURE.md is complete.
