import { describe, expect, it } from 'vitest'
import { Point } from 'fabric'
import { DoryLine, installLineControls, moveLineEnd } from './DoryLine'

function svgOf(options: Record<string, unknown> = {}): Document {
  const line = new DoryLine({ width: 200, stroke: '#112233', strokeWidth: 4, ...options })
  return new DOMParser().parseFromString(`<svg xmlns="http://www.w3.org/2000/svg">${line.toSVG()}</svg>`, 'image/svg+xml')
}

describe('DoryLine as SVG', () => {
  it('is valid XML with the stroke on the line', () => {
    const svg = svgOf()
    expect(svg.querySelector('parsererror')).toBeNull()
    const line = svg.querySelector('line')
    expect(line?.getAttribute('x1')).toBe('-100')
    expect(line?.getAttribute('style')).toContain('stroke: rgb(17,34,51)')
    expect(svg.documentElement.outerHTML).not.toContain('COMMON_PARTS')
  })

  it('draws the arrow heads, solid or open, at their ends', () => {
    const paths = [...svgOf({ arrowStart: 'open', arrowEnd: 'triangle' }).querySelectorAll('path')]
    expect(paths.map((p) => p.getAttribute('transform'))).toEqual(['translate(-100 0) rotate(180)', 'translate(100 0) rotate(0)'])
    expect(paths.map((p) => p.getAttribute('fill'))).toEqual(['none', '#112233'])
  })

  it('has no heads when there are none, and a colour cannot break out of its attribute', () => {
    expect(svgOf().querySelectorAll('path')).toHaveLength(0)
    const svg = svgOf({ arrowEnd: 'triangle', stroke: '"/><script/>' })
    expect(svg.querySelector('parsererror')).toBeNull()
    expect(svg.querySelector('script')).toBeNull()
  })
})

describe('moveLineEnd', () => {
  it.each(['start', 'end'] as const)('snaps %s to a 45 degree angle with Shift and keeps the other end fixed', (which) => {
    const line = new DoryLine({ left: 200, top: 120, width: 100, originX: 'center', originY: 'center' })
    const fixedLocalX = which === 'start' ? line.width / 2 : -line.width / 2
    const fixed = new Point(fixedLocalX, 0).transform(line.calcTransformMatrix())
    const pointer = which === 'start' ? new Point(fixed.x - 40, fixed.y - 60) : new Point(fixed.x + 40, fixed.y + 60)

    moveLineEnd(line, which, pointer.x, pointer.y, true)

    const fixedAfter = new Point(which === 'start' ? line.width / 2 : -line.width / 2, 0).transform(line.calcTransformMatrix())
    expect(fixedAfter.x).toBeCloseTo(fixed.x)
    expect(fixedAfter.y).toBeCloseTo(fixed.y)
    expect(line.width).toBeCloseTo(Math.hypot(40, 60))
    expect(line.angle / 45).toBeCloseTo(Math.round(line.angle / 45))
  })

  it.each(['start', 'end'] as const)('keeps the pointer angle for %s without Shift and keeps the other end fixed', (which) => {
    const line = new DoryLine({ left: 200, top: 120, width: 100, originX: 'center', originY: 'center' })
    const fixedLocalX = which === 'start' ? line.width / 2 : -line.width / 2
    const fixed = new Point(fixedLocalX, 0).transform(line.calcTransformMatrix())
    const pointer = which === 'start' ? new Point(fixed.x - 40, fixed.y - 60) : new Point(fixed.x + 40, fixed.y + 60)

    moveLineEnd(line, which, pointer.x, pointer.y)

    const fixedAfter = new Point(which === 'start' ? line.width / 2 : -line.width / 2, 0).transform(line.calcTransformMatrix())
    expect(fixedAfter.x).toBeCloseTo(fixed.x)
    expect(fixedAfter.y).toBeCloseTo(fixed.y)
    expect(line.width).toBeCloseTo(Math.hypot(40, 60))
    expect(line.angle).toBeCloseTo((Math.atan2(60, 40) * 180) / Math.PI)
  })

  it.each([
    ['start', 'p1'],
    ['end', 'p2'],
  ] as const)('passes Shift through the %s control (%s)', (which, controlName) => {
    const line = new DoryLine({ left: 200, top: 120, width: 100, originX: 'center', originY: 'center' })
    installLineControls(line)
    const fixed = new Point(which === 'start' ? line.width / 2 : -line.width / 2, 0).transform(line.calcTransformMatrix())
    const pointer = which === 'start' ? new Point(fixed.x - 40, fixed.y - 60) : new Point(fixed.x + 40, fixed.y + 60)
    const actionHandler = line.controls[controlName].actionHandler
    if (!actionHandler) throw new Error(`Expected ${controlName} action handler`)

    actionHandler(new MouseEvent('mousemove', { shiftKey: true }), { target: line } as never, pointer.x, pointer.y)

    expect(line.angle / 45).toBeCloseTo(Math.round(line.angle / 45))
  })
})
