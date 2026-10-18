# Huxe UI reverse-engineering reference pack

Research date: 2026-10-17. Product scope updated 2026-10-18; see [backend architecture](BACKEND_ARCHITECTURE.md) for current decisions. Purpose: identify documented Huxe screens and adapt its information architecture for an original conversational-news MVP. Huxe discontinued service in May 2026. Screenshots span multiple versions (2025-2026) and **must not be treated as one cohesive release**.

## Primary screenshot archives

- [AppsHunter archived iOS listing: 6 marketing/screenshots](https://appshunter.io/ios/app/huxe-ai-radio-and-podcasts/id6743417504)
- [AppRank iOS archive: 6 iPhone + 2 iPad images](https://apprank.io/huxe-ai-radio-podcasts-7504)
- [AppPage archived Android listing: 8 screenshots](https://apppage.net/preview/com.huxe.android.apps.huxe)
- [Hands-on onboarding and player screenshots (May 2026, Japanese)](https://minnano-rakuraku.com/contents/huxe-24474/)
- [Fast Company hands-on review (September 2025)](https://www.fastcompany.com/91409664/huxe-ai-podcasts)
- [TechCrunch launch overview (September 2025)](https://techcrunch.com/2025/09/23/former-notebooklm-devs-new-app-huxe-taps-audio-to-help-you-with-news-and-research/)
- [WIRED detailed review (February 2026)](https://www.wired.com/story/huxe-personalized-daily-audio-podcasts-powered-by-ai/)
- [Dutch hands-on UI screenshots (April 2026)](https://fmthandpickedai.substack.com/p/huxe-laat-met-ai-een-indrukwekkende)
- [Swedish App Store listing / full version history](https://apps.apple.com/se/app/huxe-ai-radio-podcasts/id6743417504)

## Six original App Store reference images (high resolution)

These are Huxe promotional screenshots, with phone-frame UI. Use for research, not as shipped app assets.

1. [Home / For You / Keep listening](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/19/ba/36/19ba3654-2ea1-75c6-b994-92ea4b3a594b/image__U00281_U0029.png/1320x2868bb.png)
2. [Daily Brief player / dynamic cards](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/16/dc/d9/16dcd9c0-2d86-58d5-b849-bea8d915a532/image__U00282_U0029.png/1320x2868bb.png)
3. [Discover / searchable stations by category](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/60/91/19/609119a6-13c6-7997-ea6a-efbc0355bcf8/image__U00283_U0029.png/1320x2868bb.png)
4. [Custom show page / episodes / Generate now / Edit](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/89/30/a5/8930a52a-15a9-87b3-1ae1-a6c299aa3d42/image__U00284_U0029.png/1320x2868bb.png)
5. [Interactive player / transcript / chapters / listening state](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/b3/87/61/b3876102-121b-d6ae-1338-79798c388197/image__U00285_U0029.png/1320x2868bb.png)
6. [DeepCast composer / Research or Use Sources / visibility](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/1f/c2/84/1fc28472-5305-ff96-0d18-d2ace7908118/image__U00286_U0029.png/1320x2868bb.png)

## May 2026 onboarding & playback screen captures

- [Sign in](https://minnano-rakuraku.com/contents/wp-content/uploads/2026/05/huxe_login.jpg)
- [Connect calendar and email, or setup later](https://minnano-rakuraku.com/contents/wp-content/uploads/2026/05/huxe_calender.jpg)
- [Select and edit interests](https://minnano-rakuraku.com/contents/wp-content/uploads/2026/05/huxe_interests.jpg)
- [Daily Brief headline card](https://minnano-rakuraku.com/contents/wp-content/uploads/2026/05/huxe_headlines.jpg)
- [Bottom audio controls / Join](https://minnano-rakuraku.com/contents/wp-content/uploads/2026/05/huxe_join.jpg)
- [Research prompt composer](https://minnano-rakuraku.com/contents/wp-content/uploads/2026/05/huxe_research.jpg)

## Function inventory

Confidence H = visible screenshot; M = detailed written hands-on description or screenshot partial; L = proposed, not established.

| Screen or behavior | Huxe evidence | Confidence | Adaptation for Talk to the News |
|---|---|---|---|
| Sign-in | Google/Apple login onboarding screenshot | H | Optional sign-in only after demo |
| Interest selection | Editable interest tags screenshot | H | Choose topics AND disliked topics |
| Connected personal data | Connect mail/calendar setup screenshot | H | Excluded from toldAI scope |
| Home / personalized daily briefing | For You, date-based greeting, Play button | H | One obvious "Play today's brief" CTA |
| Discover stations | Search, Tech/Sports/Science topics, cards | H | Source-based channels and topic feeds |
| Daily brief with live cards | Visual news cards and player controls | H | One story at a time with source citations |
| Voice interruption | Join/Listening and playback screenshot | H | Primary differentiator: ask, skip, continue |
| Segment navigation | UI chapter tabs, prior skip/deeper buttons | H | Skip, Deep dive, Next explicitly visible |
| Transcript mode | Player text visible, WIRED describes Card/Text switching | H/M | Transcript and article/source links |
| Create / DeepCast | Research/Use Sources composer screenshot | H | Create a persistent custom news channel |
| Custom show details | Episodes, Edit, Generate Now screenshot | H | My briefings with Last updated marker |
| RSS/web/X/Reddit inputs | Hands-on UI partial and Fast Company instructions | M | Start with RSS and source websites |
| Live station updating | TechCrunch hands-on | M | Refresh on demand + scheduled daily |
| Settings and voice selection | WIRED walkthrough + App Store changes | M | One voice, English in v1, playback speed |
| Continuous playback & CarPlay | Official version-history release notes | M | Defer until users establish habit |
| Reliable item-level citations | No complete UI proof located | L | Essential original improvement |
| Long-term personal context | General personalization described, details unknown | L | Add only after repeated use validated |

## Proposed information architecture for news-only MVP

```text
Onboarding
  Welcome -> Pick topics -> Save profile (English, optional location) -> Ready

Home
  Today's briefing -> Audio player
  Continue listening
  Following topics

Audio player
  Story card with source + timestamp
  Play / pause / speed
  Skip -> next story
  Ask / Deepen -> AI voice turn -> resume queue
  Transcript + Open original sources

Explore
  Search topics / browse categories -> Follow

Create
  New custom news channel -> choose topic + sources -> Save

Library / Preferences
  Followed topics, completed briefs, source preferences, voice/settings
```

## MVP build priority

**P0 - clickable visual prototype, no live models:** Welcome, Interests, Sources, Home, Player (idle/playing/listening/speaking), Explore, Source detail. Dummy 5-story briefing and realistic state transitions.

**P1 - functional core:** Daily story ingestion, deduplication, source metadata, audio playback, skip, one spoken follow-up and return to sequence, feedback events.

**P2 - habit and differentiation:** Saved interests/sources, cross-day memory for stories already heard, updates since prior discussion, reading view, bookmarks, one-click source retrieval.

**Excluded:** Email/calendar connections and weather integrations.

**Not yet:** Public social-show sharing, remixes, community follows, dozens of host voices, podcast generation for arbitrary topics, CarPlay.

## Key technical/UI behavior to simulate before building back end

Player state machine:

`IDLE -> PLAYING_STORY -> LISTENING_TO_USER -> ANSWERING -> RESUMING_STORY or ADVANCING_STORY -> PLAYING_STORY`, with `PAUSED`, `ERROR`, and `BUFFERING` branches.

The prototype should show the source and brief summary of the **currently spoken story**. When the user requests more detail, context stays on that story. After the spoken answer, it returns to playback at an explicitly defined point. A voice question must never accidentally mark a story finished.

## Gaps not reproducible with public documentation alone

- Exact screen-by-screen interactive transitions and loading/error cases.
- Internal ranking/personalization and how briefing items were selected.
- Reliable detailed settings, playback/accessibility behavior in every release.
- Exact implementations of streaming voice, audio buffering, interruption and resume.
- License terms permitting access to full article bodies.

## Important caution

This is documentation for an **independent** product, not a proposal to misrepresent Huxe or reproduce its logo, brand, proprietary visual assets, trademarks or source code. Several images are copyrighted screenshots linked to their publishers for research reference. Use original branding and visual design in shipped software.
