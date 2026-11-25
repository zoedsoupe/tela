import { Rect } from 'fabric'
import { createBlankDocument } from '@/lib/document'
import { createMemoryAdapter } from '../dev/memoryAdapter'
import { EditorEngine } from './editor'
import { DoryLine, installLineControls } from './objects/DoryLine'

async function setup() {
  const engine = new EditorEngine({
    adapter: createMemoryAdapter().adapter,
    document: createBlankDocument(800, 600),
    meta: { id: 'window-test', title: 'Window test', mode: 'local' },
    ephemeral: true,
  })
  const host = document.createElement('div')
  document.body.appendChild(host)
  const pageId = engine.state.doc.pages[0].id
  engine.mountPage(pageId, host)
  const view = await engine.whenView(pageId)
  view.setLayout(1, { x: 0, y: 0, width: 100, height: 100 })
  const relayout = vi.fn()
  engine.setViewportController({
    scrollToPage: () => undefined,
    viewportSize: () => ({ width: 100, height: 100 }),
    relayout,
    artboardRect: () => null,
  })
  return { engine, view, relayout }
}

describe('PageCanvas interaction window', () => {
  afterEach(() => {
    document.body.innerHTML = ''
  })

  it('requests relayout only after an object leaves the current window', async () => {
    const { engine, view, relayout } = await setup()
    view.setLayout(2, { x: 0, y: 0, width: 100, height: 100 })
    const target = new Rect({ left: 20, top: 20, width: 20, height: 20 })
    view.canvas.add(target)
    target.setCoords()

    view.canvas.fire('object:moving', {
      target,
      e: new MouseEvent('mousemove', { altKey: true }),
    } as never)
    expect(relayout).not.toHaveBeenCalled()

    target.set('left', 60)
    target.setCoords()
    view.canvas.fire('object:moving', {
      target,
      e: new MouseEvent('mousemove', { altKey: true }),
    } as never)
    expect(relayout).toHaveBeenCalledTimes(1)
    engine.dispose()
  })

  it('requests relayout when a DoryLine endpoint leaves the current window', async () => {
    const { engine, view, relayout } = await setup()
    const line = new DoryLine({ left: 50, top: 50, width: 20, originX: 'center', originY: 'center' })
    installLineControls(line)
    view.canvas.add(line)
    const p2 = line.controls.p2.actionHandler
    if (!p2) throw new Error('Expected the p2 control action handler')

    p2(new MouseEvent('mousemove'), { target: line } as never, 80, 50)
    expect(relayout).not.toHaveBeenCalled()

    p2(new MouseEvent('mousemove'), { target: line } as never, 130, 50)
    expect(relayout).toHaveBeenCalledTimes(1)
    engine.dispose()
  })
})
