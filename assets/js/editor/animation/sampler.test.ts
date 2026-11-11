import { describe, expect, it } from 'vitest'
import { sampleObject } from './sampler'

const animatedObject = {
  id: 'title', type: 'textbox', left: 100, top: 80,
  animation: {
    enter: { preset: 'fade', durationMs: 500, delayMs: 100, easing: 'linear' as const },
    exit: { preset: 'fade', durationMs: 400, delayMs: 1_500, easing: 'linear' as const },
  },
}

describe('animation sampler', () => {
  it('samples deterministic enter, rest, and exit states', () => {
    expect(sampleObject(animatedObject, 0).opacity).toBe(0)
    expect(sampleObject(animatedObject, 350).opacity).toBe(0.5)
    expect(sampleObject(animatedObject, 1000).opacity).toBe(1)
    expect(sampleObject(animatedObject, 1700).opacity).toBe(0.5)
    expect(sampleObject(animatedObject, 1900).opacity).toBe(0)
  })

  it('uses emphasis delay as an absolute page timestamp', () => {
    const object = {
      id: 'pulse', type: 'rect',
      animation: {
        enter: { preset: 'fade', durationMs: 500, delayMs: 0, easing: 'linear' as const },
        emphasis: { preset: 'pulse', durationMs: 500, delayMs: 600, easing: 'linear' as const },
      },
    }
    expect(sampleObject(object, 750).scaleX).toBeGreaterThan(1)
  })

  it('keeps an object without known presets in its resting state', () => {
    expect(sampleObject({ id: 'static', type: 'rect' }, 0)).toMatchObject({ opacity: 1, tx: 0, ty: 0, scaleX: 1, scaleY: 1 })
    expect(sampleObject({ id: 'future', type: 'rect', animation: { enter: { preset: 'future-effect', durationMs: 500, delayMs: 0, easing: 'linear' } } }, 0)).toMatchObject({ opacity: 1 })
  })
})
