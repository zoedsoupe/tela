export type Theme = 'light' | 'dark'

export const THEME_QUERY = '(prefers-color-scheme: dark)'

function systemTheme(): Theme {
  return typeof window.matchMedia === 'function' && window.matchMedia(THEME_QUERY).matches ? 'dark' : 'light'
}

let sessionTheme: Theme | null = null
let dispose: (() => void) | null = null

function applyTheme(root: HTMLElement = document.documentElement): Theme {
  const theme = sessionTheme ?? systemTheme()
  if (root.dataset.theme !== theme) root.dataset.theme = theme
  return theme
}

/** Temporarily sets a theme for this page session; pass null to follow the system preference again. */
export function setSessionTheme(theme: Theme | null): void {
  sessionTheme = theme
  applyTheme()
}

/**
 * Applies the system preference before the first render, then follows OS changes. Repeated calls share one listener.
 * The returned disposer is safe to call more than once.
 */
export function initTheme(): () => void {
  if (dispose) return dispose

  applyTheme()
  const update = (): void => {
    applyTheme()
  }
  const media = typeof window.matchMedia === 'function' ? window.matchMedia(THEME_QUERY) : null
  if (media?.addEventListener) media.addEventListener('change', update)
  else media?.addListener?.(update)

  let done = false
  const off = (): void => {
    if (done) return
    done = true
    if (media?.removeEventListener) media.removeEventListener('change', update)
    else media?.removeListener?.(update)
    if (dispose === off) dispose = null
  }
  dispose = off
  return off
}
