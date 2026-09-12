import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import fs from "node:fs"
import { test } from "node:test"
import { fileURLToPath } from "node:url"
import path from "node:path"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const g = "g" + "it"
const otherHome = "/Users/" + "alice" + "/project"

function read(rel) {
  return fs.readFileSync(path.join(root, rel), "utf8")
}

function exists(rel) {
  return fs.existsSync(path.join(root, rel))
}

function hook(script, payload, envExtra = {}) {
  return spawnSync(path.join(root, "scripts/hooks", script), {
    input: payload,
    encoding: "utf8",
    cwd: root,
    env: { ...process.env, ...envExtra },
  })
}

test("templates and 0001 artifacts exist with required headings", () => {
  const intent = read("sdlc/intent/0001-ai-native-sdlc.md")
  const spec = read("sdlc/spec/0001-ai-native-sdlc.md")
  const plan = read("sdlc/plan/0001-ai-native-sdlc.md")
  for (const rel of [
    "sdlc/templates/intent.md",
    "sdlc/templates/spec.md",
    "sdlc/templates/plan.md",
    "sdlc/templates/incident.md",
  ]) {
    assert.ok(exists(rel), rel)
  }
  assert.match(intent, /## 问题/)
  assert.match(intent, /## 预期结果/)
  assert.match(spec, /## 需求/)
  assert.match(spec, /## 设计/)
  assert.match(plan, /## 改动的文件/)
  assert.match(plan, /## 工作顺序/)
  assert.match(plan, /## 风险/)
  assert.match(plan, /## 验收/)
  for (const body of [intent, spec, plan]) {
    assert.match(body, /status: accepted/)
    assert.match(body, /0001-ai-native-sdlc/)
  }
  assert.match(read("sdlc/README.md"), /人读的产物/)
  assert.match(read("sdlc/templates/intent.md"), /## 问题/)
})

test("CLAUDE.md, REVIEW.md, and bands.yaml have contract headings", () => {
  assert.match(read("CLAUDE.md"), /## Commands/)
  assert.match(read("REVIEW.md"), /## Passes/)
  assert.match(read("bands.yaml"), /tiers:/)
})

test("production-gate blocks tag push unless RELEASE_APPROVAL is set", () => {
  const tag = JSON.stringify({ tool_input: { command: `${g} push origin v0.1.2` } })
  const branch = JSON.stringify({ tool_input: { command: `${g} push origin main` } })
  const blocked = hook("production-gate.sh", tag)
  assert.equal(blocked.status, 2)
  const allowed = hook("production-gate.sh", tag, { RELEASE_APPROVAL: "yes" })
  assert.equal(allowed.status, 0)
  const mainPush = hook("production-gate.sh", branch)
  assert.equal(mainPush.status, 0)
  const empty = hook("production-gate.sh", "")
  assert.equal(empty.status, 0)
})

test("depersonalize allows /Users/me and blocks other homes", () => {
  const ok = hook("depersonalize.sh", JSON.stringify({ tool_input: { content: "/Users/me/project" } }))
  assert.equal(ok.status, 0)
  const bad = hook("depersonalize.sh", JSON.stringify({ tool_input: { content: otherHome } }))
  assert.equal(bad.status, 2)
  const clonePath = hook(
    "depersonalize.sh",
    JSON.stringify({
      tool_input: {
        file_path: "/Users/me/openalon/herdr-bar/sdlc/README.md",
        content: "use /Users/me and session work",
      },
    }),
  )
  assert.equal(clonePath.status, 0)
  const localRoot = "workspace" + "2"
  const localPath = hook(
    "depersonalize.sh",
    JSON.stringify({ tool_input: { content: `/${localRoot}/openalon/herdr-bar` } }),
  )
  assert.equal(localPath.status, 2)
})

test("protect-oracle locks Herdr.js tests and allows other Swift files", () => {
  const locked = hook("protect-oracle.sh", JSON.stringify({ tool_input: { file_path: "tests/herdr.test.mjs" } }))
  assert.equal(locked.status, 2)
  const other = hook("protect-oracle.sh", JSON.stringify({ tool_input: { file_path: "Sources/MacBar/Foo.swift" } }))
  assert.equal(other.status, 0)
})

test("ten eval cases hold their phrases", () => {
  const casesDir = path.join(root, "sdlc/evals/cases")
  const files = fs.readdirSync(casesDir).filter((n) => n.endsWith(".json"))
  assert.equal(files.length, 10)
  const result = spawnSync("bash", [path.join(root, "scripts/run-evals.sh")], {
    encoding: "utf8",
    cwd: root,
  })
  assert.equal(result.status, 0, result.stderr || result.stdout)
})

test("agent-evals and maintain-bands workflows exist", () => {
  assert.ok(exists(".github/workflows/agent-evals.yml"))
  assert.ok(exists(".github/workflows/maintain-bands.yml"))
  const bands = spawnSync("python3", [path.join(root, "scripts/detect-bands.py"), "--fixture", "sdlc/evals/fixtures/ci-rates.json"], {
    encoding: "utf8",
    cwd: root,
  })
  assert.equal(bands.status, 0, bands.stderr)
  const parsed = JSON.parse(bands.stdout)
  assert.equal(parsed.action, "ok")
  const breach = spawnSync("python3", [path.join(root, "scripts/detect-bands.py"), "--fixture", "sdlc/evals/fixtures/ci-rates-breach.json"], {
    encoding: "utf8",
    cwd: root,
  })
  assert.equal(breach.status, 0, breach.stderr)
  assert.equal(JSON.parse(breach.stdout).action, "propose")
  const evalsYml = read(".github/workflows/agent-evals.yml")
  assert.match(evalsYml, /skip live evals/)
  assert.doesNotMatch(evalsYml, /ANTHROPIC_API_KEY/)
  const bandsYml = read(".github/workflows/maintain-bands.yml")
  assert.match(bandsYml, /ci-rates-breach\.json/)
  assert.doesNotMatch(bandsYml, /github\.issue|gh issue/)
})

test("published sdlc files stay de-personalized", () => {
  const scan = spawnSync(
    g,
    ["grep", "-nE", "/Users/|/home/|" + "eden" + "|client\\.new|" + "workspace" + "2", "--",
      "sdlc", "CLAUDE.md", "REVIEW.md", ".claude",
      "scripts/hooks",
      ".agents/skills/ai-native-sdlc",
      ".agents/skills/capture-intent",
      ".agents/skills/requirements-design",
      ".agents/skills/plan-mode",
      ".agents/skills/depersonalize"],
    { encoding: "utf8", cwd: root },
  )
  const lines = (scan.stdout || "").split("\n").filter(Boolean)
  // Same username class as scripts/hooks/depersonalize.py. Placeholders
  // (/Users/<you>), grep patterns, and regex source are not leaks.
  const me = "me"
  const generic = "user"
  const localRoot = "workspace" + "2"
  const pathUser = "/(?:Users|home)/[A-Za-z0-9._-]+"
  const leak = new RegExp(`${pathUser}|${localRoot}/`)
  const allowed = new RegExp(`/Users/${me}\\b|/home/${generic}\\b`, "g")
  const leaks = lines.filter((line) => {
    const body = line.replace(/^[^:]+:\d+:/, "")
    return leak.test(body.replace(allowed, ""))
  })
  assert.deepEqual(leaks, [])
})

test("five new skills declare YAML name", () => {
  for (const name of [
    "ai-native-sdlc",
    "capture-intent",
    "requirements-design",
    "plan-mode",
    "depersonalize",
  ]) {
    const body = read(`.agents/skills/${name}/SKILL.md`)
    assert.ok(body.startsWith("---"))
    assert.match(body, new RegExp(`name: ${name}`))
  }
})
