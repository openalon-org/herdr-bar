import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'

const INCLUDE = /<!--@include:\s*([^>\s]+)\s*-->/g

export function stripFrontmatter(markdown) {
  if (!markdown.startsWith('---')) return markdown
  const end = markdown.indexOf('\n---', 3)
  if (end === -1) return markdown
  return markdown.slice(end + 4)
}

export function stripInlineMarkdown(text) {
  return text
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/\*([^*]+)\*/g, '$1')
    .replace(/\s+/g, ' ')
    .trim()
}

/** Expand VitePress `<!--@include: rel{start,end}-->` one level, relative to `fromFile`. */
export function expandIncludes(markdown, fromFile) {
  if (!fromFile) return markdown
  return markdown.replace(INCLUDE, (_, spec) => {
    const match = String(spec).match(/^(.*?)(?:\{(\d+)?,(\d+)?\})?$/)
    if (!match) return ''
    const target = join(dirname(fromFile), match[1])
    if (!existsSync(target)) return ''
    const raw = readFileSync(target, 'utf8')
    const lines = (match[2] || match[3] ? raw : stripFrontmatter(raw)).split('\n')
    const start = match[2] ? Number(match[2]) - 1 : 0
    const end = match[3] ? Number(match[3]) : lines.length
    return lines.slice(start, end).join('\n')
  })
}

export function firstParagraph(markdown) {
  let inFence = false
  let inContainer = false
  const paras = []
  let buf = []
  for (const line of markdown.split('\n')) {
    if (line.trimStart().startsWith('```')) {
      inFence = !inFence
      continue
    }
    if (inFence) continue
    const trimmed = line.trim()
    if (trimmed.startsWith(':::')) {
      inContainer = !inContainer
      continue
    }
    if (inContainer) continue
    if (!trimmed) {
      if (buf.length) {
        paras.push(buf.join(' '))
        buf = []
      }
      continue
    }
    if (
      trimmed === '---'
      || trimmed.startsWith('#')
      || trimmed.startsWith(':::')
      || trimmed.startsWith('|')
      || trimmed.startsWith('<')
      || trimmed.startsWith('- ')
      || trimmed.startsWith('* ')
      || trimmed.startsWith('>')
      || trimmed.startsWith('<!--')
    ) {
      if (buf.length) {
        paras.push(buf.join(' '))
        buf = []
      }
      continue
    }
    buf.push(trimmed)
  }
  if (buf.length) paras.push(buf.join(' '))
  return stripInlineMarkdown(paras[0] || '')
}

export function clipDescription(text, max = 160) {
  if (!text) return ''
  if (text.length <= max) return text
  const slice = text.slice(0, max)
  const period = Math.max(slice.lastIndexOf('。'), slice.lastIndexOf('. '))
  if (period >= 60) {
    return slice[period] === '。'
      ? slice.slice(0, period + 1)
      : slice.slice(0, period + 1).trim()
  }
  const space = slice.lastIndexOf(' ')
  const cut = space >= 60 ? slice.slice(0, space) : slice.trim()
  return `${cut.replace(/[.,;:、，]+$/, '')}…`
}

export function extractDescription(markdown, fromFile) {
  const expanded = expandIncludes(markdown, fromFile)
  return clipDescription(firstParagraph(stripFrontmatter(expanded)))
}

/**
 * `## FAQ` / `## 常见问题` blocks whose questions are a bold line
 * (`**What is herdr-bar?**`) followed by the answer paragraph.
 */
export function extractFaq(markdown) {
  const lines = stripFrontmatter(markdown).split('\n')
  const items = []
  let inFaq = false
  for (let i = 0; i < lines.length; i += 1) {
    const heading = /^(#{2,3})\s+(.*)$/.exec(lines[i])
    if (heading) {
      const title = heading[2].replace(/\s*\{#.*\}\s*$/, '').trim()
      if (/^(faq|常见问题)$/i.test(title)) {
        inFaq = true
        continue
      }
      if (heading[1] === '##' && inFaq) break
    }
    if (!inFaq) continue
    const question = /^\*\*(.+?)\*\*\s*$/.exec(lines[i].trim())
    if (!question) continue
    const name = stripInlineMarkdown(question[1])
    const answer = []
    i += 1
    while (i < lines.length) {
      const line = lines[i]
      if (!line.trim()) {
        if (answer.length) break
        i += 1
        continue
      }
      if (/^\*\*(.+?)\*\*\s*$/.test(line.trim()) || /^#{2,3}\s+/.test(line)) {
        i -= 1
        break
      }
      answer.push(line.trim())
      i += 1
    }
    const text = stripInlineMarkdown(answer.join(' '))
    if (name && text) items.push({ name, text })
  }
  return items
}
