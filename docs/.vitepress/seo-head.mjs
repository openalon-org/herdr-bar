import { existsSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const DOCS_DIR = join(dirname(fileURLToPath(import.meta.url)), '..')

export function pageKey(relativePath) {
  return relativePath
    .replace(/^zh\//, '')
    .replace(/index\.md$/, '')
    .replace(/\.md$/, '')
    .replace(/\/$/, '')
}

export function isZh(relativePath) {
  return relativePath === 'zh.md' || relativePath.startsWith('zh/')
}

export function twinMarkdownPath(relativePath, toZh) {
  const key = pageKey(relativePath)
  if (toZh) return key === '' ? 'zh/index.md' : `zh/${key}.md`
  return key === '' ? 'index.md' : `${key}.md`
}

export function localePageExists(relativePath, toZh, docsDir = DOCS_DIR) {
  if (isZh(relativePath) === toZh) return true
  return existsSync(join(docsDir, twinMarkdownPath(relativePath, toZh)))
}

export function isSeoHeadTag(tag) {
  const type = tag[0]
  const attrs = tag[1] ?? {}
  if (type === 'link' && (attrs.rel === 'canonical' || attrs.rel === 'alternate')) return true
  if (type === 'meta') {
    const name = attrs.name
    const property = attrs.property
    if (name === 'robots' || name?.startsWith('twitter:')) return true
    if (property?.startsWith('og:')) return true
  }
  if (type === 'script' && attrs.type === 'application/ld+json') return true
  return false
}

/** Drop a previous SEO injection so `docs:dev` HMR does not stack canonicals. */
export function replaceSeoHead(head, next) {
  return [...(head ?? []).filter((tag) => !isSeoHeadTag(tag)), ...next]
}
