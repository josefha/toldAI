# Illustrated card direction · v0.2

Approved visual direction. The [brand book](BRAND_BOOK.md), [native interaction contract](UI_FOUNDATION.md), and [artwork system](ARTWORK_SYSTEM.md) are authoritative for implementation. This supersedes the text-heavy v0.1 board. [View concept](card-direction-v2.png). Generated with the built-in image-generation tool; a visual exploration, not a functioning or accessibility-verified interface.

## Composition

- A quiet greeting and one generous illustrated briefing card: title, count, duration, play. Remove marketing slogans and summary paragraphs.
- Large interest boxes with short labels. Two columns normally, one when width or Dynamic Type requires it. Content continues below the fold.
- All five stories remain accessible in briefing detail. Interest collections do not replace the queue.
- Player: large artwork, headline, story position, source access, Ask and pause. Disclose summary and transcript on demand.
- Prototype with 24pt margins, 16pt card gaps, 32pt section spacing. Use medium-weight display type and quiet white primary controls. These are proposed values, not measurements of the generated image.

## Illustration system

Create a curated reusable library per interest, not per user or article. Store a stable theme key, asset version, palette, focal point and crop guidance; cache on device.

Atmospheric editorial landscapes, sculptural forms, diffuse light, subtle grain, uncluttered compositions. Technology: optical forms and lavender. Environment: sage terrain. Daily brief: warm sunrise arches. Extend the same visual grammar to science, culture, business and world news after approving this direction.

Generate standalone artwork without text or controls. Render labels and interactions in SwiftUI. Compose for square and portrait crops, reserving quiet areas for overlays. Artwork is conceptual, never evidence of a news event. Use neutral artwork for sensitive reporting.

## Native validation

Expand selected artwork continuously from card into player. Tune an interruptible spring on device; crossfade with Reduce Motion. Keep artwork static while listening.

Source count must open sources with a labeled target at least 44pt. Include an explicit summary action. Verify contrast over final crops using controlled scrims or opaque label backing; gray metadata in the generated mockup is not an approved token.

Retain the existing foundation's playback coordinator, gesture ownership, cancellation, VoiceOver and Dynamic Type requirements. Prove Home → Player → Ask → Answer → Continue on device before extracting reusable components. A static mockup cannot establish smoothness.

## Generation prompt

Built-in image generation; final saved asset: `docs/design/card-direction-v2.png`.

```text
Use case: ui-mockup. Create a polished high fidelity visual concept for toldAI, a native iPhone audio news app inspired by the spacious media-card composition of Huxe. Landscape presentation, two large straight-on iPhone screen designs side by side on a plain warm charcoal background, small labels HOME and LISTEN outside screens. This is a refined editorial art direction, not a dashboard. No explanatory board paragraphs, swatches or marketing slogans.
Screen 1 HOME: near-black background, small 'told' wordmark, restrained greeting 'Morning, Josef'. A very large rounded rectangular daily brief card with original soft editorial illustration of a sunrise passing through sculptural sandstone arches, atmospheric apricot, burgundy, muted lilac, subtle paper grain, beautiful diffuse light, plenty of negative space. Card text only 'Your daily five' and '5 stories · 8 min', plus a white circular play button. Under card spacious heading 'Your interests' and two broad rounded illustrated theme boxes 'Technology' (sculptural translucent optical prism, dusty lavender) and 'Our planet' (rolling sage landscape, warm cream). These are beautiful imagery-led boxes with short titles, no description paragraphs, no rows of tiny news text. Partial next content at bottom suggests vertical scrolling. Floating restrained bottom pill navigation Home Search You, safe area breathing room.
Screen 2 LISTEN: immersive spacious near-black player, small top chevron and 'Technology', huge rounded square artwork of translucent optical prism on sculptural lavender terrain rendered in exact same soft editorial style. Beneath artwork 'The next wave of AI' in restrained medium weight sans serif, 'Story 1 of 5 · 3 sources' smaller. Five very thin progress segments. Lots of breathing room. Bottom controls: large white rounded 'Ask' button with mic icon and separate circular pause. Small 'Transcript' link. No summary paragraph. Clear readable SF-like typography, 24px margins, generous vertical rhythm, soft continuous corner curves, no gold CTA, no neon, no generic AI sparkle icon, no glass stacked on glass, no ornamental fake waveforms, no device perspective. Illustration must be conceptual and obviously art, never fake news photography. Show tasteful premium app design with calm spacing, less text, more generous image-bearing boxes.
```

