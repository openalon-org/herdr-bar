import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { describe, it } from 'node:test'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const dist = join(root, 'docs/.vitepress/dist')

function html(rel) {
  return readFileSync(join(dist, rel), 'utf8')
}

function mustInclude(body, snippets, label) {
  for (const snippet of snippets) {
    assert.ok(body.includes(snippet), `${label} missing ${snippet}`)
  }
}

describe('docs SEO head', () => {
  it('home has one canonical, hreflang pair, OG image, and JSON-LD', () => {
    const body = html('index.html')
    mustInclude(body, [
      '<link rel="canonical" href="https://openalon.com/herdr-bar/">',
      '<link rel="alternate" hreflang="en-US" href="https://openalon.com/herdr-bar/">',
      '<link rel="alternate" hreflang="zh-CN" href="https://openalon.com/herdr-bar/zh/">',
      '<link rel="alternate" hreflang="x-default" href="https://openalon.com/herdr-bar/">',
      'property="og:image" content="https://openalon.com/herdr-bar/og.png"',
      'property="og:url" content="https://openalon.com/herdr-bar/"',
      'application/ld+json',
      '"@type":"SoftwareApplication"',
      '"What is herdr-bar?"',
    ], 'en home')
    assert.equal((body.match(/rel="canonical"/g) || []).length, 1)
  })

  it('install page canonical uses .html and points at the zh twin', () => {
    const body = html('guide/installation.html')
    mustInclude(body, [
      '<link rel="canonical" href="https://openalon.com/herdr-bar/guide/installation.html">',
      'hreflang="zh-CN" href="https://openalon.com/herdr-bar/zh/guide/installation.html"',
      'Pack herdr-bar as a menu-bar extra and point it at Herdr already running on this Mac.',
    ], 'install')
  })

  it('a guide page without frontmatter description still gets a unique snippet from the first paragraph', () => {
    const body = html('guide/usage.html')
    mustInclude(body, [
      'Two layers: a menu-bar glance (counts) and a dashboard (jump list).',
    ], 'usage')
  })

  it('zh home is a reciprocal hreflang, not a copy of the English canonical', () => {
    const body = html('zh/index.html')
    mustInclude(body, [
      '<link rel="canonical" href="https://openalon.com/herdr-bar/zh/">',
      'hreflang="en-US" href="https://openalon.com/herdr-bar/"',
      'hreflang="x-default" href="https://openalon.com/herdr-bar/"',
    ], 'zh home')
  })

  it('sitemap and robots share the same host+base', () => {
    const sitemap = readFileSync(join(dist, 'sitemap.xml'), 'utf8')
    const robots = readFileSync(join(dist, 'robots.txt'), 'utf8')
    assert.match(sitemap, /<loc>https:\/\/openalon.com\/herdr-bar\/<\/loc>/)
    assert.match(sitemap, /<loc>https:\/\/openalon.com\/herdr-bar\/guide\/installation\.html<\/loc>/)
    assert.match(sitemap, /<loc>https:\/\/openalon.com\/herdr-bar\/zh\/<\/loc>/)
    assert.match(robots, /Sitemap: https:\/\/openalon.com\/herdr-bar\/sitemap.xml/)
    assert.ok(existsSync(join(dist, 'og.png')), 'og.png missing from dist')
  })

  it('frontmatter description wins over the first paragraph on architecture', () => {
    const body = html('guide/architecture.html')
    const desc = body.match(/<meta name="description" content="([^"]*)">/)?.[1] ?? ''
    assert.equal(desc, 'How herdr-bar watches Herdr sockets, aggregates sessions, and raises the host TUI.')
    assert.ok(body.includes('Two Swift targets'), 'body still has the first paragraph')
  })

  it('404 is noindex and has no canonical', () => {
    const body = html('404.html')
    mustInclude(body, ['name="robots" content="noindex, nofollow"'], '404')
    assert.equal((body.match(/rel="canonical"/g) || []).length, 0)
  })

  it('every page loads Google Tag Manager in head and noscript after body', () => {
    for (const rel of ['index.html', 'guide/usage.html', 'zh/index.html', '404.html']) {
      const body = html(rel)
      mustInclude(body, [
        'GTM-MNXQCPGT',
        'https://www.googletagmanager.com/gtm.js?id=',
        'googletagmanager.com/ns.html?id=GTM-MNXQCPGT',
      ], rel)
      const bodyOpen = body.search(/<body[^>]*>/)
      const noscript = body.indexOf('googletagmanager.com/ns.html?id=GTM-MNXQCPGT')
      assert.ok(bodyOpen >= 0 && noscript > bodyOpen, `${rel} noscript is not after <body>`)
    }
  })
})
