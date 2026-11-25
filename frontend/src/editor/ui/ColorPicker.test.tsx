import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
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
    let target = document.createElement('div').style as object | null
    let originalBackground: PropertyDescriptor | undefined
    while (target && !originalBackground) {
      originalBackground = Object.getOwnPropertyDescriptor(target, 'background')
      if (!originalBackground) target = Object.getPrototypeOf(target) as object | null
    }
    expect(originalBackground?.set).toBeDefined()
    if (!target || !originalBackground?.set) throw new Error('CSSStyleDeclaration.background setter is unavailable')
    const backgroundTarget = target
    const backgroundDescriptor = originalBackground

    const backgroundValues: string[] = []
    Object.defineProperty(backgroundTarget, 'background', {
      ...backgroundDescriptor,
      set(value: string) {
        backgroundValues.push(value)
        backgroundDescriptor.set?.call(this, value)
      },
    })

    try {
      render(<ColorPicker value="#ff0000" onChange={() => undefined} />)

      // JSDOM's CSS parser drops the modern space-separated hsl() syntax from style attributes.
      expect(backgroundValues).toContain(
        'linear-gradient(to top, #000, transparent), linear-gradient(to right, #fff, hsl(0 100% 50%))',
      )

      const alpha = screen.getByRole('slider', { name: 'Opacidade' })
      expect(alpha.getAttribute('style')).toMatch(
        /linear-gradient\(to right, transparent, (?:#ff0000|rgb\(255, 0, 0\))\)/,
      )
    } finally {
      Object.defineProperty(backgroundTarget, 'background', backgroundDescriptor)
    }
  })

  it('shows the eyedropper button when EyeDropper is available', () => {
    vi.stubGlobal('EyeDropper', class EyeDropperMock {})

    render(<ColorPicker value="#ff0000" onChange={() => undefined} />)

    expect(screen.getByRole('button', { name: 'Selecionar uma cor da tela' })).toBeInTheDocument()
  })

  it('commits only the final colour after previewing a drag', () => {
    const changes: string[] = []
    const commits: string[] = []
    render(<ColorPicker value="#ff0000" onChange={(color) => changes.push(color)} onCommit={(color) => commits.push(color)} />)
    const hue = screen.getByRole('slider', { name: 'Matiz' })

    fireEvent.change(hue, { target: { value: '30' } })
    fireEvent.change(hue, { target: { value: '60' } })
    fireEvent.change(hue, { target: { value: '90' } })
    expect(changes).toHaveLength(3)
    expect(commits).toEqual([])

    fireEvent.pointerUp(hue)
    expect(commits).toEqual([changes.at(-1)])

    fireEvent.blur(hue)
    expect(commits).toHaveLength(1)
  })

  it('saves the current colour through the explicit brand action', async () => {
    const onSaveColor = vi.fn().mockResolvedValue(undefined)
    render(<ColorPicker value="#ff0000" onChange={() => undefined} onSaveColor={onSaveColor} />)

    fireEvent.click(screen.getByRole('button', { name: 'Salvar cor no kit de marca' }))
    await waitFor(() => expect(onSaveColor).toHaveBeenCalledWith('#ff0000'))
  })

  it('does not commit an untouched control on blur', () => {
    const onCommit = vi.fn()
    render(<ColorPicker value="#ff0000" onChange={() => undefined} onCommit={onCommit} />)

    fireEvent.blur(screen.getByRole('slider', { name: 'Matiz' }))
    expect(onCommit).not.toHaveBeenCalled()
  })
})
