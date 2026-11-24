import { Point, type FabricObject } from 'fabric'
import { createBlankDocument } from '@/lib/document'
import { createMemoryAdapter } from '../dev/memoryAdapter'
import { EditorEngine } from './editor'
import { DoryLine } from './objects/DoryLine'

async function setup() {
  const engine = new EditorEngine({
    adapter: createMemoryAdapter().adapter,
    document: createBlankDocument(800, 600),
    meta: { id: 'drag-test', title: 'Drag test', mode: 'local' },
    ephemeral: true,
  })
  const host = document.createElement('div')
  document.body.appendChild(host)
  const pageId = engine.state.doc.pages[0].id
  engine.mountPage(pageId, host)
  const view = await engine.whenView(pageId)
  view.setLayout(1, { x: 0, y: 0, width: 800, height: 600 })
  return { engine, view }
}

function transformFor(target: FabricObject, action = 'drag', corner = '') {
  return {
    target,
    action,
    corner,
    width: target.width,
    height: target.height,
    original: {
      left: target.left,
      top: target.top,
      scaleX: target.scaleX,
      scaleY: target.scaleY,
      skewX: target.skewX,
      skewY: target.skewY,
      angle: target.angle,
      flipX: target.flipX,
      flipY: target.flipY,
      originX: target.originX,
      originY: target.originY,
      cropX: 'cropX' in target ? target.cropX : undefined,
      cropY: 'cropY' in target ? target.cropY : undefined,
    },
  }
}

function beginTransform(
  view: Awaited<ReturnType<typeof setup>>['view'],
  transform: ReturnType<typeof transformFor>,
  x = 100,
  y = 100,
): void {
  const e = new MouseEvent('mousedown', { button: 0, clientX: x, clientY: y })
  view.canvas.fire('mouse:down:before', { e } as never)
  view.canvas.fire('before:transform', { e, transform } as never)
}

function moving(
  view: Awaited<ReturnType<typeof setup>>['view'],
  target: FabricObject,
  transform: ReturnType<typeof transformFor>,
  dx: number,
  dy = 0,
): void {
  target.set({ left: target.left + dx, top: target.top + dy })
  view.canvas.fire(
    'object:moving',
    {
      target,
      transform,
      e: new MouseEvent('mousemove', { clientX: 100 + dx, clientY: 100 + dy }),
    } as never,
  )
}

function endTransform(view: Awaited<ReturnType<typeof setup>>['view'], target: FabricObject, transform: ReturnType<typeof transformFor>): void {
  view.canvas.fire('object:modified', { target, transform, action: transform.action } as never)
  view.canvas.fire(
    'mouse:up',
    { e: new MouseEvent('mouseup'), scenePoint: { x: 0, y: 0 }, viewportPoint: { x: 0, y: 0 } } as never,
  )
}

describe('PageCanvas drag threshold', () => {
  afterEach(() => {
    document.body.innerHTML = ''
  })

  it('restores a 1 px body movement without changing the document, history, or live selection', async () => {
    const { engine, view } = await setup()
    await engine.insert.shape('rect')
    engine.history.seal()
    const target = view.canvas.getActiveObject()
    if (!target) throw new Error('Expected an active object')
    const before = structuredClone(engine.state.doc)
    const depth = engine.history.depth
    const selectionLive = vi.spyOn(engine, 'onSelectionLive')
    const transform = transformFor(target)
    const originalLeft = target.left
    const originalTop = target.top

    beginTransform(view, transform)
    moving(view, target, transform, 1)

    expect(target.left).toBe(originalLeft)
    expect(target.top).toBe(originalTop)
    endTransform(view, target, transform)
    expect(engine.state.doc).toEqual(before)
    expect(engine.history.depth).toBe(depth)
    expect(selectionLive).not.toHaveBeenCalled()
    engine.dispose()
  })

  it('commits a body movement after 6 CSS px', async () => {
    const { engine, view } = await setup()
    await engine.insert.shape('rect')
    engine.history.seal()
    const target = view.canvas.getActiveObject()
    if (!target) throw new Error('Expected an active object')
    const before = engine.state.doc.pages[0].objects[0].left
    const depth = engine.history.depth
    const transform = transformFor(target)

    beginTransform(view, transform)
    moving(view, target, transform, 6)
    endTransform(view, target, transform)

    expect(engine.state.doc.pages[0].objects[0].left).not.toBe(before)
    expect(engine.history.depth).toBe(depth + 1)
    engine.dispose()
  })

  it('does not snap a body click before the drag threshold', async () => {
    const { engine, view } = await setup()
    await engine.insert.shape('rect')
    engine.arrange.setPosition(2, 100)
    engine.history.seal()
    const target = view.canvas.getActiveObject()
    if (!target) throw new Error('Expected an active object')
    const before = structuredClone(engine.state.doc)
    const transform = transformFor(target)

    beginTransform(view, transform)
    moving(view, target, transform, 1)

    expect(target.getBoundingRect().left).toBeCloseTo(2)
    endTransform(view, target, transform)
    expect(engine.state.doc).toEqual(before)
    engine.dispose()
  })

  it('allows a DoryLine p1 handle edit smaller than the body threshold', async () => {
    const { engine, view } = await setup()
    await engine.insert.shape('line')
    engine.history.seal()
    const line = view.canvas.getActiveObject()
    if (!(line instanceof DoryLine)) throw new Error('Expected a DoryLine')
    const before = engine.state.doc.pages[0].objects[0]
    const depth = engine.history.depth
    const transform = transformFor(line, 'modifyLine', 'p1')
    const start = new Point(-line.width / 2, 0).transform(line.calcTransformMatrix())
    const p1 = line.controls.p1.actionHandler
    if (!p1) throw new Error('Expected the p1 control action handler')

    view.canvas.fire('before:transform', { e: new MouseEvent('mousedown'), transform } as never)
    p1(new MouseEvent('mousemove'), transform as never, start.x - 1, start.y)
    view.canvas.fire('object:modified', { target: line, transform, action: 'modifyLine' } as never)

    expect(engine.state.doc.pages[0].objects[0]).not.toEqual(before)
    expect(engine.history.depth).toBe(depth + 1)
    engine.dispose()
  })
})
