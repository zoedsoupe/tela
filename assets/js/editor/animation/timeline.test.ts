import { describe, expect, it } from 'vitest'
import { createDocument } from '../document/factory'
import { addPage } from '../document/operations'
import { buildTimeline, frameCount, gifDelayCs } from './timeline'

describe('animation timeline and GIF scheduling', () => {
  it('includes page bodies and transitions in document duration', () => {
    const original = createDocument({ width: 1920, height: 1080 })
    original.pages[0]!.durationSec = 1
    const doc = addPage(original)
    doc.pages[1]!.durationSec = 1
    doc.pages[1]!.transition = { preset: 'fade', durationMs: 300, easing: 'ease-in-out' }
    const timeline = buildTimeline(doc)
    expect(timeline.totalMs).toBe(2300)
    expect(timeline.segments.map((segment) => segment.kind)).toEqual(['page', 'transition', 'page'])
  })

  it('computes frames without cumulative floating point delays', () => {
    expect(frameCount(1000, 15)).toBe(15)
    expect(Array.from({ length: 15 }, (_, index) => gifDelayCs(index, 15, 1000)).reduce((a, b) => a + b, 0)).toBe(100)
  })
})
