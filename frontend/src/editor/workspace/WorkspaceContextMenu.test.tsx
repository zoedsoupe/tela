import { fireEvent, render } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { EditorProvider } from '../EditorProvider'
import { setupEditor } from '../animation/testing'
import { Workspace } from './Workspace'

class FakeResizeObserver {
  observe(): void {}
  disconnect(): void {}
}

describe('workspace context menu', () => {
  let dispose: (() => void) | null = null

  afterEach(() => {
    dispose?.()
    dispose = null
    vi.unstubAllGlobals()
  })

  async function mountWorkspace() {
    const { engine } = await setupEditor()
    dispose = () => engine.dispose()
    vi.stubGlobal('ResizeObserver', FakeResizeObserver)
    const rendered = render(
      <EditorProvider engine={engine} portalRoot={document.body}>
        <Workspace stripOpen={false} onToggleStrip={() => undefined} />
      </EditorProvider>,
    )
    const scroller = rendered.container.querySelector('[data-workspace-bg]') as HTMLDivElement
    return { ...rendered, scroller }
  }

  it('prevents the native menu for a descendant of the scroller', async () => {
    const { scroller } = await mountWorkspace()
    const descendant = scroller.querySelector('[data-workspace-bg]') as HTMLElement
    const observedEvents: Event[] = []
    const observeContextMenu = (event: Event): void => {
      observedEvents.push(event)
    }
    document.addEventListener('contextmenu', observeContextMenu)

    fireEvent.contextMenu(descendant)

    document.removeEventListener('contextmenu', observeContextMenu)
    expect(observedEvents[0]?.defaultPrevented).toBe(true)
  })

  it.each([
    ['input', () => document.createElement('input')],
    ['textarea', () => document.createElement('textarea')],
    ['contenteditable', () => {
      const element = document.createElement('div')
      element.setAttribute('contenteditable', 'true')
      return element
    }],
  ])('does not prevent the native menu on an editable %s', async (_name, createField) => {
    const { scroller } = await mountWorkspace()
    const field = createField()
    scroller.append(field)
    const observedEvents: Event[] = []
    const observeContextMenu = (event: Event): void => {
      observedEvents.push(event)
    }
    document.addEventListener('contextmenu', observeContextMenu)

    fireEvent.contextMenu(field)

    document.removeEventListener('contextmenu', observeContextMenu)
    expect(observedEvents[0]?.defaultPrevented).toBe(false)
    field.remove()
  })
})
