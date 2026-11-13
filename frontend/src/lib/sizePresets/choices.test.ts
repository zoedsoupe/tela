import { afterEach, describe, expect, it } from 'vitest'
import { getSizeChoices, loadSizeChoices, noteUsedSize, setCollapsed, setSizeChoicesForTests, subscribeSizeChoices, togglePinned } from './choices'

afterEach(() => localStorage.removeItem("tela.sizeChoices"))

describe('local size choices', () => {
  it('loads and saves pinned, recent and collapsed choices in this browser', async () => {
    localStorage.setItem("tela.sizeChoices", JSON.stringify({ pinned: ['a4'], recent: ['poster'], collapsed: [] }))
    await loadSizeChoices(true)
    expect(getSizeChoices()).toEqual({ pinned: ['a4'], recent: ['poster'], collapsed: [] })
    togglePinned('logo', ['a4'])
    setCollapsed(['social'])
    noteUsedSize('poster')
    expect(JSON.parse(localStorage.getItem("tela.sizeChoices")!)).toEqual({ pinned: ['a4', 'logo'], recent: ['poster'], collapsed: ['social'] })
  })

  it('refuses a pin past the limit instead of dropping an existing size', () => {
    const full = Array.from({ length: 24 }, (_, index) => `size-${index}`)
    setSizeChoicesForTests({ pinned: full })
    expect(togglePinned('poster', [])).toBe(false)
    expect(getSizeChoices().pinned).toEqual(full)
  })

  it('notifies subscribers after local changes', () => {
    let notifications = 0
    const stop = subscribeSizeChoices(() => notifications++)
    setCollapsed(['print'])
    stop()
    expect(notifications).toBe(1)
  })
})
