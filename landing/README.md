# told. landing page

A small React + TypeScript + Vite site using the existing told. wordmark and illustrations. Independent of the iOS app and backend; no API keys or services are required.

## Local development

Node 22.12+:

```sh
cd landing
npm ci
npm run dev
```

`npm run build` checks TypeScript and outputs the production site to `dist/`. `npm run preview` serves that build locally.

## Vercel configuration — prepared, not deployed

When you choose to deploy, import this repository into Vercel with:

| Setting | Value |
| --- | --- |
| Root Directory | `landing` |
| Framework | Vite |
| Node.js | 22.x |
| Install command | `npm ci` |
| Build command | `npm run build` |
| Output directory | `dist` |

`vercel.json` supplies the build settings and basic response headers. There are no server functions or client-side routes; navigation uses page anchors. No Vercel project or deployment has been created.

Leave `VITE_APP_STORE_URL` unset for the placeholder: buttons say “Coming soon to the App Store” and lead to the closing section. Set the real `https://apps.apple.com/...` listing URL in Vercel and rebuild when it is available. All `VITE_*` values are public; never add backend secrets here. When you choose the public domain, update `og:image` in `index.html` to its absolute image URL and add the canonical URL.

Reference: [Vite on Vercel](https://vercel.com/docs/frameworks/frontend/vite), [root-directory settings](https://vercel.com/docs/builds/configure-a-build#root-directory).

## Content and behavior

- Hero with original illustrated daily-five card.
- Personal podcast section with three selectable example topics.
- Listening section with an interactive, visual deep-dive timeline. This is a product illustration, with no microphone access or generated audio.
- Light/dark toggle, initialized from system appearance and saved locally; linked creator credit to @josefkarakoca on X.
- Closing App Store placeholder; no departure/shutdown message, signup form, or analytics.
- Local DM Sans fonts with included license, optimized local artwork, keyboard focus states, skip link, and reduced-motion support.

The composition takes inspiration from the user's [Huxe reference](https://www.huxe.com/); all shipped artwork and branding come from this repository.

## Checked

Production TypeScript/Vite build passes. Browser review covers desktop, 390px and 320px phone widths, loaded images, topic selection, deep-dive insertion/reset, and the placeholder link. No horizontal overflow at tested phone widths and no browser console errors. Screenshot: `../docs/landing/preview.jpg`.
