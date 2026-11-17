import { cleanup, render, screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { afterEach, describe, expect, it } from "vitest"
import { createBlankDocument } from "@/lib/document"
import { createMemoryAdapter } from "../dev/memoryAdapter"
import { EditorProvider } from "../EditorProvider"
import { EditorEngine } from "../engine/editor"
import { rectObject } from "../animation/testing"
import { EMPTY_SELECTION } from "../store/editorStore"
import { t } from "../strings"
import "../builtins/toolbar"
import { ContextualToolbar } from "./ContextualToolbar"

let engine: EditorEngine | null = null

function mountSelectedShape() {
  const handle = createMemoryAdapter()
  engine = new EditorEngine({
    adapter: handle.adapter,
    document: createBlankDocument(800, 600),
    meta: { id: 'd', title: 'Test', mode: 'local' },
    ephemeral: true,
  })
  engine.store.setState({
    selection: {
      ...EMPTY_SELECTION,
      pageId: engine.state.doc.pages[0].id,
      ids: ['shape'],
      kinds: ['shape'],
      objects: [rectObject('shape', 100, 100, undefined, { shapeKind: 'rect', rx: 8, stroke: '#111111', strokeWidth: 2 })],
      bounds: { x: 50, y: 50, width: 100, height: 80, angle: 0 },
      version: 1,
    },
  })
  render(
    <EditorProvider engine={engine} portalRoot={document.body}>
      <ContextualToolbar />
    </EditorProvider>,
  )
  return engine
}

describe('ContextualToolbar scroll isolation', () => {
  afterEach(() => {
    cleanup()
    engine?.dispose()
    engine = null
  })

  it('keeps wheel and accordion interactions inside a selected shape popover', async () => {
    mountSelectedShape()
    const strip = screen.getByTestId('ed-context-scroll')
    strip.scrollLeft = 40

    await userEvent.click(screen.getByTestId('ed-shape-more'))
    const popover = screen.getByRole('dialog', { name: t.ctx.moreOptions })
    const popoverScroll = within(popover).getByTestId('ed-shape-more-scroll')

    const popoverWheel = new WheelEvent('wheel', { bubbles: true, cancelable: true, deltaY: 60 })
    popoverScroll.dispatchEvent(popoverWheel)
    expect(popoverWheel.defaultPrevented).toBe(false)
    expect(strip.scrollLeft).toBe(40)

    for (const section of ['more-effects', 'more-position', 'more-arrange', 'more-link']) {
      await userEvent.click(within(popover).getByTestId(section).querySelector('button') as HTMLButtonElement)
      expect(strip.scrollLeft).toBe(40)
    }

    const stripWheel = new WheelEvent('wheel', { bubbles: true, cancelable: true, deltaY: 30 })
    strip.dispatchEvent(stripWheel)
    expect(stripWheel.defaultPrevented).toBe(true)
    expect(strip.scrollLeft).toBe(70)
  })
})
