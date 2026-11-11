import { describe, expect, it } from 'vitest'
import { emphasisPresets, inOutPresets, transitionPresets } from './presets'

describe('built-in animation presets', () => {
  it('ships the curated MVP collection', () => {
    expect([...inOutPresets.keys()].sort()).toEqual(['fade', 'pop', 'rise', 'slide', 'spin', 'wipe'])
    expect([...emphasisPresets.keys()].sort()).toEqual(['pulse', 'shake', 'sway'])
    expect([...transitionPresets.keys()].sort()).toEqual(['fade', 'slide', 'wipe'])
  })

  it('keeps enter effects hidden at zero and resting at one', () => {
    for (const [id, preset] of inOutPresets) {
      expect(preset.effect(0).opacity, id).toBe(0)
      expect(preset.effect(1), id).toMatchObject({ opacity: 1, scaleX: 1, scaleY: 1 })
    }
  })
})
