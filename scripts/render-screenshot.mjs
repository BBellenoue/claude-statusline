#!/usr/bin/env node
// Renders the real output of statusline.sh into docs/statusline.svg, inside a mock terminal window.
// The project, branch, conversation and numbers are made up.
import { execFileSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const repo = join(mkdtempSync(join(tmpdir(), 'statusline-')), 'shop-api')
mkdirSync(repo)
execFileSync('git', ['-C', repo, 'init', '-q', '-b', 'feat/order-pagination'])
for (const name of ['a', 'b', 'c']) writeFileSync(join(repo, name), name)

const now = Math.floor(Date.now() / 1000)
const input = {
  model: { display_name: 'Opus 5.5' },
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
const MUTED = '#6e7681'
const ANSI = { 31: '#f14c4c', 32: '#3fb950', 35: '#bc8cff', 36: '#39c5cf', 90: MUTED }

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
const tspan = (s) =>
  `<tspan fill="${s.fill}"${s.bold ? ' font-weight="bold"' : ''}${s.dim ? ' opacity="0.6"' : ''}>${escapeXml(s.text)}</tspan>`
const plain = (text, extra = {}) => ({ fill: DEFAULT, bold: false, dim: false, text, ...extra })

const conversation = [
  [plain('> ', { fill: MUTED }), plain('add pagination to the orders endpoint')],
  [],
  [plain('● ', { fill: '#3fb950' }), plain('I will add page and limit query parameters, then cap the page size.')],
  [plain('● ', { fill: '#3fb950' }), plain('Update', { bold: true }), plain('(src/orders/orders.controller.ts)')],
  [plain('  ⎿  Updated src/orders/orders.controller.ts with 12 additions and 3 removals', { fill: MUTED })],
]
const statusLines = output.split('\n')

const width = 760
const pad = 22
const lineHeight = 22
const titleHeight = 36
const convTop = titleHeight + 16
const boxTop = convTop + lineHeight * conversation.length + 12
const boxHeight = 38
const statusTop = boxTop + boxHeight + 12
const height = statusTop + lineHeight * statusLines.length + 18
const baseline = (top, i) => top + lineHeight * (i + 1) - 7

const textRow = (segs, y) => `<text x="${pad}" y="${y}" xml:space="preserve">${segs.map(tspan).join('')}</text>`
const rows = [
  ...conversation.map((segs, i) => textRow(segs, baseline(convTop, i))),
  textRow([plain('> ', { fill: MUTED }), plain('Try "write a test for the orders service"', { fill: MUTED })], boxTop + 24),
  ...statusLines.map((line, i) => textRow(segments(line), baseline(statusTop, i))),
].join('\n    ')

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" role="img" aria-label="A terminal window: a short Claude Code exchange above the four-line status line with model, folder and git branch, context window, 5-hour and 7-day usage gauges">
  <title>claude-statusline</title>
  <rect x="0.5" y="0.5" width="${width - 1}" height="${height - 1}" rx="10" fill="#010409" stroke="#30363d"/>
  <path d="M0.5 ${titleHeight} V10.5 a10 10 0 0 1 10 -10 H${width - 10.5} a10 10 0 0 1 10 10 V${titleHeight} Z" fill="#161b22" stroke="#30363d"/>
  <circle cx="22" cy="18" r="6" fill="#ff5f56"/>
  <circle cx="42" cy="18" r="6" fill="#ffbd2e"/>
  <circle cx="62" cy="18" r="6" fill="#27c93f"/>
  <text x="${width / 2}" y="23" text-anchor="middle" font-family="system-ui, -apple-system, 'Segoe UI', sans-serif" font-size="13" fill="#8b949e">shop-api · claude</text>
  <rect x="${pad - 10}" y="${boxTop}" width="${width - 2 * pad + 20}" height="${boxHeight}" rx="7" fill="none" stroke="#3b434d"/>
  <g font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', monospace" font-size="15">
    ${rows}
  </g>
</svg>
`

mkdirSync(join(root, 'docs'), { recursive: true })
writeFileSync(join(root, 'docs', 'statusline.svg'), svg)
