# toldAI brand book

Version 1.0 · 2026-10-18 · Approved visual direction; native implementation and accessibility validation pending.

## The direction

**A quiet black-and-white interface with generous illustrated cards.** Color belongs to the pictures. Native controls, spacious composition, and continuous movement make listening feel effortless.

The [approved concept](card-direction-v2.png) is the visual reference. The earlier `brand-board.svg` and its PNG are superseded explorations, not implementation targets. [Tokens](tokens.json), [interaction plan](UI_FOUNDATION.md), and [artwork system](ARTWORK_SYSTEM.md) define the build. The generated concept establishes atmosphere and hierarchy, not exact typography, contrast, control dimensions, or working gestures.

Huxe informed the media-card composition. toldAI's content is five relevant news stories, with explicit sources and room for questions. Calendar, email, and weather are outside scope. English is the first release language.

## Character and writing

Calm, curious, clear, grounded. Say “Your daily five”, “Ask”, “Continue”, and “View sources”. Avoid promotional slogans in the listening interface. Errors explain a useful next step. The approved wordmark is **told.**, including its final dot: [transparent PNG](logo/told-wordmark-v1.png). Use the supplied sculpted lettering, not a font recreation. Keep the repository/project name toldAI. Preserve proportions and use clear space around the mark; a reverse-color variant and vector master remain production preparation tasks.

One headline and one metadata line normally suffice on a browsing card. Full headlines, summaries, attribution, and transcripts remain available in detail. Less visible copy must not mean missing information. Do not hide essential controls to make a screenshot cleaner.

## Monochrome foundation

| Semantic role | Dark | Light |
|---|---|---|
| Canvas | #0C0C0C | #F7F7F7 |
| Surface | #1C1C1E | #FFFFFF |
| Primary text | #F5F5F5 | #171717 |
| Secondary text | #B8B8BD | #626268 |
| Primary action fill | #F5F5F5 | #171717 |
| Primary action label | #171717 | #FFFFFF |
| Divider, decorative | #3A3A3C | #D8D8DC |

Use system semantic error/destructive colors with a label and symbol. Monochrome branding does not override meaningful platform status colors. Do not apply a universal tint that erases permission, destructive, disabled, or focus states. Links need labels or underlines, not color alone.

Opaque contrast values are computed in tokens.json. Artwork overlays and materials require separate measurement in the final rendered UI. Use a controlled bottom scrim behind card titles; increase opacity or move labels to an opaque backing when required. Decorative dividers must not be the only visible control boundary.

Light mode uses the same artwork, white surfaces, and dark controls; do not simply invert images. Follow system appearance. Increased Contrast strengthens boundaries and metadata; Reduce Transparency uses opaque surfaces.

## Type and space

Use SwiftUI's SF system text styles and Dynamic Type. Identity comes from the pictures and composition. Default to regular or medium display weights; reserve semibold for section titles and actions.

| Role | Starting size and weight |
|---|---|
| Briefing card title | 28pt medium, title scaling |
| Player headline | 28pt medium, title scaling, wraps fully |
| Section heading | 22pt semibold, title2 scaling |
| Body and transcript | 17pt regular, body scaling |
| Action | 17pt semibold, body scaling |
| Metadata | 13pt medium, caption scaling |
| Playback time | 13pt medium, monospaced digits |

Spacing scale: 4, 8, 12, 16, 20, 24, 32, 48pt. Start with 24pt screen insets, 16pt card gaps, 20pt card content padding, 32pt section gaps. Continuous rounded corners: 24pt cards, 32pt hero; capsules for primary voice actions. These are adaptable tokens, never fixed screen coordinates.

Targets are at least 44×44pt. At larger text sizes, use one-column interest cards, reduce decorative image height, move labels below artwork when needed, and allow vertical scrolling. Preserve all actions. Do not truncate the player headline or shrink fonts to fit.

## Screen composition

**Home:** restrained greeting, one large daily-brief illustration with title/count/duration and Play, followed by a simple grid of interest collections. No slogan block and no dense story rows above the fold. Card body opens briefing details; its separate Play button starts/resumes playback. Avoid nested buttons. A stable mini-player appears above native tabs when a session exists.

**Briefing detail:** all five stories in order, readable headlines, duration, sources, and play actions. A native list is appropriate here. Tapping a story opens its details; pressing Play explicitly changes audio. Finishing a story advances through the current queue.

**Player:** large artwork, headline, current story/count, Sources, transport, and Ask. Summary and Transcript are accessible detail destinations. Artwork can shrink on smaller screens so controls stay reachable. Five segments indicate story position; the separate timeline controls within-story seeking. Never turn tiny segments into the sole navigation control.

**Search:** native search input, readable results and explicit research submission. A query does not replace a playing briefing. **You:** native settings forms for interests, optional location, and playback preferences. English is the only v1 language.

## Imagery

Use original conceptual illustrations from a small curated category library. Soft light, subtle grain, sculptural landscapes, generous negative space. Category colors are stable while compositions rotate. Artwork is decorative, not a depiction of a reported event. Keep generated imagery away from photorealistic news claims and use restrained neutral art for sensitive stories.

No generated text, buttons, or logos inside shipped artwork. Render all UI natively. See the artwork system for rotation, caching, accessibility, and asset review.

## Native behavior and motion

Use standard TabView, NavigationStack, Button, Slider, Menu, TextField, List, Form, and system sheets where they fit. Keep SF Symbols, native scrolling, back gestures, keyboard, permissions, sharing, and selection behavior. The generated floating tab bar is illustrative; accept the native tab appearance of each supported OS rather than recreating it pixel-for-pixel.

The signature movement follows artwork from card or mini-player into the player. Start with native presentation; add matched artwork movement only if cancellation, VoiceOver, and scrolling remain reliable. Keep audio ownership independent of presentation. No continuous moving gradients, decorative waveforms, or mandatory parallax.

Retain supported iOS 18 behavior. Newer visual materials are optional behind availability checks, not a dependency. Let system components use platform timing; custom timing tokens are starting values for the native prototype only.

## Review gate

Prove Home → Player → Ask → Answer → Continue using sample audio before extracting reusable patterns. Review light/dark, narrow phones, largest Dynamic Type, VoiceOver, Reduce Motion/Transparency, long titles, missing artwork, offline playback, permission denial, cancellation, and audio interruptions. A static concept does not prove fluid interaction.

## Apple design principles applied

These rules come from the installed Apple design skill references; all visual token choices are project decisions.

- `branding.md › Best practices`: “Express your brand with familiar components.” [Branding](https://developer.apple.com/design/human-interface-guidelines/branding)
- `collections.md › Best practices`: “Use the standard row or grid layout whenever possible.” [Collections](https://developer.apple.com/design/human-interface-guidelines/collections)
- `buttons.md › Best practices`: “Always include a press state for a custom button.” [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
- `sheets.md › Best practices`: “Display only one sheet at a time from the main interface.” [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
- `motion.md › Providing feedback`: “Let people cancel motion.” [Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
