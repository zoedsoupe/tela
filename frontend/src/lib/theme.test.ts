import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { initTheme, setSessionTheme, THEME_QUERY } from './theme'

type MediaListener = (event: MediaQueryListEvent) => void

function mediaQuery(matches: boolean) {
  const listeners = new Set<MediaListener>()
  let currentMatches = matches
  const addEventListener = vi.fn((_type: string, listener: MediaListener) => listeners.add(listener))
  const removeEventListener = vi.fn((_type: string, listener: MediaListener) => listeners.delete(listener))
  const media = {
    get matches() {
      return currentMatches
    },
    media: THEME_QUERY,
    onchange: null,
    addEventListener,
    removeEventListener,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    dispatch(next: boolean) {
      currentMatches = next
      const event = { matches: next, media: THEME_QUERY } as MediaQueryListEvent
      for (const listener of listeners) listener(event)
    },
  } as unknown as MediaQueryList & {
    dispatch(next: boolean): void
    addEventListener: ReturnType<typeof vi.fn>
    removeEventListener: ReturnType<typeof vi.fn>
  }

  return media
}

let cleanup: (() => void) | undefined
let media: ReturnType<typeof mediaQuery>

beforeEach(() => {
  document.documentElement.removeAttribute('data-theme')
  media = mediaQuery(false)
  vi.stubGlobal('matchMedia', vi.fn(() => media))
})

afterEach(() => {
  cleanup?.()
  cleanup = undefined
  setSessionTheme(null)
  document.documentElement.removeAttribute('data-theme')
  vi.unstubAllGlobals()
})

describe('system theme', () => {
  it('defaults to light when the system does not request dark mode', () => {
    cleanup = initTheme()

    expect(document.documentElement.dataset.theme).toBe('light')
    expect(window.matchMedia).toHaveBeenCalledWith(THEME_QUERY)
  })

  it('starts in dark mode when the system requests it', () => {
    media.dispatch(true)
    cleanup = initTheme()

    expect(document.documentElement.dataset.theme).toBe('dark')
  })

  it('follows system preference changes', () => {
    cleanup = initTheme()

    media.dispatch(true)
    expect(document.documentElement.dataset.theme).toBe('dark')

    media.dispatch(false)
    expect(document.documentElement.dataset.theme).toBe('light')
  })

  it('only sets the theme attribute and supports a session override', () => {
    document.documentElement.dataset.contrast = 'more'
    cleanup = initTheme()
    setSessionTheme('dark')

    expect(document.documentElement.dataset.theme).toBe('dark')
    expect(document.documentElement.dataset.contrast).toBe('more')

    setSessionTheme(null)
    expect(document.documentElement.dataset.theme).toBe('light')
  })

  it('shares one media listener and has an idempotent disposer', () => {
    const firstCleanup = initTheme()
    const secondCleanup = initTheme()

    expect(secondCleanup).toBe(firstCleanup)
    expect(media.addEventListener).toHaveBeenCalledTimes(1)

    firstCleanup()
    firstCleanup()
    expect(media.removeEventListener).toHaveBeenCalledTimes(1)

    cleanup = initTheme()
    expect(media.addEventListener).toHaveBeenCalledTimes(2)
  })
})
