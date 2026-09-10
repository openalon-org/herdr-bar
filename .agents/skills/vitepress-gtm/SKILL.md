---
name: vitepress-gtm
description: Inject Google Tag Manager (GTM-MNXQCPGT) into an npm VitePress site that ships under openalon.com. Use when adding analytics/GTM/tracking, scaffolding a new VitePress docs site for this domain, or verifying every page (including 404) loads the container.
---

# VitePress GTM on openalon.com

One container for every VitePress site on `https://openalon.com/…`: `GTM-MNXQCPGT`. Site-level, not per markdown page. New pages pick it up automatically.

Reference implementation: `docs/.vitepress/gtm.ts` in herdr-bar. Copy that file (or the snippets below) into the target repo.

## When

- The site is VitePress (`vitepress` in package.json) and production origin is `openalon.com` (any path prefix / GitHub Pages `base`).
- User asks to add Google Tag Manager, GTM, 跟踪, analytics, or “same tracking as herdr-bar / openalon.com”.
- Scaffolding a new docs site under this domain.

Do **not** use for non-VitePress apps, a different domain, or a different GTM container unless the user names a new ID.

## Do

1. Confirm the site is VitePress and the canonical host is `openalon.com`. Keep `GTM-MNXQCPGT` unless they paste a different ID.

2. Drop `docs/.vitepress/gtm.ts` (adjust the docs root if it is not `docs/`):

   ```ts
   import type { HeadConfig } from 'vitepress'

   export const GTM_ID = 'GTM-MNXQCPGT'

   const GTM_BOOTSTRAP = `(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src='https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);})(window,document,'script','dataLayer','${GTM_ID}');`

   export const gtmHead: HeadConfig[] = [['script', {}, GTM_BOOTSTRAP]]

   export function injectGtmNoscript(code: string): string | void {
     const marker = `googletagmanager.com/ns.html?id=${GTM_ID}`
     if (code.includes(marker)) return
     return code.replace(
       /<body([^>]*)>/,
       `<body$1><!-- Google Tag Manager (noscript) --><noscript><iframe src="https://www.googletagmanager.com/ns.html?id=${GTM_ID}" height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript><!-- End Google Tag Manager (noscript) -->`,
     )
   }
   ```

3. Wire it in `defineConfig` — **head script first**, then other tags. `transformHtml` is build-only (no body slot in VitePress):

   ```ts
   import { gtmHead, injectGtmNoscript } from './gtm'

   export default defineConfig({
     transformHtml(code) {
       return injectGtmNoscript(code)
     },
     head: [
       ...gtmHead,
       // existing icon / theme-color / …
     ],
   })
   ```

   If `transformHead` already exists, leave it. Do not put GTM there (that hook is for per-page extras such as 404 `noindex`).

4. Prove it after `vitepress build`:

   - Built HTML contains `GTM-MNXQCPGT` and `https://www.googletagmanager.com/gtm.js?id=` in `<head>`.
   - Built HTML contains `googletagmanager.com/ns.html?id=GTM-MNXQCPGT` **after** `<body`.
   - Check home, one nested page, locale twin if any, and `404.html`.
   - VitePress minifies the bootstrap (parameter names change). Assert the container ID, not the unminified source.

   Example assertion (Node test against `docs/.vitepress/dist`):

   ```js
   assert.ok(html.includes('GTM-MNXQCPGT'))
   assert.ok(html.includes('https://www.googletagmanager.com/gtm.js?id='))
   const bodyOpen = html.search(/<body[^>]*>/)
   const noscript = html.indexOf('googletagmanager.com/ns.html?id=GTM-MNXQCPGT')
   assert.ok(bodyOpen >= 0 && noscript > bodyOpen)
   ```

5. Copy this skill folder into the other repo’s `.agents/skills/vitepress-gtm/` (and symlink `.claude/skills` → `.agents/skills` if that repo uses the same layout) so the next agent finds it.

## Do not

- Paste GTM into a markdown page or frontmatter `head` — new pages would miss it.
- Add gtag.js (`G-…`) next to this container unless the user asks; tags live in GTM, not a second snippet.
- `--deep` / duplicate: skip if `gtm.js?id=GTM-MNXQCPGT` is already in site `head`.
- Expect the noscript iframe in `vitepress dev` — `transformHtml` runs on build. Head script does load in dev.
- Change the container ID, dataLayer name, or host (`www.googletagmanager.com`) without an explicit new snippet from the user.
- Put GTM on a site that is not served from `openalon.com`.

## After deploy

GTM Preview → tag `https://openalon.com/<base>/` (include the VitePress `base`, e.g. `/herdr-bar/`). Local `docs:dev` also hits the container.
