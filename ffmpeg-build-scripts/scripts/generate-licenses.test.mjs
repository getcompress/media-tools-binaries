#!/usr/bin/env node

// SPDX-FileCopyrightText: 2026 GetCompress contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const packageRoot = path.resolve(__dirname, '..')
const scriptPath = path.join(__dirname, 'generate-licenses.mjs')
const manifestPath = path.join(packageRoot, 'licenses.json')
const versionDir = path.join(packageRoot, 'version')
const buildScriptPath = path.join(packageRoot, 'build.sh')
const workflowUrl = 'https://example.test/workflow.yml'
const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'))
const buildOnlySkipMarkers = new Set([
  'skip-decklink',
  'skip-libiconv',
  'skip-sdl'
])

function normalizeText(text) {
  return text.replace(/\r\n/g, '\n').trim()
}

function templateValues(version) {
  return {
    version,
    version_major_minor: version.split('.').slice(0, 2).join('.'),
    package_version: `${version}-1`
  }
}

function renderTemplate(text, values) {
  return text.replace(/\{\{(\w+)\}\}/g, (_, key) => {
    assert.ok(key in values, `Missing test template value ${key}`)
    return values[key]
  })
}

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

async function readDependencyVersion(dependency) {
  if (dependency.version) {
    return normalizeText(String(dependency.version))
  }

  const versionKey = dependency.version_key ?? dependency.name
  return normalizeText(await fs.readFile(path.join(versionDir, versionKey), 'utf8'))
}

async function readBuildFixtureVersion(buildRoot, dependency) {
  if (dependency.version) {
    return normalizeText(String(dependency.version))
  }

  const versionKey = dependency.version_key ?? dependency.name
  const overridePath = path.join(buildRoot, 'log', versionKey, 'version')
  try {
    return normalizeText(await fs.readFile(overridePath, 'utf8'))
  } catch (error) {
    if (error.code !== 'ENOENT') {
      throw error
    }
  }

  return readDependencyVersion(dependency)
}

async function assertManifestIsValid() {
  assert.ok(Array.isArray(manifest.dependencies), 'Manifest dependencies must be an array')
  assert.ok(manifest.dependencies.length > 0, 'Manifest must contain dependencies')

  const names = new Set()
  const skipMarkers = new Set()
  for (const dependency of manifest.dependencies) {
    assert.equal(typeof dependency.name, 'string', 'Dependency name must be a string')
    assert.notEqual(dependency.name.trim(), '', 'Dependency name must not be empty')
    assert.equal(names.has(dependency.name), false, `Duplicate dependency name: ${dependency.name}`)
    names.add(dependency.name)

    assert.equal(typeof dependency.homepage, 'string', `${dependency.name} homepage must be a string`)
    assert.equal(typeof dependency.license_expression, 'string', `${dependency.name} license_expression must be a string`)
    assert.equal(typeof dependency.source_glob, 'string', `${dependency.name} source_glob must be a string`)
    assert.ok(Array.isArray(dependency.source_urls), `${dependency.name} source_urls must be an array`)
    assert.ok(dependency.source_urls.length > 0, `${dependency.name} source_urls must not be empty`)
    assert.ok(Array.isArray(dependency.license_files), `${dependency.name} license_files must be an array`)
    assert.ok(dependency.license_files.length > 0, `${dependency.name} license_files must not be empty`)

    if (dependency.version) {
      assert.equal(typeof dependency.version, 'string', `${dependency.name} version must be a string`)
      assert.notEqual(normalizeText(dependency.version), '', `${dependency.name} version must not be empty`)
      assert.equal('version_key' in dependency, false, `${dependency.name} must not define both version and version_key`)
    } else {
      const versionKey = dependency.version_key ?? dependency.name
      assert.equal(typeof versionKey, 'string', `${dependency.name} version_key must be a string`)
      const version = await readDependencyVersion(dependency)
      assert.notEqual(version, '', `${dependency.name} version file must not be empty`)
    }

    if (dependency.skip_marker) {
      assert.match(dependency.skip_marker, /^skip-[A-Za-z0-9_-]+$/, `${dependency.name} skip_marker has invalid format`)
      assert.equal(skipMarkers.has(dependency.skip_marker), false, `Duplicate skip_marker: ${dependency.skip_marker}`)
      skipMarkers.add(dependency.skip_marker)
    }
  }
}

async function assertBuildSkipMarkersAreCovered() {
  const buildScript = await fs.readFile(buildScriptPath, 'utf8')
  const buildMarkers = new Set()

  for (const line of buildScript.split('\n')) {
    const match = line.match(/^\s*echo\s+"(?:YES|NO)"\s+>\s+"\$LOG_DIR\/(skip-[A-Za-z0-9_-]+)"\s*$/)
    if (match) {
      buildMarkers.add(match[1])
    }
  }

  const manifestMarkers = new Set(
    manifest.dependencies
      .map((dependency) => dependency.skip_marker)
      .filter(Boolean)
  )

  for (const marker of manifestMarkers) {
    assert.ok(buildMarkers.has(marker), `Manifest skip_marker is never written by build.sh: ${marker}`)
  }

  for (const marker of buildMarkers) {
    if (!manifestMarkers.has(marker) && !buildOnlySkipMarkers.has(marker)) {
      throw new Error(`build.sh writes ${marker}, but licenses.json does not cover it and it is not build-only`)
    }
  }
}

async function assertBuildScriptVersionsExist() {
  const scriptDir = path.join(packageRoot, 'script')
  const entries = await fs.readdir(scriptDir, { withFileTypes: true })

  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.startsWith('build-') || !entry.name.endsWith('.sh')) {
      continue
    }

    const script = await fs.readFile(path.join(scriptDir, entry.name), 'utf8')
    const versionKeys = [...script.matchAll(/cat "\$SCRIPT_DIR\/\.\.\/version\/([^"]+)"/g)]
      .map((match) => match[1])

    for (const versionKey of versionKeys) {
      const versionPath = path.join(versionDir, versionKey)
      const version = normalizeText(await fs.readFile(versionPath, 'utf8'))
      assert.notEqual(version, '', `${entry.name} reads empty version file: ${versionPath}`)
    }
  }
}

async function writeFileWithParents(filePath, contents) {
  await fs.mkdir(path.dirname(filePath), { recursive: true })
  await fs.writeFile(filePath, contents, 'utf8')
}

async function createSourceFixture(buildRoot, dependency) {
  const version = await readBuildFixtureVersion(buildRoot, dependency)
  const sourceGlob = renderTemplate(dependency.source_glob, templateValues(version))
  const sourceDir = path.join(buildRoot, sourceGlob.replace(/\*/g, 'fixture'))
  await fs.mkdir(sourceDir, { recursive: true })

  for (const relativeLicensePath of dependency.license_files) {
    await writeFileWithParents(
      path.join(sourceDir, relativeLicensePath),
      `license text for ${dependency.name} ${relativeLicensePath}\n`
    )
  }
}

async function createBuildFixture(activeOptionalDependencies = [], buildLocalMetadata = {}) {
  const buildRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'generate-licenses-test-'))
  const activeOptionalDependencyNames = new Set(activeOptionalDependencies)

  await fs.mkdir(path.join(buildRoot, 'log'), { recursive: true })
  for (const [versionKey, values] of Object.entries(buildLocalMetadata)) {
    const metadataDir = path.join(buildRoot, 'log', versionKey)
    await fs.mkdir(metadataDir, { recursive: true })
    for (const [key, value] of Object.entries(values)) {
      await fs.writeFile(path.join(metadataDir, key), `${value}\n`)
    }
  }

  for (const dependency of manifest.dependencies) {
    if (dependency.skip_marker) {
      const isActive = activeOptionalDependencyNames.has(dependency.name)
      await fs.writeFile(path.join(buildRoot, 'log', dependency.skip_marker), isActive ? 'NO\n' : 'YES\n')
      if (!isActive) {
        continue
      }
    }

    await createSourceFixture(buildRoot, dependency)
  }

  return buildRoot
}

async function runGenerator(buildRoot) {
  const outputDir = path.join(buildRoot, 'dist')
  const licensesPath = path.join(outputDir, 'LICENSES-ALL.md')
  const sourcesPath = path.join(outputDir, 'SOURCES.md')
  const result = spawnSync(process.execPath, [scriptPath, buildRoot, licensesPath, sourcesPath, workflowUrl], {
    encoding: 'utf8'
  })

  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`)

  return {
    licenses: await fs.readFile(licensesPath, 'utf8'),
    sources: await fs.readFile(sourcesPath, 'utf8')
  }
}

await assertManifestIsValid()
await assertBuildSkipMarkersAreCovered()
await assertBuildScriptVersionsExist()

const skippedBuildRoot = await createBuildFixture()
const skippedOutput = await runGenerator(skippedBuildRoot)
assert.match(skippedOutput.licenses, /#### Used by: ffmpeg /)
assert.doesNotMatch(skippedOutput.licenses, /#### Used by: x264 /)
assert.match(skippedOutput.sources, new RegExp(escapeRegExp(workflowUrl)))
await fs.rm(skippedBuildRoot, { recursive: true, force: true })

const x264BuildRoot = await createBuildFixture(['x264'])
const x264Output = await runGenerator(x264BuildRoot)
assert.match(x264Output.licenses, /#### Used by: x264 master https:\/\/code\.videolan\.org\/videolan\/x264/)
assert.match(x264Output.sources, /### Source Code: x264 master/)
await fs.rm(x264BuildRoot, { recursive: true, force: true })

const libiconvBuildRoot = await createBuildFixture(['libiconv'], {
  libiconv: {
    version: '1.18',
    package_version: '1.18-1',
    package_name: 'mingw-w64-clang-aarch64-libiconv'
  }
})
const libiconvOutput = await runGenerator(libiconvBuildRoot)
assert.match(libiconvOutput.licenses, /#### Used by: libiconv 1\.18 https:\/\/www\.gnu\.org\/software\/libiconv\//)
assert.match(libiconvOutput.licenses, /### License: LGPL-2\.1-or-later/)
assert.match(libiconvOutput.licenses, /license text for libiconv COPYING\.LIB/)
assert.doesNotMatch(libiconvOutput.licenses, /license text for libiconv COPYING\n/)
assert.doesNotMatch(libiconvOutput.licenses, /### License: .*GPL-3\.0-or-later/)
assert.match(libiconvOutput.sources, /### Source Code: libiconv 1\.18/)
assert.match(libiconvOutput.sources, /mingw-w64-libiconv-1\.18-1\.src\.tar\.zst/)
await fs.rm(libiconvBuildRoot, { recursive: true, force: true })

for (const dependency of manifest.dependencies.filter((candidate) => candidate.skip_marker)) {
  const buildRoot = await createBuildFixture([dependency.name])
  const output = await runGenerator(buildRoot)
  assert.match(output.licenses, new RegExp(`#### Used by: ${escapeRegExp(dependency.name)} `))
  assert.match(output.sources, new RegExp(`### Source Code: ${escapeRegExp(dependency.name)} `))
  await fs.rm(buildRoot, { recursive: true, force: true })
}

console.log('generate-licenses tests passed')
