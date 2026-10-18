# Category artwork system

Approved direction: [concept](card-direction-v2.png). The concept contains example imagery; standalone production assets have not yet been generated. Do not crop controls or text out of the mockup to create production art.

## Initial library

Begin with three reviewed variants each for Daily brief, Technology, and Our planet: nine standalone assets. Expand only to categories actually included in onboarding. Each category keeps its palette, medium, and lighting across variants.

| Category | Palette | Composition family |
|---|---|---|
| Daily brief | Apricot, sandstone, burgundy | Sunrise, open arches, broad horizons |
| Technology | Dusty lavender, pale blue, pearl | Optical forms and sculptural terrain |
| Our planet | Sage, moss, warm cream | Hills, water, layered terrain |

Science, culture, business, and world-news art follow after the first family is reviewed. Avoid stock AI brains, neon circuit boards, dollar signs, flags as category shortcuts, and cartoon depictions of tragedies. Broad neutral artwork is the fallback.

## Generation and delivery

Use the built-in image-generation tool and the approved concept as a style reference. Generate each standalone image separately. Base prompt: “Original atmospheric editorial illustration for the [CATEGORY] collection of an audio news app. [SUBJECT]. [PALETTE]. Diffuse light, subtle grain, sculptural forms, generous quiet space, consistent with the supplied style reference. Conceptual artwork, no factual news scene, no text, logos, interface, borders, or watermarks.” Save the exact prompt and generation provenance with each asset.

Review at card size and full-player size. Prefer a square master with a crop-safe subject and a quiet lower region; review both square and portrait crops. If neither crop works, create a dedicated alternative. Export device-appropriate sizes after native measurements; do not ship oversized masters to every card. Choose an iOS-supported format after checking visual quality and decoding performance.

## Stable rotation

- Assign artwork when a daily briefing is created; persist its asset ID and version with that briefing. Reopening, refreshing the view, or moving from card to player uses the same image.
- For category collections, rotate once per content day in the configured edition timezone. Use a stable category-specific variant offset; avoid immediate repeats when multiple eligible variants exist. Do not rotate on every render or app launch.
- Pin selected artwork for the entire active playback session, even across midnight or an updated briefing. A new briefing becomes available without replacing the current queue.
- Story artwork inherits a suitable category variant unless a reviewed editorial asset exists. Avoid adjacent duplicates when possible. Never imply each article has a unique illustration.
- Retain old asset versions while referenced by cached briefings. Fetch a new variant in advance and switch atomically after it is ready; never flash between placeholders and changing art.

## Asset contract

Manifest fields: assetId, categoryId, variantId, version, localFallbackName, remoteURL, pixelWidth, pixelHeight, focalPoint, allowedCrops, palette, sensitiveContentEligible, prompt/provenance, reviewStatus. Store the selected asset ID on the briefing/story presentation model; SwiftUI views never pick random assets.

Bundle one neutral fallback and small initial category assets. Cache other versions on device. Missing images must not block playback, headline display, or source access. Cancel obsolete image fetches; decode away from animation-critical work.

## Accessibility and editorial handling

Card titles are native text with a verified scrim/backing. Decorative artwork is hidden from VoiceOver; the card announces its title and meaningful metadata once. Do not describe imaginary landscapes as news content. Sensitive stories use quiet abstract or neutral art, selected by editorial suitability, not mood inferred solely from a keyword.
