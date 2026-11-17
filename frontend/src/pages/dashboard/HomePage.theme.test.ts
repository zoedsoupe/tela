import { readFileSync } from 'node:fs'
import { resolve as resolvePath } from 'node:path'
import { contrastRatio, parseColor, type Rgba } from '@/editor/engine/colors'

const homeCss = readFileSync(resolvePath(__dirname, 'HomePage.module.css'), 'utf-8')
const tokensCss = readFileSync(resolvePath(__dirname, '../../styles/tokens.css'), 'utf-8')
const globalCss = readFileSync(resolvePath(__dirname, '../../styles/global.css'), 'utf-8')

function block(selector: string, source: string): Record<string, string> {
  const css = source.replace(/\/\*[\s\S]*?\*\//g, '')
  const start = css.indexOf(`${selector} {`)
  if (start < 0) throw new Error(`no ${selector} block`)
  const body = css.slice(start + selector.length + 2, css.indexOf('}', start))
  const props: Record<string, string> = {}
  for (const [, name, value] of body.matchAll(/([\w-]+)\s*:\s*([^;]+);/g)) props[name] = value.trim()
  return props
}

function resolve(value: string, variables: Record<string, string>): string {
  return value.replace(/var\((--[\w-]+)\)/g, (_, name: string) => resolve(variables[name] ?? '', variables))
}

function color(value: string): Rgba {
  const parsed = parseColor(value)
  if (!parsed) throw new Error(`${value} is not a colour`)
  return parsed
}

const light = block(':root', tokensCss)
const dark = { ...light, ...block(":root[data-theme='dark']", tokensCss) }
const darkGlobal = { ...block(':root', globalCss), ...block(":root[data-theme='dark']", globalCss) }
const hero = block('.hero', homeCss)
const chip = block('.chip', homeCss)
const allSizes = block('.allSizes', homeCss)

describe('dashboard home hero theme', () => {
  it('keeps the original light hero gradient and sizes wash in semantic tokens', () => {
    expect(resolve(light['--color-home-hero-start'], light)).toBe('#efeaff')
    expect(resolve(light['--color-home-hero-middle'], light)).toBe('#f6f0ff')
    expect(resolve(light['--color-home-hero-end'], light)).toBe('#fdeef3')
    expect(resolve(light['--color-home-hero-sizes-bg'], light)).toBe('rgb(255 255 255 / 0.55)')
    expect(resolve(light['--color-home-hero-sizes-border'], light)).toBe(resolve(light['--color-border-strong'], light))
  })

  it('uses only semantic background tokens for the hero and all-sizes chip', () => {
    expect(hero.background.replace(/\s+/g, ' ')).toBe(
      'linear-gradient( 120deg, var(--color-home-hero-start) 0%, var(--color-home-hero-middle) 55%, var(--color-home-hero-end) 100% )',
    )
    expect(hero.background).not.toMatch(/#[\da-f]{3,8}|rgba?\(/i)
    expect(allSizes.background).toBe('var(--color-home-hero-sizes-bg)')
    expect(allSizes.border).toBe('1.5px dashed var(--color-home-hero-sizes-border)')
  })

  it('keeps the dark title, links, chips and all-sizes control at readable contrast', () => {
    const title = color(resolve(dark['--color-text'], dark))
    const link = color(resolve(darkGlobal['--color-brand-strong'], { ...dark, ...darkGlobal }))
    const chipText = color(resolve(chip.color, dark))
    const chipSurface = color(resolve(chip.background, dark))
    const sizesText = color(resolve(darkGlobal['--color-brand-strong'], { ...dark, ...darkGlobal }))
    const sizesSurface = color(resolve(allSizes.background, dark))

    for (const stop of ['--color-home-hero-start', '--color-home-hero-middle', '--color-home-hero-end']) {
      const background = color(resolve(dark[stop], dark))
      expect(contrastRatio(title, background), stop).toBeGreaterThanOrEqual(7)
      expect(contrastRatio(link, background), stop).toBeGreaterThanOrEqual(7)
    }

    expect(contrastRatio(chipText, chipSurface)).toBeGreaterThanOrEqual(7)
    expect(contrastRatio(sizesText, sizesSurface)).toBeGreaterThanOrEqual(7)
    expect(contrastRatio(color(resolve(dark['--color-home-hero-sizes-border'], dark)), sizesSurface)).toBeGreaterThanOrEqual(3)
  })
})
