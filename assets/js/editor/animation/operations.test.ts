import { describe, expect, it } from 'vitest'
import { createDocument } from '../document/factory'
import { setObjectAnimation, setPageTransition } from './operations'

const withObject = () => {
  const doc = createDocument({ width: 1080, height: 1080 })
  doc.pages[0]!.objects.push({ id: 'title', type: 'textbox' })
  return doc
}

describe('animation operations', () => {
  it('sets, patches, and removes animation slots immutably', () => {
    const original = withObject()
    const animated = setObjectAnimation(original, original.pages[0]!.id, 'title', 'enter', { preset: 'fade', durationMs: 500, delayMs: 0, easing: 'linear' })
    expect(animated.pages[0]?.objects[0]?.animation?.enter).toMatchObject({ preset: 'fade', durationMs: 500 })
    expect(original.pages[0]?.objects[0]?.animation).toBeUndefined()
    const cleared = setObjectAnimation(animated, animated.pages[0]!.id, 'title', 'enter', null)
    expect(cleared.pages[0]?.objects[0]?.animation).toBeUndefined()
  })

  it('sets and clears page transitions', () => {
    const original = withObject()
    const transitioned = setPageTransition(original, original.pages[0]!.id, { preset: 'fade', durationMs: 300, easing: 'ease-in-out' })
    expect(transitioned.pages[0]?.transition).toMatchObject({ preset: 'fade', durationMs: 300 })
    expect(setPageTransition(transitioned, transitioned.pages[0]!.id, null).pages[0]?.transition).toBeUndefined()
  })
})
