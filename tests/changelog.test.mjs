import assert from "node:assert/strict"
import { execFileSync } from "node:child_process"
import fs from "node:fs"
import { test } from "node:test"
import { fileURLToPath } from "node:url"
import path from "node:path"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const changelogPath = path.join(root, "CHANGELOG.md")
const notesScript = path.join(root, "scripts/changelog-notes.sh")

function parseChangelog(markdown) {
  const versions = []
  let current = null
  let currentSection = null

  for (const line of markdown.split("\n")) {
    const versionMatch = line.match(/^## \[(.+?)\] - (.+)$/)
    if (versionMatch) {
      if (current) versions.push(current)
      current = { version: versionMatch[1], date: versionMatch[2], sections: [] }
      currentSection = null
      continue
    }
    if (!current) continue

    const sectionMatch = line.match(/^### (.+)$/)
    if (sectionMatch) {
      currentSection = { heading: sectionMatch[1], items: [] }
      current.sections.push(currentSection)
      continue
    }

    const itemMatch = line.match(/^- (.+)$/)
    if (itemMatch) {
      if (!currentSection) {
        currentSection = { heading: "", items: [] }
        current.sections.push(currentSection)
      }
      currentSection.items.push(itemMatch[1])
    }
  }
  if (current) versions.push(current)
  return versions
}

function notes(version) {
  return execFileSync(notesScript, [version], { encoding: "utf8", cwd: root })
}

test("CHANGELOG.md is Keep a Changelog with newest first", () => {
  const markdown = fs.readFileSync(changelogPath, "utf8")
  const versions = parseChangelog(markdown)
  assert.ok(versions.length >= 3, "expected at least 0.1.0, 0.1.1, and 0.1.2")
  assert.equal(versions[0].version, "0.1.2")
  assert.equal(versions[1].version, "0.1.1")
  assert.equal(versions[2].version, "0.1.0")
  for (const release of versions) {
    assert.match(release.version, /^\d+\.\d+\.\d+$/)
    assert.match(release.date, /^\d{4}-\d{2}-\d{2}$/)
    assert.ok(release.sections.length > 0, `${release.version} has no sections`)
    const headings = release.sections.map((section) => section.heading)
    for (const heading of headings) {
      assert.match(
        heading,
        /^(Added|Changed|Fixed|Removed|Thanks to \d+ contributors?!)$/,
        `${release.version} unexpected heading: ${heading}`,
      )
    }
    const thanks = release.sections.filter((section) => section.heading.startsWith("Thanks"))
    assert.equal(thanks.length, 1, `${release.version} needs one Thanks section`)
    assert.ok(thanks[0].items.length > 0, `${release.version} Thanks list is empty`)
  }
})

test("changelog-notes.sh extracts one version and fails closed", () => {
  const latest = notes("v0.1.2")
  assert.match(latest, /### Added/)
  assert.match(latest, /WidgetKit/)
  assert.doesNotMatch(latest, /## \[0\.1\.2\]/)
  assert.doesNotMatch(latest, /## \[0\.1\.1\]/)
  assert.equal(notes("0.1.2"), latest)

  const body = notes("v0.1.1")
  assert.match(body, /### Changed/)
  assert.match(body, /elapsed time/)
  assert.doesNotMatch(body, /## \[0\.1\.1\]/)
  assert.doesNotMatch(body, /## \[0\.1\.0\]/)
  assert.equal(notes("0.1.1"), body)

  const initial = notes("0.1.0")
  assert.match(initial, /### Added/)
  assert.match(initial, /events\.subscribe/)

  assert.throws(() => notes("9.9.9"), /no ## \[9\.9\.9\] section/)
})

test("docs changelog pages include the root CHANGELOG.md", () => {
  const markdown = fs.readFileSync(changelogPath, "utf8")
  const firstVersionLine = markdown.split("\n").findIndex((line) => line.startsWith("## [")) + 1
  assert.equal(
    firstVersionLine,
    5,
    "docs/zh/changelog.md includes CHANGELOG.md{5,}; keep the header four lines so the first ## [version] stays on line 5",
  )
  const en = fs.readFileSync(path.join(root, "docs/changelog.md"), "utf8")
  const zh = fs.readFileSync(path.join(root, "docs/zh/changelog.md"), "utf8")
  assert.match(en, /<!--@include: \.\.\/CHANGELOG\.md-->/)
  assert.match(zh, /<!--@include: \.\.\/\.\.\/CHANGELOG\.md\{5,\}-->/)
})
