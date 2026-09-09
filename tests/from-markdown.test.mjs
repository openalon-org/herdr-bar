import assert from 'node:assert/strict'
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { describe, it } from 'node:test'
import { fileURLToPath } from 'node:url'
import {
  clipDescription,
  extractDescription,
  extractFaq,
} from '../docs/.vitepress/from-markdown.mjs'
import {
  localePageExists,
  replaceSeoHead,
} from '../docs/.vitepress/seo-head.mjs'

describe('from-markdown SEO extractors', () => {
  it('uses the first prose paragraph, not the heading or a tip', () => {
    const md = `---
outline: false
---

# Install

Pack herdr-bar as a menu-bar extra and point it at Herdr already running on this Mac.

::: tip Herdr has to be online first
ignored
:::
`
    assert.equal(
      extractDescription(md),
      'Pack herdr-bar as a menu-bar extra and point it at Herdr already running on this Mac.',
    )
  })

  it('follows a VitePress include when the page itself has no paragraph', () => {
    const dir = mkdtempSync(join(tmpdir(), 'herdr-seo-'))
    writeFileSync(join(dir, 'notes.md'), '# Changelog\n\nAll notable changes to herdr-bar are documented here.\n')
    const page = join(dir, 'page.md')
    writeFileSync(page, '---\noutline: [2, 3]\n---\n\n<!--@include: ./notes.md-->\n')
    assert.equal(
      extractDescription(readFileSync(page, 'utf8'), page),
      'All notable changes to herdr-bar are documented here.',
    )
  })

  it('parses **question** / answer pairs under FAQ', () => {
    const items = extractFaq(`## FAQ

**What is herdr-bar?**
A macOS menu-bar extra for [Herdr](https://herdr.dev/).

**Does it create new panes?**
No. Focus is \`agent.focus\`.
`)
    assert.deepEqual(items, [
      { name: 'What is herdr-bar?', text: 'A macOS menu-bar extra for Herdr.' },
      { name: 'Does it create new panes?', text: 'No. Focus is agent.focus.' },
    ])
  })

  it('skips VitePress container blocks such as ::: info', () => {
    const md = `::: info What this is
**herdr-bar** is inside a callout, ignore me.
:::

Two layers: a **menu-bar glance** (counts) and a **dashboard** (jump list).
`
    assert.equal(
      extractDescription(md),
      'Two layers: a menu-bar glance (counts) and a dashboard (jump list).',
    )
  })

  it('clips long descriptions on a sentence when it can', () => {
    const long = `${'Word '.repeat(10)}End of first. ${'More '.repeat(40)}`
    const clipped = clipDescription(long, 80)
    assert.ok(clipped.endsWith('End of first.'))
    assert.ok(clipped.length <= 80)
  })

  it('reads the real install and home pages', () => {
    const docs = join(dirname(fileURLToPath(import.meta.url)), '../docs')
    const install = join(docs, 'guide/installation.md')
    assert.equal(
      extractDescription(readFileSync(install, 'utf8'), install),
      'Pack herdr-bar as a menu-bar extra and point it at Herdr already running on this Mac.',
    )
    const home = readFileSync(join(docs, 'index.md'), 'utf8')
    const faq = extractFaq(home)
    assert.equal(faq[0]?.name, 'What is herdr-bar?')
    assert.ok(faq.length >= 3)
  })
})

describe('seo-head helpers', () => {
  it('replaceSeoHead drops a previous canonical instead of stacking', () => {
    const first = replaceSeoHead([], [
      ['link', { rel: 'canonical', href: 'https://openalon.com/herdr-bar/' }],
      ['link', { rel: 'icon', href: '/icon.svg' }],
    ])
    const second = replaceSeoHead(first, [
      ['link', { rel: 'canonical', href: 'https://openalon.com/herdr-bar/' }],
    ])
    assert.equal(second.filter((tag) => tag[1]?.rel === 'canonical').length, 1)
    assert.equal(second.filter((tag) => tag[1]?.rel === 'icon').length, 1)
  })

  it('localePageExists is false when the zh twin is missing', () => {
    const dir = mkdtempSync(join(tmpdir(), 'herdr-seo-twin-'))
    mkdirSync(join(dir, 'guide'))
    writeFileSync(join(dir, 'guide/foo.md'), '# Foo\n')
    assert.equal(localePageExists('guide/foo.md', false, dir), true)
    assert.equal(localePageExists('guide/foo.md', true, dir), false)
  })
})
