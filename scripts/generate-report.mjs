#!/usr/bin/env bun
// Spark Report Generator — Converts Markdown to a self-contained HTML report
// with sidebar navigation, scroll spy, responsive design, and refined typography.
// Zero npm dependencies. Reads from stdin or file arg, writes HTML to stdout.
// Forked from Anvil's generate-report.mjs, adapted for multi-persona ideation output.

import { readFileSync } from 'fs'

// --- Input ---
let markdown
if (process.argv[2]) {
  markdown = readFileSync(process.argv[2], 'utf-8')
} else {
  markdown = readFileSync('/dev/stdin', 'utf-8')
}

// --- Utilities ---

function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

function sanitizeHref(url) {
  const trimmed = url.trim()
  if (/^(https?:|mailto:|\/|#|\.)/i.test(trimmed)) return trimmed
  if (/^[a-z][a-z0-9+.-]*:/i.test(trimmed)) return '#blocked'
  return trimmed
}

function convertInline(text) {
  text = escapeHtml(text)
  text = text.replace(/`([^`]+)`/g, '<code>$1</code>')
  text = text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
  text = text.replace(/\*(.+?)\*/g, '<em>$1</em>')
  text = text.replace(/(?<!\w)_(.+?)_(?!\w)/g, '<em>$1</em>')
  text = text.replace(
    /\[([^\]]+)\]\(([^)]+)\)/g,
    (_, label, href) => `<a href="${sanitizeHref(href)}">${label}</a>`,
  )
  return text
}

function slugify(text) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
}

function parseMetadata(text) {
  const meta = {}
  const re = /\*\*(.+?)\*\*\s*:\s*([^|*]+)/g
  let m
  while ((m = re.exec(text)) !== null) {
    meta[m[1].trim().toLowerCase()] = m[2].trim()
  }
  return meta
}

function formatDate(str) {
  try {
    const d = new Date(str)
    if (isNaN(d.getTime())) return str
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ]
    return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`
  } catch {
    return str
  }
}

// --- Persona Color Management ---

const PERSONA_COLORS = [
  { name: 'teal', hex: '#2a7d6e', rgb: '42,125,110' },
  { name: 'amber', hex: '#b37d4e', rgb: '179,125,78' },
  { name: 'indigo', hex: '#5a5fa0', rgb: '90,95,160' },
  { name: 'rose', hex: '#b35a6e', rgb: '179,90,110' },
  { name: 'slate', hex: '#5a7d8a', rgb: '90,125,138' },
  { name: 'plum', hex: '#8a5a9a', rgb: '138,90,154' },
]

const personaColorMap = new Map()
let colorIndex = 0

function getPersonaColor(personaName) {
  if (!personaColorMap.has(personaName)) {
    personaColorMap.set(personaName, PERSONA_COLORS[colorIndex % PERSONA_COLORS.length])
    colorIndex++
  }
  return personaColorMap.get(personaName)
}

// --- Markdown Converter ---

function convertMarkdown(md) {
  const lines = md.split('\n')
  let i = 0
  let title = ''
  let metadata = null
  let foundMetadata = false
  let skippedFirstHr = false
  const tocItems = []
  const sectionHtmlChunks = []
  const preSectionHtml = []
  let cur = null
  let inPersona = false
  let inSynthesis = false

  function closeCurrent() {
    if (inPersona && cur) {
      cur.push('</div></div>')
      inPersona = false
    }
    if (inSynthesis && cur) {
      cur.push('</div>')
      inSynthesis = false
    }
  }

  function closeSection() {
    closeCurrent()
    if (cur) {
      cur.push('</section>')
      sectionHtmlChunks.push(cur.join('\n'))
      cur = null
    }
  }

  function emit(html) {
    if (cur) {
      cur.push(html)
    } else {
      preSectionHtml.push(html)
    }
  }

  // Detect phase and persona from H2 text
  function detectPhase(text) {
    const seedMatch = text.match(/^Seed:\s*(.+)$/i)
    if (seedMatch) return { phase: 'seed', persona: seedMatch[1].trim() }

    const crossMatch = text.match(/^Cross-Pollination(?:\s+Round\s+\d+)?:\s*(.+)$/i)
    if (crossMatch) return { phase: 'cross', persona: crossMatch[1].trim() }

    if (/^Session\s+Record$/i.test(text)) return { phase: 'session-record', persona: null }

    if (/^Synthesis$/i.test(text)) return { phase: 'synthesis', persona: null }

    return { phase: null, persona: null }
  }

  while (i < lines.length) {
    const line = lines[i]

    // --- Code blocks ---
    if (line.startsWith('```')) {
      const lang = line
        .slice(3)
        .trim()
        .replace(/[^a-zA-Z0-9_-]/g, '')
      const codeLines = []
      i++
      while (i < lines.length && !lines[i].startsWith('```')) {
        codeLines.push(escapeHtml(lines[i]))
        i++
      }
      if (i < lines.length) i++

      // Mermaid diagrams get special treatment
      if (lang === 'mermaid') {
        emit(`<div class="mermaid">${codeLines.join('\n')}</div>`)
      } else {
        const langAttr = lang ? ` class="language-${lang}"` : ''
        emit(`<pre><code${langAttr}>${codeLines.join('\n')}</code></pre>`)
      }
      continue
    }

    // --- Headings ---
    const hm = line.match(/^(#{1,4})\s+(.+)$/)
    if (hm) {
      const level = hm[1].length
      const text = hm[2]

      if (level === 1) {
        title = text
        i++
        continue
      }

      if (level === 2) {
        closeSection()
        const id = slugify(text)
        const { phase, persona } = detectPhase(text)
        let cls = ''
        if (phase === 'synthesis') cls = ' synthesis-section'
        if (phase === 'session-record') cls = ' session-record-section'

        cur = []
        cur.push(`<section id="${id}" class="section${cls}">`)
        cur.push(`<h2>${convertInline(text)}</h2>`)

        if (phase === 'synthesis') {
          cur.push('<div class="synthesis-callout">')
          inSynthesis = true
        }

        const tocPhase = phase || ''
        tocItems.push({ id, text, level: 2, phase: tocPhase, persona })
        i++
        continue
      }

      if (level === 3) {
        if (inPersona) {
          emit('</div></div>')
          inPersona = false
        }

        const parentToc = tocItems.filter((t) => t.level === 2).slice(-1)[0]
        const parentId = parentToc?.id || ''
        const id = parentId ? `${parentId}-${slugify(text)}` : slugify(text)

        // Check if parent section has a persona — H3s inside persona sections get persona styling
        const parentPersona = parentToc?.persona

        if (parentPersona) {
          const color = getPersonaColor(parentPersona)
          inPersona = true
          emit(
            `<div class="persona-section persona-${color.name}" id="${id}">`,
          )
          emit(
            `<h3><span class="persona-badge" style="color:${color.hex};background:rgba(${color.rgb},0.08)">${escapeHtml(text)}</span></h3>`,
          )
          emit('<div class="persona-content">')
        } else {
          emit(`<h3 id="${id}">${convertInline(text)}</h3>`)
        }
        tocItems.push({ id, text, level: 3, persona: parentPersona })
        i++
        continue
      }

      // h4
      emit(`<h4>${convertInline(text)}</h4>`)
      i++
      continue
    }

    // --- Blockquote (first = metadata) ---
    if (line.startsWith('>')) {
      const quoteLines = []
      while (i < lines.length && lines[i].startsWith('>')) {
        quoteLines.push(lines[i].replace(/^>\s?/, ''))
        i++
      }
      if (!foundMetadata && !cur) {
        const candidate = parseMetadata(quoteLines.join(' '))
        if (Object.keys(candidate).length > 0) {
          metadata = candidate
          foundMetadata = true
          continue
        }
      }
      emit(`<blockquote>${quoteLines.map(convertInline).join('<br>')}</blockquote>`)
      continue
    }

    // --- Horizontal rule ---
    if (/^---+$/.test(line.trim())) {
      if (foundMetadata && !skippedFirstHr && !cur) {
        skippedFirstHr = true
        i++
        continue
      }
      if (inSynthesis) {
        emit('</div>')
        inSynthesis = false
        i++
        continue
      }
      emit('<hr>')
      i++
      continue
    }

    // --- Tables ---
    if (line.includes('|') && line.trim().startsWith('|')) {
      const tableLines = []
      while (i < lines.length && lines[i].includes('|') && lines[i].trim().startsWith('|')) {
        tableLines.push(lines[i])
        i++
      }
      if (tableLines.length >= 2) {
        const hCells = tableLines[0].split('|').filter((c) => c.trim() !== '')
        let t = '<div class="table-wrap"><table><thead><tr>'
        for (const c of hCells) t += `<th>${convertInline(c.trim())}</th>`
        t += '</tr></thead><tbody>'
        for (let r = 2; r < tableLines.length; r++) {
          const cells = tableLines[r].split('|').filter((c) => c.trim() !== '')
          t += '<tr>'
          for (const c of cells) t += `<td>${convertInline(c.trim())}</td>`
          t += '</tr>'
        }
        t += '</tbody></table></div>'
        emit(t)
      }
      continue
    }

    // --- Unordered lists ---
    if (/^[-*]\s/.test(line.trim())) {
      let list = '<ul>'
      while (
        i < lines.length &&
        (/^[-*]\s/.test(lines[i].trim()) ||
          (lines[i].trim() === '' && i + 1 < lines.length && /^[-*]\s/.test(lines[i + 1]?.trim())))
      ) {
        if (lines[i].trim() === '') {
          i++
          continue
        }
        list += `<li>${convertInline(lines[i].trim().replace(/^[-*]\s+/, ''))}</li>`
        i++
      }
      list += '</ul>'
      emit(list)
      continue
    }

    // --- Ordered lists ---
    if (/^\d+\.\s/.test(line.trim())) {
      let list = '<ol>'
      while (
        i < lines.length &&
        (/^\d+\.\s/.test(lines[i].trim()) ||
          (lines[i].trim() === '' && i + 1 < lines.length && /^\d+\.\s/.test(lines[i + 1]?.trim())))
      ) {
        if (lines[i].trim() === '') {
          i++
          continue
        }
        list += `<li>${convertInline(lines[i].trim().replace(/^\d+\.\s+/, ''))}</li>`
        i++
      }
      list += '</ol>'
      emit(list)
      continue
    }

    // --- Blank line ---
    if (line.trim() === '') {
      i++
      continue
    }

    // --- Paragraph ---
    const paraLines = []
    while (
      i < lines.length &&
      lines[i].trim() !== '' &&
      !lines[i].startsWith('#') &&
      !lines[i].startsWith('```') &&
      !lines[i].startsWith('>') &&
      !/^[-*]\s/.test(lines[i].trim()) &&
      !/^\d+\.\s/.test(lines[i].trim()) &&
      !/^---+$/.test(lines[i].trim()) &&
      !(lines[i].includes('|') && lines[i].trim().startsWith('|'))
    ) {
      paraLines.push(lines[i])
      i++
    }
    if (paraLines.length > 0) {
      emit(`<p>${convertInline(paraLines.join('\n'))}</p>`)
    }
  }

  closeSection()
  return { sections: sectionHtmlChunks, preSectionHtml, tocItems, title, metadata }
}

// --- HTML Builders ---

function buildTocHtml(items) {
  if (items.length === 0) return ''
  let html = '<ul class="toc" id="toc">'
  for (const item of items) {
    const sub = item.level === 3 ? ' toc-sub' : ''
    let personaCls = ''
    if (item.persona) {
      const color = getPersonaColor(item.persona)
      personaCls = ` toc-persona-${color.name}`
    }
    html += `<li><a href="#${item.id}" class="toc-link${sub}${personaCls}" data-target="${item.id}">${escapeHtml(item.text)}</a></li>`
  }
  html += '</ul>'
  return html
}

function buildMetaBarHtml(meta) {
  if (!meta || Object.keys(meta).length === 0) return ''
  const displayOrder = ['personas', 'rounds', 'focus', 'date']
  const keys = [
    ...displayOrder.filter((k) => meta[k]),
    ...Object.keys(meta).filter((k) => !displayOrder.includes(k) && meta[k]),
  ]
  let html = '<div class="meta-bar">'
  for (const key of keys) {
    const val = meta[key]
    if (!val) continue
    const label = key.charAt(0).toUpperCase() + key.slice(1)
    const display = key === 'date' ? formatDate(val) : val
    html += `<div class="meta-item"><span class="meta-label">${escapeHtml(label)}</span><span class="meta-value">${escapeHtml(display)}</span></div>`
  }
  html += '</div>'
  return html
}

// --- Persona CSS variables ---

function buildPersonaCssVars() {
  let vars = ''
  for (const [, color] of personaColorMap) {
    vars += `
.persona-${color.name} {
  border-left-color: ${color.hex};
  background: linear-gradient(to right, rgba(${color.rgb},0.035), transparent 70%);
}
.toc-link.toc-persona-${color.name}::before {
  background: ${color.hex};
}
`
  }
  return vars
}

// --- CSS ---

const baseCss = `
:root {
  --bg-page: #f5f2eb;
  --bg-surface: #ffffff;
  --bg-sidebar: #18181b;
  --bg-sidebar-hover: rgba(255,255,255,0.06);
  --text: #1c1c1e;
  --text-secondary: #636366;
  --text-tertiary: #aeaeb2;
  --text-sidebar: #a1a1aa;
  --text-sidebar-active: #fafafa;
  --accent: #b37d4e;
  --accent-rgb: 179,125,78;
  --accent-light: rgba(179,125,78,0.06);
  --accent-border: rgba(179,125,78,0.25);
  --border: #d5d1ca;
  --border-light: #e8e4dd;
  --font-display: Georgia, "Noto Serif", "Times New Roman", serif;
  --font-body: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
  --font-mono: ui-monospace, "SF Mono", "Cascadia Code", Menlo, Consolas, monospace;
  --sidebar-w: 260px;
  --radius: 6px;
}

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

html { scroll-behavior: smooth; scroll-padding-top: 1.5rem; }

body {
  background: var(--bg-page);
  color: var(--text);
  font-family: var(--font-body);
  font-size: 0.925rem;
  line-height: 1.8;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* === Progress Bar === */
.progress-bar {
  position: fixed;
  top: 0; left: 0;
  width: 0%;
  height: 2px;
  background: linear-gradient(90deg, var(--accent), #d4a06a);
  z-index: 1000;
  transition: width 80ms linear;
  pointer-events: none;
}

/* === Sidebar === */
.sidebar {
  position: fixed;
  top: 0; left: 0;
  width: var(--sidebar-w);
  height: 100vh;
  background: var(--bg-sidebar);
  display: flex;
  flex-direction: column;
  z-index: 100;
  overflow-y: auto;
  overflow-x: hidden;
}

.sidebar::-webkit-scrollbar { width: 3px; }
.sidebar::-webkit-scrollbar-track { background: transparent; }
.sidebar::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.12); border-radius: 2px; }

.sidebar-brand {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid rgba(255,255,255,0.06);
  flex-shrink: 0;
}

.brand-mark {
  width: 8px; height: 8px;
  background: var(--accent);
  transform: rotate(45deg);
  flex-shrink: 0;
  border-radius: 1px;
}

.brand-text {
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.22em;
  color: var(--text-sidebar-active);
}

.toc { list-style: none; padding: 0.75rem 0; flex: 1; }
.toc li { margin: 0; }

.toc-link {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1.5rem;
  font-size: 0.78rem;
  color: var(--text-sidebar);
  text-decoration: none;
  border-left: 2px solid transparent;
  transition: all 0.15s ease;
  line-height: 1.5;
}

.toc-link:hover {
  color: var(--text-sidebar-active);
  background: var(--bg-sidebar-hover);
}

.toc-link.active {
  color: var(--text-sidebar-active);
  border-left-color: var(--accent);
  background: rgba(255,255,255,0.03);
}

.toc-link.toc-sub {
  padding-left: 2.25rem;
  font-size: 0.72rem;
}

/* Persona color dots in TOC */
.toc-link[class*="toc-persona-"]::before {
  content: "";
  width: 5px; height: 5px;
  border-radius: 50%;
  flex-shrink: 0;
}

.sidebar-footer {
  padding: 0.75rem 1.5rem;
  font-size: 0.6rem;
  color: rgba(255,255,255,0.2);
  border-top: 1px solid rgba(255,255,255,0.06);
  flex-shrink: 0;
  letter-spacing: 0.04em;
}

/* === Burger Menu === */
.burger {
  display: none;
  position: fixed;
  top: 0.75rem; right: 0.75rem;
  z-index: 300;
  width: 38px; height: 38px;
  background: var(--bg-surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  cursor: pointer;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  transition: box-shadow 0.2s ease;
  padding: 0;
}

.burger:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.12); }

.burger span {
  display: block;
  width: 16px; height: 1.5px;
  background: var(--text);
  border-radius: 1px;
  transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
}

.burger.active span:nth-child(1) { transform: translateY(5.5px) rotate(45deg); }
.burger.active span:nth-child(2) { opacity: 0; transform: scaleX(0); }
.burger.active span:nth-child(3) { transform: translateY(-5.5px) rotate(-45deg); }

/* === Overlay === */
.overlay {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.35);
  z-index: 50;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.3s ease;
  backdrop-filter: blur(2px);
  -webkit-backdrop-filter: blur(2px);
}

/* === Back to Top === */
.back-to-top {
  position: fixed;
  bottom: 1.5rem; right: 1.5rem;
  z-index: 90;
  width: 36px; height: 36px;
  background: var(--bg-surface);
  border: 1px solid var(--border);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  opacity: 0;
  transform: translateY(8px);
  transition: all 0.25s ease;
  pointer-events: none;
  padding: 0;
}

.back-to-top.visible {
  opacity: 1;
  transform: translateY(0);
  pointer-events: auto;
}

.back-to-top:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  border-color: var(--accent);
}

.back-to-top svg {
  width: 16px; height: 16px;
  stroke: var(--text-secondary);
  fill: none;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

/* === Content === */
.content {
  margin-left: var(--sidebar-w);
  min-height: 100vh;
  padding: 3rem 3rem 4rem;
}

article {
  max-width: 700px;
  margin: 0 auto;
  counter-reset: spark-section;
}

/* === Report Header === */
.report-header {
  margin-bottom: 3rem;
  padding-bottom: 2rem;
  border-bottom: 1px solid var(--border-light);
}

.report-eyebrow {
  font-size: 0.62rem;
  font-weight: 700;
  letter-spacing: 0.2em;
  color: var(--accent);
  margin-bottom: 0.4rem;
}

.report-header h1 {
  font-family: var(--font-display);
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--text);
  letter-spacing: -0.01em;
  line-height: 1.35;
  margin-bottom: 1.25rem;
}

.meta-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 0;
  background: var(--bg-page);
  border-radius: var(--radius);
  border: 1px solid var(--border-light);
  overflow: hidden;
}

.meta-item {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  padding: 0.6rem 1rem;
  border-right: 1px solid var(--border-light);
  min-width: 0;
}

.meta-item:last-child { border-right: none; }

.meta-label {
  font-size: 0.58rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-tertiary);
}

.meta-value {
  font-size: 0.82rem;
  color: var(--text);
  font-weight: 500;
}

/* === Sections === */
.section > h2 {
  font-family: var(--font-body);
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.14em;
  color: var(--text-secondary);
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding-bottom: 0.65rem;
  border-bottom: 1px solid var(--border);
  margin-top: 3rem;
  margin-bottom: 1.5rem;
}

.section > h2::before {
  counter-increment: spark-section;
  content: counter(spark-section, decimal-leading-zero);
  font-family: var(--font-mono);
  font-size: 0.62rem;
  color: var(--accent);
  font-weight: 400;
  letter-spacing: 0;
}

.section:first-child > h2 { margin-top: 0; }

/* === Synthesis Callout === */
.synthesis-callout {
  background: linear-gradient(135deg, rgba(var(--accent-rgb),0.05), rgba(var(--accent-rgb),0.015));
  border: 1px solid var(--accent-border);
  border-left: 3px solid var(--accent);
  border-radius: 0 var(--radius) var(--radius) 0;
  padding: 1.25rem 1.5rem;
}

.synthesis-callout p:last-child { margin-bottom: 0; }

/* === Persona Sections === */
.persona-section {
  border-left: 3px solid var(--border);
  padding: 1rem 1.5rem;
  margin: 1.25rem 0;
  border-radius: 0 var(--radius) var(--radius) 0;
}

.persona-section h3 { margin: 0 0 0.75rem; }

.persona-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-family: var(--font-body);
  font-size: 0.62rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  padding: 0.2rem 0.55rem;
  border-radius: 3px;
}

.persona-badge::before {
  content: "";
  width: 5px; height: 5px;
  border-radius: 50%;
  background: currentColor;
}

.persona-content > p:last-child { margin-bottom: 0; }

/* === Typography === */
h3 {
  font-family: var(--font-display);
  font-size: 1.05rem;
  font-weight: 600;
  color: var(--text);
  margin-top: 1.5rem;
  margin-bottom: 0.5rem;
  line-height: 1.4;
}

h4 {
  font-family: var(--font-body);
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--text-secondary);
  margin-top: 1.25rem;
  margin-bottom: 0.4rem;
}

p { margin-bottom: 1rem; }
strong { font-weight: 600; }

a {
  color: var(--accent);
  text-decoration: none;
  transition: color 0.15s ease;
}

a:hover { text-decoration: underline; }

/* === Blockquotes === */
blockquote {
  border-left: 3px solid var(--border);
  padding: 0.6rem 1rem;
  margin: 1.25rem 0;
  color: var(--text-secondary);
  font-size: 0.9rem;
  font-style: italic;
  border-radius: 0 var(--radius) var(--radius) 0;
  background: rgba(0,0,0,0.015);
}

/* === Code === */
code {
  font-family: var(--font-mono);
  font-size: 0.84em;
  background: rgba(0,0,0,0.04);
  padding: 0.15em 0.4em;
  border-radius: 3px;
}

pre {
  background: #1e1e22;
  color: #d4d4d8;
  border-radius: var(--radius);
  padding: 1.15rem 1.25rem;
  overflow-x: auto;
  margin: 1.25rem 0;
  font-size: 0.84rem;
  line-height: 1.6;
  border: 1px solid rgba(255,255,255,0.04);
}

pre code {
  background: none;
  padding: 0;
  font-size: inherit;
  color: inherit;
}

/* === Mermaid === */
.mermaid {
  margin: 1.25rem 0;
  text-align: center;
}

/* === Lists === */
ul, ol { margin: 0.5rem 0 1.25rem 1.5rem; }
li { margin-bottom: 0.35rem; line-height: 1.7; }
li::marker { color: var(--text-tertiary); }

/* === Tables === */
.table-wrap { overflow-x: auto; margin: 1.25rem 0; }

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

th {
  text-align: left;
  padding: 0.55rem 0.85rem;
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-secondary);
  border-bottom: 2px solid var(--border);
}

td {
  padding: 0.5rem 0.85rem;
  border-bottom: 1px solid var(--border-light);
}

tbody tr:hover { background: var(--accent-light); }

/* === Horizontal Rule === */
hr {
  border: none;
  height: 1px;
  background: var(--border-light);
  margin: 2rem 0;
}

/* === Responsive === */
@media (max-width: 1024px) {
  .sidebar {
    transform: translateX(-100%);
    transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    z-index: 200;
  }

  .sidebar.open {
    transform: translateX(0);
    box-shadow: 4px 0 24px rgba(0,0,0,0.25);
  }

  .content { margin-left: 0; padding: 2rem 1.5rem 3rem; }
  .burger { display: flex; }
  .overlay { display: block; }
  .overlay.visible { opacity: 1; pointer-events: auto; }
  .back-to-top { bottom: 1rem; right: 1rem; }
}

@media (max-width: 640px) {
  .content { padding: 1.25rem 1rem 2.5rem; }
  .report-header h1 { font-size: 1.25rem; }
  .meta-bar { flex-direction: column; }
  .meta-item {
    border-right: none;
    border-bottom: 1px solid var(--border-light);
    padding: 0.45rem 0.85rem;
    flex-direction: row;
    align-items: center;
    gap: 0.5rem;
  }
  .meta-item:last-child { border-bottom: none; }
  .meta-label { min-width: 55px; }
  .persona-section { padding: 0.75rem 1rem; }
  pre { font-size: 0.8rem; padding: 0.9rem 1rem; }
  table { font-size: 0.82rem; }
}

/* === Print === */
@media print {
  .sidebar, .burger, .overlay, .progress-bar, .back-to-top { display: none !important; }
  .content { margin-left: 0 !important; padding: 0 !important; }
  body { background: #fff; font-size: 10pt; }
  article { max-width: 100%; }
  .report-header { border-bottom-color: #ccc; }
  .report-header h1 { font-size: 14pt; }
  .report-eyebrow { color: #666; }
  .meta-bar { background: #f5f5f5; border-color: #ddd; }
  .meta-item { border-color: #ddd; }
  a { color: var(--text); }
  a[href]::after { content: " (" attr(href) ")"; font-size: 0.8em; color: #666; }
  pre { background: #f5f5f5; color: #333; border: 1px solid #ddd; }
  h2, h3, h4 { page-break-after: avoid; }
  pre, table, blockquote, .persona-section, .synthesis-callout { page-break-inside: avoid; }
  .synthesis-callout { background: #faf7f0; border-left-color: #999; border-color: #ddd; }
  .persona-section { background: none; border-left-color: #999; }
  .section > h2::before { color: #999; }
  .section > h2 { border-bottom-color: #ccc; }
}
`

// --- Client JS ---

const clientJs = `
(function(){
  var sidebar = document.getElementById("sidebar");
  var burger = document.getElementById("burger");
  var overlay = document.getElementById("overlay");
  var progress = document.getElementById("progress");
  var backTop = document.getElementById("back-to-top");
  var tocLinks = [].slice.call(document.querySelectorAll(".toc-link"));

  function toggleMenu() {
    var open = sidebar.classList.toggle("open");
    overlay.classList.toggle("visible", open);
    burger.classList.toggle("active", open);
  }

  if (burger) burger.addEventListener("click", toggleMenu);
  if (overlay) overlay.addEventListener("click", toggleMenu);

  document.addEventListener("keydown", function(e) {
    if (e.key === "Escape" && sidebar.classList.contains("open")) toggleMenu();
  });

  tocLinks.forEach(function(link) {
    link.addEventListener("click", function(e) {
      e.preventDefault();
      var el = document.getElementById(this.getAttribute("data-target"));
      if (el) {
        el.scrollIntoView({ behavior: "smooth", block: "start" });
        if (sidebar.classList.contains("open")) toggleMenu();
      }
    });
  });

  var targets = [];
  tocLinks.forEach(function(link) {
    var el = document.getElementById(link.getAttribute("data-target"));
    if (el) targets.push({ el: el, link: link });
  });

  function updateSpy() {
    var y = window.scrollY + 100;
    var active = null;
    for (var i = 0; i < targets.length; i++) {
      if (targets[i].el.offsetTop <= y) active = targets[i];
    }
    tocLinks.forEach(function(l) { l.classList.remove("active"); });
    if (active) {
      active.link.classList.add("active");
      if (window.innerWidth > 1024) {
        var linkRect = active.link.getBoundingClientRect();
        var sidebarRect = sidebar.getBoundingClientRect();
        if (linkRect.top < sidebarRect.top + 60 || linkRect.bottom > sidebarRect.bottom - 40) {
          active.link.scrollIntoView({ block: "center", behavior: "smooth" });
        }
      }
    }
  }

  function updateProgress() {
    var h = document.documentElement;
    var max = h.scrollHeight - h.clientHeight;
    var pct = max > 0 ? (h.scrollTop / max) * 100 : 0;
    progress.style.width = pct + "%";
    if (backTop) {
      backTop.classList.toggle("visible", h.scrollTop > 400);
    }
  }

  if (backTop) {
    backTop.addEventListener("click", function() {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
  }

  var ticking = false;
  window.addEventListener("scroll", function() {
    if (!ticking) {
      window.requestAnimationFrame(function() {
        updateSpy();
        updateProgress();
        ticking = false;
      });
      ticking = true;
    }
  });

  updateSpy();
  updateProgress();
})();
`

// --- Assembly ---

const { sections, preSectionHtml, tocItems, title, metadata } = convertMarkdown(markdown)
const pageTitle = title || 'Spark Report'

// Strip "Spark Report: " prefix for the visual h1 (eyebrow already says it)
let displayTitle = title
const titlePrefix = 'Spark Report: '
if (displayTitle.startsWith(titlePrefix)) {
  displayTitle = displayTitle.slice(titlePrefix.length)
} else if (displayTitle.startsWith('Spark Report:')) {
  displayTitle = displayTitle.slice('Spark Report:'.length).trim()
}

// Build persona-specific CSS after markdown conversion (colors are assigned during parsing)
const personaCss = buildPersonaCssVars()

// Check if any mermaid blocks were used
const hasMermaid =
  sections.some((s) => s.includes('class="mermaid"')) ||
  preSectionHtml.some((s) => s.includes('class="mermaid"'))

const mermaidScript = hasMermaid
  ? '\n<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></' +
    'script>\n<script>mermaid.initialize({ startOnLoad: true, theme: "neutral" });</' +
    'script>'
  : ''

const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escapeHtml(pageTitle)}</title>
<style>${baseCss}${personaCss}</style>
</head>
<body>
<div class="progress-bar" id="progress"></div>
<nav class="sidebar" id="sidebar">
<div class="sidebar-brand"><span class="brand-mark"></span><span class="brand-text">SPARK</span></div>
${buildTocHtml(tocItems)}
<div class="sidebar-footer">Generated by Spark</div>
</nav>
<button class="burger" id="burger" aria-label="Toggle navigation"><span></span><span></span><span></span></button>
<div class="overlay" id="overlay"></div>
<main class="content">
<article>
<header class="report-header">
<div class="report-eyebrow">SPARK REPORT</div>
<h1>${convertInline(displayTitle)}</h1>
${buildMetaBarHtml(metadata)}
</header>
${preSectionHtml.join('\n')}
${sections.join('\n')}
</article>
</main>
<button class="back-to-top" id="back-to-top" aria-label="Back to top"><svg viewBox="0 0 24 24"><path d="M18 15l-6-6-6 6"/></svg></button>
<script>${clientJs}</script>${mermaidScript}
</body>
</html>`

process.stdout.write(html)
