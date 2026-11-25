import { Rect } from 'fabric'
import { createBlankDocument } from '@/lib/document'
import { createMemoryAdapter } from '../dev/memoryAdapter'
import { EditorEngine } from './editor'
import type { OverlayState } from './pageCanvas'

const engines: EditorEngine[] = []

async function setup() {
  const engine = new EditorEngine({
    adapter: createMemoryAdapter().adapter,
    document: createBlankDocument(800, 600),
    meta: { id: 'guides-test', title: 'Guides test', mode: 'local' },
    ephemeral: true,
  })
  engines.push(engine)
  const host = document.createElement('div')
  document.body.appendChild(host)
  const pageId = engine.state.doc.pages[0].id
  engine.mountPage(pageId, host)
  const view = await engine.whenView(pageId)
  view.setLayout(1, { x: 0, y: 0, width: 800, height: 600 })
  return { engine, view }
}

function overlayOf(view: Awaited<ReturnType<typeof setup>>['view']): OverlayState {
  return (view as unknown as { overlay: OverlayState }).overlay
}

describe('PageCanvas smart-guide measurements', () => {
  afterEach(() => {
    for (const engine of engines.splice(0)) engine.dispose()
    document.body.innerHTML = ''
  })

  it('measures gaps during Alt-drag without snapping or showing snap guides', async () => {
    const { view } = await setup()
    const target = new Rect({ left: 143, top: 100, width: 40, height: 30, strokeWidth: 0 })
    const other = new Rect({ left: 100, top: 100, width: 40, height: 30, strokeWidth: 0 })
    view.canvas.add(target, other)
    target.setCoords()
    const originalLeft = target.left

    view.canvas.fire('object:moving', {
      target,
      e: new MouseEvent('mousemove', { altKey: true }),
    } as never)

    expect(target.left).toBe(originalLeft)
    expect(overlayOf(view).guides).toEqual([])
    expect(overlayOf(view).spacing).toEqual([])
    expect(overlayOf(view).measurements).toContainEqual(
      expect.objectContaining({ axis: 'x', kind: 'gap', value: 3 }),
    )
  })

  it('clears measurements when guides are turned off', async () => {
    const { engine, view } = await setup()
    const target = new Rect({ left: 143, top: 100, width: 40, height: 30, strokeWidth: 0 })
    const other = new Rect({ left: 100, top: 100, width: 40, height: 30, strokeWidth: 0 })
    view.canvas.add(target, other)
    view.canvas.fire('object:moving', {
      target,
      e: new MouseEvent('mousemove', { altKey: true }),
    } as never)
    expect(overlayOf(view).measurements.length).toBeGreaterThan(0)

    engine.patchUi({ guides: false })
    view.invalidateOverlay()

    expect(overlayOf(view).measurements).toEqual([])
    expect(overlayOf(view).guides).toEqual([])
    expect(overlayOf(view).spacing).toEqual([])
  })

  it('clears measurements on mouse up', async () => {
    const { view } = await setup()
    const target = new Rect({ left: 143, top: 100, width: 40, height: 30, strokeWidth: 0 })
    const other = new Rect({ left: 100, top: 100, width: 40, height: 30, strokeWidth: 0 })
    view.canvas.add(target, other)
    view.canvas.fire('object:moving', {
      target,
      e: new MouseEvent('mousemove', { altKey: true }),
    } as never)
    expect(overlayOf(view).measurements.length).toBeGreaterThan(0)

    view.canvas.fire('mouse:up', {
      e: new MouseEvent('mouseup'),
      scenePoint: { x: 0, y: 0 },
      viewportPoint: { x: 0, y: 0 },
    } as never)

    expect(overlayOf(view).measurements).toEqual([])
  })

  it('computes measurements during object scaling with snapping suspended', async () => {
    const { view } = await setup()
    const target = new Rect({ left: 200, top: 100, width: 40, height: 30, strokeWidth: 0, scaleX: 2 })
    const other = new Rect({ left: 400, top: 300, width: 80, height: 30, strokeWidth: 0 })
    view.canvas.add(target, other)
    target.setCoords()

    view.canvas.fire('object:scaling', {
      target,
      transform: { corner: 'br' },
      e: new MouseEvent('mousemove', { altKey: true }),
    } as never)

    expect(overlayOf(view).measurements).toContainEqual(
      expect.objectContaining({ axis: 'x', kind: 'size', value: 80 }),
    )
  })

  it('tracks the document unit', async () => {
    const { engine } = await setup()

    expect(engine.unit).toBe('px')
    engine.pages.setUnit('mm')
    expect(engine.unit).toBe('mm')
  })
})
