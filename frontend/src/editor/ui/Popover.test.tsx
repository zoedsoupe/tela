import { fireEvent, render, screen } from '@testing-library/react'
import { createRef } from 'react'
import { PortalContext } from '../context'
import { Popover } from './Popover'

describe('Popover positioning', () => {
  it('does not reposition for scroll events inside the panel', () => {
    const anchor = document.createElement('button')
    document.body.append(anchor)
    const anchorRef = createRef<HTMLElement>()
    anchorRef.current = anchor
    const getAnchorRect = vi.fn(() => ({
      left: 100,
      right: 140,
      top: 120,
      bottom: 150,
      width: 40,
      height: 30,
      x: 100,
      y: 120,
      toJSON: () => ({}),
    }))
    anchor.getBoundingClientRect = getAnchorRect

    render(
      <PortalContext.Provider value={document.body}>
        <Popover open onClose={() => undefined} anchorRef={anchorRef} label="Color picker">
          <div data-testid="scroll-content">Scrollable content</div>
        </Popover>
      </PortalContext.Provider>,
    )

    const panel = screen.getByRole('dialog', { name: 'Color picker' })
    const initialLeft = panel.style.left
    const initialTop = panel.style.top
    expect(initialLeft).toBe('100px')
    expect(initialTop).toBe('156px')

    getAnchorRect.mockReturnValue({
      left: 300,
      right: 340,
      top: 320,
      bottom: 350,
      width: 40,
      height: 30,
      x: 300,
      y: 320,
      toJSON: () => ({}),
    })
    fireEvent.scroll(screen.getByTestId('scroll-content'))

    expect(panel.style.left).toBe(initialLeft)
    expect(panel.style.top).toBe(initialTop)
    anchor.remove()
  })

  it('repositions on window resize', () => {
    const anchor = document.createElement('button')
    document.body.append(anchor)
    const anchorRef = createRef<HTMLElement>()
    anchorRef.current = anchor
    let anchorLeft = 100
    anchor.getBoundingClientRect = () =>
      ({
        left: anchorLeft,
        right: anchorLeft + 40,
        top: 120,
        bottom: 150,
        width: 40,
        height: 30,
        x: anchorLeft,
        y: 120,
        toJSON: () => ({}),
      }) as DOMRect

    render(
      <PortalContext.Provider value={document.body}>
        <Popover open onClose={() => undefined} anchorRef={anchorRef} label="Color picker">
          Picker contents
        </Popover>
      </PortalContext.Provider>,
    )

    const panel = screen.getByRole('dialog', { name: 'Color picker' })
    expect(panel.style.left).toBe('100px')

    anchorLeft = 240
    fireEvent(window, new Event('resize'))

    expect(panel.style.left).toBe('240px')
    anchor.remove()
  })
})
