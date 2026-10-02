#!/usr/bin/env node
// Renders the real output of statusline.sh into docs/statusline.svg.
import { execFileSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const repo = join(mkdtempSync(join(tmpdir(), 'statusline-')), 'my-project')
mkdirSync(repo)
execFileSync('git', ['-C', repo, 'init', '-q', '-b', 'main'])
for (const name of ['a', 'b', 'c']) writeFileSync(join(repo, name), name)

const now = Math.floor(Date.now() / 1000)
const input = {
  model: { display_name: 'Opus' },
  effort: { level: 'high' },
  workspace: { current_dir: repo },
  context_window: { used_percentage: 42.6, total_input_tokens: 85200, context_window_size: 200000 },
  cost: { total_lines_added: 120, total_lines_removed: 34, total_duration_ms: 4380000 },
  rate_limits: {
    five_hour: { used_percentage: 63, resets_at: now + 2 * 3600 + 41 * 60 + 30 },
    seven_day: { used_percentage: 87.2, resets_at: now + 3 * 86400 + 4 * 3600 + 30 },
  },
}
const output = execFileSync('bash', [join(root, 'statusline.sh')], {
  input: JSON.stringify(input),
  encoding: 'utf8',
})

const DEFAULT = '#c9d1d9'
const ANSI = { 31: '#f14c4c', 32: '#3fb950', 35: '#bc8cff', 36: '#39c5cf', 90: '#6e7681' }

function segments(line) {
  const out = []
  let style = { fill: DEFAULT, bold: false, dim: false }
  for (const m of line.matchAll(/\x1b\[([0-9;]*)m|([^\x1b]+)/g)) {
    if (m[2] !== undefined) {
      out.push({ ...style, text: m[2] })
      continue
    }
    const codes = m[1].split(';').map(Number)
    if (m[1] === '' || codes[0] === 0) style = { fill: DEFAULT, bold: false, dim: false }
    else if (codes[0] === 1) style = { ...style, bold: true }
    else if (codes[0] === 2) style = { ...style, dim: true }
    else if (codes[0] === 38 && codes[1] === 2) style = { ...style, fill: `rgb(${codes[2]},${codes[3]},${codes[4]})` }
    else if (ANSI[codes[0]]) style = { ...style, fill: ANSI[codes[0]] }
  }
  return out
}

const escapeXml = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
const lines = output.split('\n')
const lineHeight = 24
const pad = 18
const width = 680
const height = pad * 2 + lineHeight * lines.length

const rows = lines
  .map((line, i) => {
    const spans = segments(line)
      .map((s) => `<tspan fill="${s.fill}"${s.bold ? ' font-weight="bold"' : ''}${s.dim ? ' opacity="0.6"' : ''}>${escapeXml(s.text)}</tspan>`)
      .join('')
    return `<text x="${pad + 2}" y="${pad + lineHeight * (i + 1) - 7}" xml:space="preserve">${spans}</text>`
  })
  .join('\n    ')

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" role="img" aria-label="The four lines of the status line: model, folder and git branch, context window, 5-hour and 7-day usage gauges">
  <title>claude-statusline</title>
  <rect width="100%" height="100%" rx="8" fill="#0d1117"/>
  <g font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', monospace" font-size="15">
    ${rows}
  </g>
</svg>
`

mkdirSync(join(root, 'docs'), { recursive: true })
writeFileSync(join(root, 'docs', 'statusline.svg'), svg)
