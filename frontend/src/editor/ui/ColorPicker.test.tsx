import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { ColorPicker } from './ColorPicker'

vi.mock('../context', () => ({
  useDocument: () => ({ pages: [] }),
  useEditorStateShallow: () => [],
}))

vi.mock('../hooks/useCanvasIllustrationColors', () => ({
  useCanvasIllustrationColors: () => [],
}))

afterEach(() => {
  cleanup()
  vi.unstubAllGlobals()
})

describe('ColorPicker', () => {
  it('uses valid gradients for saturation and alpha controls', () => {
    const originalBackground = Object.getOwnPropertyDescriptor(CSSStyleDeclaration.prototype, 'background')
    expect(originalBackground?.set).toBeDefined()
    if (!originalBackground?.set) throw new Error('CSSStyleDeclaration.background setter is unavailable')

    const backgroundValues: string[] = []
    Object.defineProperty(CSSStyleDeclaration.prototype, 'background', {
      ...originalBackground,
      set(value: string) {
        backgroundValues.push(value)
        originalBackground.set?.call(this, value)
      },
    })

    try {
      render(<ColorPicker value="#ff0000" onChange={() => undefined} />)

      // JSDOM's CSS parser drops the modern space-separated hsl() syntax from style attributes.
      expect(backgroundValues).toContain(
        'linear-gradient(to top, #000, transparent), linear-gradient(to right, #fff, hsl(0 100% 50%))',
      )

      const alpha = screen.getByRole('slider', { name: 'Opacidade' })
      expect(alpha.getAttribute('style')).toContain(
        'linear-gradient(to right, transparent, #ff0000)',
      )
    } finally {
      Object.defineProperty(CSSStyleDeclaration.prototype, 'background', originalBackground)
    }
  })

  it('shows the eyedropper button when EyeDropper is available', () => {
    vi.stubGlobal('EyeDropper', class EyeDropperMock {})

    render(<ColorPicker value="#ff0000" onChange={() => undefined} />)

    expect(screen.getByRole('button', { name: 'Selecionar uma cor da tela' })).toBeInTheDocument()
  })
})
