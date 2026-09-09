import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import type { HeadConfig, PageData } from 'vitepress'
import { extractDescription, extractFaq } from './from-markdown.mjs'
import {
  isZh as pathIsZh,
  localePageExists,
  pageKey as pathPageKey,
  replaceSeoHead as replaceSeoHeadTags,
} from './seo-head.mjs'

export const replaceSeoHead = replaceSeoHeadTags

/** Production origin, no trailing slash. Path prefix lives in VitePress `base`. */
export const SITE_ORIGIN = 'https://openalon.com'
export const SITE_PATH = '/herdr-bar'
export const SITE_URL = `${SITE_ORIGIN}${SITE_PATH}`
export const GITHUB = 'https://github.com/openalon-org/herdr-bar'
export const OG_IMAGE = `${SITE_URL}/og.png`
export const OG_IMAGE_ALT = 'herdr-bar — macOS menu-bar companion for Herdr'

export const SITE_TITLE = 'herdr-bar'
export const SITE_DESCRIPTION_EN =
  'macOS menu-bar companion for Herdr: see every coding agent at a glance and jump to the one that needs you.'
export const SITE_DESCRIPTION_ZH =
  'macOS 菜单栏上的 Herdr 伴侣：一眼看到每个 coding agent，跳到最需要你的那个。'

const DOCS_DIR = join(dirname(fileURLToPath(import.meta.url)), '..')

export function pageKey(relativePath: string): string {
  return pathPageKey(relativePath)
}

export function isZh(relativePath: string): boolean {
  return pathIsZh(relativePath)
}

export function localeOf(relativePath: string): 'en-US' | 'zh-CN' {
  return isZh(relativePath) ? 'zh-CN' : 'en-US'
}

function sourcePath(pageData: PageData): string | null {
  const rel = pageData.filePath || pageData.relativePath
  if (!rel) return null
  return join(DOCS_DIR, rel)
}

function sourceOf(pageData: PageData): string {
  const path = sourcePath(pageData)
  if (!path) return ''
  try {
    return readFileSync(path, 'utf8')
  } catch {
    return ''
  }
}

/**
 * Per-page description, in this order:
 * 1. frontmatter `description` (explicit override)
 * 2. home layout → locale site tagline
 * 3. first prose paragraph of the markdown (VitePress includes expanded)
 * 4. locale site tagline
 */
export function descriptionFor(pageData: PageData): string {
  const fm = pageData.frontmatter?.description
  if (typeof fm === 'string' && fm.trim()) return fm.trim()
  if (pageData.frontmatter.layout === 'home' || pageKey(pageData.relativePath) === '') {
    return isZh(pageData.relativePath) ? SITE_DESCRIPTION_ZH : SITE_DESCRIPTION_EN
  }
  const path = sourcePath(pageData)
  const fromMd = extractDescription(sourceOf(pageData), path ?? undefined)
  if (fromMd) return fromMd
  return isZh(pageData.relativePath) ? SITE_DESCRIPTION_ZH : SITE_DESCRIPTION_EN
}

export function titleFor(pageData: PageData): string {
  if (pageData.frontmatter.layout === 'home' || pageKey(pageData.relativePath) === '') {
    return `${SITE_TITLE} | ${isZh(pageData.relativePath) ? '菜单栏上的 Herdr 伴侣' : 'A Herdr companion in the menu bar'}`
  }
  const pageTitle = pageData.title?.trim()
  return pageTitle ? `${pageTitle} | ${SITE_TITLE}` : SITE_TITLE
}

/** Canonical path under /herdr-bar, always with a trailing slash on indexes. */
export function canonicalPath(relativePath: string): string {
  const stripped = relativePath.replace(/\.md$/, '')
  if (stripped === 'index') return `${SITE_PATH}/`
  if (stripped === 'zh/index' || stripped === 'zh') return `${SITE_PATH}/zh/`
  return `${SITE_PATH}/${stripped}.html`
}

export function canonicalUrl(relativePath: string): string {
  return `${SITE_ORIGIN}${canonicalPath(relativePath)}`
}

export function alternatePath(relativePath: string, toZh: boolean): string {
  const key = pageKey(relativePath)
  if (toZh) {
    return key === '' ? `${SITE_PATH}/zh/` : `${SITE_PATH}/zh/${key}.html`
  }
  return key === '' ? `${SITE_PATH}/` : `${SITE_PATH}/${key}.html`
}

export function alternateUrl(relativePath: string, toZh: boolean): string {
  return `${SITE_ORIGIN}${alternatePath(relativePath, toZh)}`
}

function jsonLd(pageData: PageData, url: string, title: string, description: string): string {
  const zh = isZh(pageData.relativePath)
  const home = zh ? `${SITE_URL}/zh/` : `${SITE_URL}/`
  const crumbs: { '@type': 'ListItem'; position: number; name: string; item: string }[] = [
    { '@type': 'ListItem', position: 1, name: SITE_TITLE, item: home },
  ]
  const key = pageKey(pageData.relativePath)
  if (key !== '') {
    crumbs.push({
      '@type': 'ListItem',
      position: 2,
      name: pageData.title || key,
      item: url,
    })
  }
  const graph: Record<string, unknown>[] = [
    {
      '@type': 'WebSite',
      '@id': `${SITE_URL}/#website`,
      url: `${SITE_URL}/`,
      name: SITE_TITLE,
      description: SITE_DESCRIPTION_EN,
      inLanguage: ['en-US', 'zh-CN'],
      publisher: { '@id': `${SITE_URL}/#org` },
    },
    {
      '@type': 'Organization',
      '@id': `${SITE_URL}/#org`,
      name: 'openalon',
      url: SITE_ORIGIN,
      sameAs: [GITHUB],
    },
    {
      '@type': 'SoftwareApplication',
      '@id': `${SITE_URL}/#app`,
      name: SITE_TITLE,
      applicationCategory: 'DeveloperApplication',
      operatingSystem: 'macOS 13+',
      url: `${SITE_URL}/`,
      downloadUrl: `${GITHUB}/releases`,
      softwareRequirements: 'Herdr 0.8+',
      license: `${GITHUB}/blob/main/LICENSE`,
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
    },
    {
      '@type': 'WebPage',
      '@id': `${url}#webpage`,
      url,
      name: title,
      description,
      inLanguage: localeOf(pageData.relativePath),
      isPartOf: { '@id': `${SITE_URL}/#website` },
      about: { '@id': `${SITE_URL}/#app` },
      primaryImageOfPage: { '@type': 'ImageObject', url: OG_IMAGE, width: 1200, height: 630 },
      breadcrumb: {
        '@type': 'BreadcrumbList',
        itemListElement: crumbs,
      },
    },
  ]
  const faq = extractFaq(sourceOf(pageData))
  if (faq.length) {
    graph.push({
      '@type': 'FAQPage',
      '@id': `${url}#faq`,
      url,
      mainEntity: faq.map((item) => ({
        '@type': 'Question',
        name: item.name,
        acceptedAnswer: { '@type': 'Answer', text: item.text },
      })),
    })
  }
  return JSON.stringify({ '@context': 'https://schema.org', '@graph': graph })
}

export function pageHead(pageData: PageData): HeadConfig[] {
  if (pageData.isNotFound) {
    return [['meta', { name: 'robots', content: 'noindex, nofollow' }]]
  }
  const url = canonicalUrl(pageData.relativePath)
  const title = titleFor(pageData)
  const description = descriptionFor(pageData)
  const locale = localeOf(pageData.relativePath)
  const en = alternateUrl(pageData.relativePath, false)
  const zh = alternateUrl(pageData.relativePath, true)
  const head: HeadConfig[] = [
    ['link', { rel: 'canonical', href: url }],
  ]
  if (localePageExists(pageData.relativePath, false)) {
    head.push(['link', { rel: 'alternate', hreflang: 'en-US', href: en }])
  }
  if (localePageExists(pageData.relativePath, true)) {
    head.push(['link', { rel: 'alternate', hreflang: 'zh-CN', href: zh }])
  }
  if (localePageExists(pageData.relativePath, false)) {
    head.push(['link', { rel: 'alternate', hreflang: 'x-default', href: en }])
  }
  head.push(
    ['meta', { name: 'robots', content: 'index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: SITE_TITLE }],
    ['meta', { property: 'og:locale', content: locale.replace('-', '_') }],
  )
  if (localePageExists(pageData.relativePath, locale !== 'zh-CN')) {
    head.push(['meta', { property: 'og:locale:alternate', content: locale === 'zh-CN' ? 'en_US' : 'zh_CN' }])
  }
  head.push(
    ['meta', { property: 'og:title', content: title }],
    ['meta', { property: 'og:description', content: description }],
    ['meta', { property: 'og:url', content: url }],
    ['meta', { property: 'og:image', content: OG_IMAGE }],
    ['meta', { property: 'og:image:alt', content: OG_IMAGE_ALT }],
    ['meta', { property: 'og:image:width', content: '1200' }],
    ['meta', { property: 'og:image:height', content: '630' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:title', content: title }],
    ['meta', { name: 'twitter:description', content: description }],
    ['meta', { name: 'twitter:image', content: OG_IMAGE }],
    ['meta', { name: 'twitter:image:alt', content: OG_IMAGE_ALT }],
    ['script', { type: 'application/ld+json' }, jsonLd(pageData, url, title, description)],
  )
  return head
}
