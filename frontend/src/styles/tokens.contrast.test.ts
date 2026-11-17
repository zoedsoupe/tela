import { readFileSync } from 'node:fs'
import { resolve as resolvePath } from 'node:path'
import { contrastRatio, parseColor, type Rgba } from '@/editor/engine/colors'

/**
 * The high-contrast block in tokens.css, checked against the WCAG contrast formula on every surface the chrome uses,
 * and held to colours only. The stylesheet is read from disk as text: with `css: false` a `?raw` import of it is empty.
 */
const tokensCss = readFileSync(resolvePath(__dirname, 'tokens.css'), 'utf-8')
const globalCss = readFileSync(resolvePath(__dirname, 'global.css'), 'utf-8')

function block(selector: string, source = tokensCss): Record<string, string> {
  const css = source.replace(/\/\*[\s\S]*?\*\//g, '')
  const start = css.indexOf(`${selector} {`)
  if (start < 0) throw new Error(`no ${selector} block`)
  const body = css.slice(start + selector.length + 2, css.indexOf('}', start))
  const props: Record<string, string> = {}
  for (const [, name, value] of body.matchAll(/([\w-]+)\s*:\s*([^;]+);/g)) props[name] = value.trim()
  return props
}

const base = block(':root')
const more = block(":root[data-contrast='more']")
const dark = block(":root[data-theme='dark']")
const darkMore = block(":root[data-theme='dark'][data-contrast='more']")
const baseAliases = block(':root', globalCss)
const darkAliases = block(":root[data-theme='dark']", globalCss)
const lightTheme = { ...base, ...more }
const darkTheme = { ...base, ...dark }
const darkHighContrastTheme = { ...base, ...dark, ...more, ...darkMore }

function resolve(value: string, theme: Record<string, string>): string {
  return value.replace(/var\((--[\w-]+)\)/g, (_, name: string) => resolve(theme[name] ?? '', theme))
}

function color(name: string, theme: Record<string, string> = lightTheme): Rgba {
  const parsed = parseColor(resolve(theme[name] ?? '', theme))
  if (!parsed) throw new Error(`${name} is not a colour`)
  return parsed
}

const SURFACES = ['--color-surface', '--color-bg', '--color-bg-subtle', '--color-bg-muted', '--color-canvas-workspace', '--color-brand-soft', '--color-brand-soft-hover']

function lowest(foreground: Rgba, surfaces = SURFACES, theme: Record<string, string> = lightTheme): number {
  return Math.min(...surfaces.map((surface) => contrastRatio(foreground, color(surface, theme))))
}

describe('high-contrast tokens', () => {
  it('only overrides colour tokens that the light theme defines', () => {
    expect(Object.keys(more).length).toBeGreaterThan(0)
    for (const name of Object.keys(more)) {
      expect(base, name).toHaveProperty(name)
      expect(name).toMatch(/^--(color-|focus-ring$|selection-color$|guide-color$|accent-|shadow-artboard$)/)
    }
  })

  it('leaves the page, workspace, stage and transparency checkerboard alone, and stays light', () => {
    for (const name of ['--color-bg', '--color-canvas-workspace', '--color-stage', '--color-on-stage', '--color-checker', 'color-scheme']) expect(more).not.toHaveProperty(name)
  })

  it('keeps every text colour at 7:1 or more on every surface', () => {
    for (const name of ['--color-text', '--color-text-muted', '--color-text-subtle']) {
      expect(lowest(color(name), SURFACES, lightTheme), name).toBeGreaterThanOrEqual(7)
    }
  })

  it('keeps lines, the focus ring, selection and guides at 3:1 or more', () => {
    const ring = parseColor(resolve(more['--focus-ring'], lightTheme).split(/\s+/).pop() ?? '')
    expect(ring).not.toBeNull()
    expect(lowest(ring as Rgba), '--focus-ring').toBeGreaterThanOrEqual(3)
    for (const name of ['--color-border', '--color-border-strong', '--selection-color', '--guide-color']) {
      expect(lowest(color(name)), name).toBeGreaterThanOrEqual(3)
    }
  })

  it('keeps tracks told apart from the ink that fills them (switches, sliders, progress bars)', () => {
    for (const name of ['--color-border', '--color-border-strong']) expect(contrastRatio(color(name), color('--color-brand')), name).toBeGreaterThanOrEqual(3)
  })

  it('keeps the status colours at 6:1 or more on the surface and on their own wash', () => {
    for (const status of ['success', 'warning', 'danger', 'info']) {
      expect(lowest(color(`--color-${status}`), ['--color-surface', `--color-${status}-soft`]), status).toBeGreaterThanOrEqual(6)
    }
  })

  it('keeps the password meter score readable: its empty segments are --color-bg-muted in high contrast', () => {
    for (const status of ['success', 'warning']) expect(contrastRatio(color(`--color-${status}`), color('--color-bg-muted')), status).toBeGreaterThanOrEqual(3)
  })

  it('makes muted text and borders darker than the standard theme', () => {
    const standard = (name: string): Rgba => parseColor(base[name]) as Rgba
    for (const name of ['--color-text-muted', '--color-text-subtle', '--color-border', '--color-border-strong']) {
      expect(lowest(color(name)), name).toBeGreaterThan(
        Math.min(...SURFACES.map((surface) => contrastRatio(standard(name), parseColor(resolve(base[surface], base)) as Rgba))),
      )
    }
  })

  it('keeps dark chrome neutral and does not retheme stage, checkerboard or artwork shadows', () => {
    expect(dark['color-scheme']).toBe('dark')
    expect(base['color-scheme']).toBe('light')
    for (const name of ['--color-stage', '--color-on-stage', '--color-checker', '--shadow-artboard']) {
      expect(dark, name).not.toHaveProperty(name)
    }
    for (const name of ['--color-stage', '--color-on-stage', '--color-checker', '--shadow-artboard']) {
      expect(resolve(darkTheme[name], darkTheme), name).toBe(resolve(base[name], base))
    }
    expect(color('--color-bg', darkTheme).r).toBeLessThan(40)
    expect(color('--color-bg', darkTheme).b - color('--color-bg', darkTheme).r).toBeLessThan(10)
  })

  it('keeps dark high-contrast text readable on every dark surface', () => {
    for (const name of ['--color-text', '--color-text-muted', '--color-text-subtle']) {
      expect(lowest(color(name, darkHighContrastTheme), SURFACES, darkHighContrastTheme), name).toBeGreaterThanOrEqual(7)
    }
  })

  it('keeps dark high-contrast boundaries, selection and focus visible', () => {
    const ring = parseColor(resolve(darkMore['--focus-ring'], darkHighContrastTheme).split(/\s+/).pop() ?? '')
    expect(ring).not.toBeNull()
    expect(lowest(ring as Rgba, SURFACES, darkHighContrastTheme), '--focus-ring').toBeGreaterThanOrEqual(3)
    for (const name of ['--color-border', '--color-border-strong', '--selection-color', '--guide-color']) {
      expect(lowest(color(name, darkHighContrastTheme), SURFACES, darkHighContrastTheme), name).toBeGreaterThanOrEqual(3)
    }
  })

  it('keeps dark high-contrast status colours readable on their own soft surfaces', () => {
    for (const status of ['success', 'warning', 'danger', 'info']) {
      expect(
        lowest(color(`--color-${status}`, darkHighContrastTheme), ['--color-surface', `--color-${status}-soft`], darkHighContrastTheme),
        status,
      ).toBeGreaterThanOrEqual(6)
    }
  })

  it('keeps standard dark status colours readable on dark surfaces and their state washes', () => {
    for (const status of ['success', 'warning', 'danger', 'info']) {
      expect(
        lowest(color(`--color-${status}`, darkTheme), ['--color-surface', `--color-${status}-soft`], darkTheme),
        status,
      ).toBeGreaterThanOrEqual(4.5)
    }
  })

  it('keeps dark UI aliases on the semantic theme tokens', () => {
    const aliases = { ...darkTheme, ...baseAliases, ...darkAliases }
    for (const [alias, semantic] of [
      ['--color-brand-fill', '--color-brand'],
      ['--color-brand-fill-hover', '--color-brand-hover'],
      ['--color-brand-fill-active', '--color-brand-active'],
      ['--color-brand-strong', '--color-text'],
    ]) {
      expect(resolve(darkAliases[alias], aliases), alias).toBe(resolve(darkTheme[semantic], darkTheme))
    }
  })
})
