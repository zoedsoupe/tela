import { Ellipse, Rect } from 'fabric'
import { createBlankDocument } from '@/lib/document'
import { createMemoryAdapter } from '../dev/memoryAdapter'
import { EditorEngine } from './editor'

async function setup() {
  const engine = new EditorEngine({
    adapter: createMemoryAdapter().adapter,
    document: createBlankDocument(800, 600),
    meta: { id: 'scaling-test', title: 'Scaling test', mode: 'local' },
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

describe('PageCanvas scaling', () => {
  afterEach(() => {
    document.body.innerHTML = ''
  })

  it('uses free scaling by default', async () => {
    const { engine, view } = await setup()

    expect(view.canvas.uniformScaling).toBe(false)

    engine.dispose()
  })

  it.each([
    ['Rect', (left: number, top: number) => new Rect({ left, top, width: 120, height: 60, strokeWidth: 0 })],
    ['Ellipse', (left: number, top: number) => new Ellipse({ left, top, rx: 60, ry: 30, strokeWidth: 0 })],
  ] as const)('%s becomes square with Shift on a corner handle', async (_name, createShape) => {
    const { engine, view } = await setup()
    const target = createShape(200, 180)
    target.set({ scaleX: 1.5, scaleY: 1.1 })
    target.setCoords()
    view.canvas.add(target)
    const fixedCorner = target.getCoords()[0]

    view.canvas.fire(
      'object:scaling',
      { target, transform: { corner: 'br' }, e: new MouseEvent('mousemove', { shiftKey: true, altKey: true }) } as never,
    )

    expect(target.width * Math.abs(target.scaleX)).toBeCloseTo(target.height * Math.abs(target.scaleY))
    expect(target.getCoords()[0].x).toBeCloseTo(fixedCorner.x)
    expect(target.getCoords()[0].y).toBeCloseTo(fixedCorner.y)
    engine.dispose()
  })

  it.each([
    ['Rect', (left: number, top: number) => new Rect({ left, top, width: 120, height: 60, strokeWidth: 0 })],
    ['Ellipse', (left: number, top: number) => new Ellipse({ left, top, rx: 60, ry: 30, strokeWidth: 0 })],
  ] as const)('%s keeps free dimensions without Shift on a corner handle', async (_name, createShape) => {
    const { engine, view } = await setup()
    const target = createShape(200, 180)
    target.set({ scaleX: 1.5, scaleY: 1.1 })
    target.setCoords()
    view.canvas.add(target)

    view.canvas.fire(
      'object:scaling',
      { target, transform: { corner: 'br' }, e: new MouseEvent('mousemove', { altKey: true }) } as never,
    )

    expect(target.width * Math.abs(target.scaleX)).not.toBeCloseTo(target.height * Math.abs(target.scaleY))
    engine.dispose()
  })
})
