import { describe, expect, it } from 'vitest'
import { normalizeAnimation, pageDurationMs } from './model'

describe('animation model', () => {
  it('bounds timing values and supplies safe defaults', () => {
    expect(normalizeAnimation({ preset: 'fade', durationMs: 20, delayMs: -5, easing: 'invalid' })).toEqual({
      preset: 'fade', durationMs: 100, delayMs: 0, easing: 'ease-out',
    })
    expect(normalizeAnimation({ preset: 'fade', durationMs: 50_000, delayMs: 100_000 })).toMatchObject({
      durationMs: 10_000, delayMs: 60_000,
    })
  })

  it('rejects invalid preset identifiers', () => {
    expect(normalizeAnimation({ preset: 'not valid!' })).toBeNull()
    expect(normalizeAnimation(null)).toBeNull()
  })

  it('uses the longest finite animation and ignores looping emphasis for duration', () => {
    expect(pageDurationMs({ objects: [
      { id: 'one', type: 'text', animation: { enter: { preset: 'fade', durationMs: 500, delayMs: 400, easing: 'ease-out' } } },
      { id: 'two', type: 'rect', animation: { emphasis: { preset: 'pulse', durationMs: 800, delayMs: 0, easing: 'ease-out', loop: true } } },
    ] })).toBe(1000)
  })

  it('allows page duration to extend beyond animation timing', () => {
    expect(pageDurationMs({ durationSec: 4, objects: [] })).toBe(4000)
  })
})
