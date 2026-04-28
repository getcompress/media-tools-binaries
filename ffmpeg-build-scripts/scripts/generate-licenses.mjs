#!/usr/bin/env node

// SPDX-FileCopyrightText: 2026 GetCompress contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const [buildRootArg, licensesOutputArg, sourcesOutputArg, workflowUrl] = process.argv.slice(2)

if (!buildRootArg || !licensesOutputArg || !sourcesOutputArg || !workflowUrl) {
  throw new Error('Usage: generate-licenses.mjs <build-root> <licenses-output> <sources-output> <workflow-url>')
}

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const manifestPath = path.resolve(__dirname, '..', 'licenses.json')
const buildRoot = path.resolve(buildRootArg)
const licensesOutputPath = path.resolve(licensesOutputArg)
const sourcesOutputPath = path.resolve(sourcesOutputArg)
const logDir = path.join(buildRoot, 'log')
const versionDir = path.resolve(__dirname, '..', 'version')

const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'))

async function exists(targetPath) {
  try {
    await fs.access(targetPath)
    return true
  } catch {
    return false
  }
}

function normalizeText(text) {
  return text.replace(/\r\n/g, '\n').trim()
}

function escapeRegex(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

async function readVersion(dependency) {
  if (dependency.version) {
    return normalizeText(String(dependency.version))
  }

  const versionKey = dependency.version_key ?? dependency.name
  const versionPath = path.join(versionDir, versionKey)
  try {
    const version = normalizeText(await fs.readFile(versionPath, 'utf8'))
    if (!version) {
      throw new Error(`Version metadata for ${dependency.name} is empty: ${versionPath}`)
    }
    return version
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw new Error(
        `Missing version metadata for ${dependency.name}: expected ${versionPath}. ` +
        'Add a fixed "version" to licenses.json or create the matching version file.'
      )
    }
    throw error
  }
}

function templateValues(version) {
  return {
    version,
    version_major_minor: version.split('.').slice(0, 2).join('.')
  }
}

function renderTemplate(text, values) {
  return text.replace(/\{\{(\w+)\}\}/g, (_, key) => {
    if (!(key in values)) {
      throw new Error(`Missing template value ${key} for ${text}`)
    }
    return values[key]
  })
}

async function resolveSourceDir(sourceGlob) {
  const absolutePattern = path.join(buildRoot, sourceGlob)
  if (!absolutePattern.includes('*')) {
    return (await exists(absolutePattern)) ? absolutePattern : null
  }

  const parentDir = path.dirname(absolutePattern)
  if (!(await exists(parentDir))) {
    return null
  }

  const basenamePattern = path.basename(absolutePattern)
  const matcher = new RegExp(`^${basenamePattern.split('*').map(escapeRegex).join('.*')}$`)
  const entries = await fs.readdir(parentDir, { withFileTypes: true })
  const matches = entries
    .filter((entry) => entry.isDirectory() && matcher.test(entry.name))
    .map((entry) => path.join(parentDir, entry.name))
    .sort()

  if (matches.length === 0) {
    return null
  }
  if (matches.length > 1) {
    throw new Error(`Multiple source directories matched ${sourceGlob}: ${matches.join(', ')}`)
  }
  return matches[0]
}

async function isSkipped(dependency) {
  if (!dependency.skip_marker) {
    return false
  }

  const markerPath = path.join(logDir, dependency.skip_marker)
  if (!(await exists(markerPath))) {
    return false
  }

  return normalizeText(await fs.readFile(markerPath, 'utf8')) === 'YES'
}

function formatUsedBy(dependency, version) {
  const parts = [dependency.name]
  parts.push(version)
  if (dependency.homepage) {
    parts.push(dependency.homepage)
  }
  return parts.join(' ')
}

async function renderDependency(dependency) {
  if (await isSkipped(dependency)) {
    return null
  }

  const version = await readVersion(dependency)
  const values = templateValues(version)
  const sourceDir = await resolveSourceDir(renderTemplate(dependency.source_glob, values))
  if (!sourceDir) {
    throw new Error(
      `Missing source directory for active dependency ${dependency.name}: ` +
      `expected ${renderTemplate(dependency.source_glob, values)} under ${buildRoot}`
    )
  }

  const blocks = []
  for (const relativeLicensePath of dependency.license_files) {
    const absoluteLicensePath = path.join(sourceDir, relativeLicensePath)
    if (!(await exists(absoluteLicensePath))) {
      throw new Error(`Missing license file for ${dependency.name}: ${absoluteLicensePath}`)
    }

    const text = normalizeText(await fs.readFile(absoluteLicensePath, 'utf8'))
    blocks.push(`--- ${relativeLicensePath} ---\n${text}`)
  }

  const licensesSection = [
    `### License: ${dependency.license_expression}`,
    `#### Used by: ${formatUsedBy(dependency, version)}`,
    '#### License text:',
    '```',
    blocks.join('\n\n'),
    '```'
  ].join('\n')

  const renderedSourceUrls = dependency.source_urls.map((sourceUrl) => renderTemplate(sourceUrl, values))
  const sourcesLines = [
    `### Source Code: ${dependency.name} ${version}`,
    `This distribution includes ${dependency.name} built from source.`
  ]

  if (renderedSourceUrls.length === 1) {
    sourcesLines.push(`The complete corresponding code for this build is available at: ${renderedSourceUrls[0]}`)
  } else {
    sourcesLines.push('The complete corresponding code for this build is available from one of the source URLs used by the build script:')
    for (const sourceUrl of renderedSourceUrls) {
      sourcesLines.push(`- ${sourceUrl}`)
    }
  }
  sourcesLines.push(`The build script used for this distribution is available at: ${workflowUrl}`)

  return {
    licensesSection,
    sourcesSection: sourcesLines.join('\n')
  }
}

const licenseSections = []
const sourceSections = []
for (const dependency of manifest.dependencies) {
  const rendered = await renderDependency(dependency)
  if (rendered) {
    licenseSections.push(rendered.licensesSection)
    sourceSections.push(rendered.sourcesSection)
  }
}

if (licenseSections.length === 0 || sourceSections.length === 0) {
  throw new Error(`No license sections were generated from ${manifestPath}`)
}

await fs.mkdir(path.dirname(licensesOutputPath), { recursive: true })
await fs.mkdir(path.dirname(sourcesOutputPath), { recursive: true })
await fs.writeFile(licensesOutputPath, `${licenseSections.join('\n\n')}\n`, 'utf8')
await fs.writeFile(sourcesOutputPath, `${sourceSections.join('\n\n')}\n`, 'utf8')
