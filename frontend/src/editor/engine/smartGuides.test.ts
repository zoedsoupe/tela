import { computeMeasurements } from './smartGuides'
import type { Rect } from './geometry'

const rect = (left: number, top: number, width: number, height: number): Rect => ({
  left,
  top,
  width,
  height,
})

describe('computeMeasurements', () => {
  it('measures a gap beyond the snapping threshold', () => {
    const measurements = computeMeasurements(rect(150, 20, 50, 30), [rect(0, 20, 50, 30)], undefined, {
      includeSize: false,
    })

    expect(measurements).toContainEqual({
      axis: 'x',
      kind: 'gap',
      value: 100,
      equal: false,
      segments: [{ from: 50, to: 150, at: 35 }],
      reference: [],
    })
  })

  it('measures the nearest neighbors on both sides', () => {
    const measurements = computeMeasurements(
      rect(100, 20, 40, 30),
      [rect(50, 20, 30, 30), rect(160, 20, 20, 30)],
      undefined,
      { includeSize: false },
    )

    expect(measurements.filter((measurement) => measurement.axis === 'x')).toEqual([
      {
        axis: 'x',
        kind: 'gap',
        value: 20,
        equal: true,
        segments: [{ from: 80, to: 100, at: 35 }],
        reference: [],
      },
      {
        axis: 'x',
        kind: 'gap',
        value: 20,
        equal: true,
        segments: [{ from: 140, to: 160, at: 35 }],
        reference: [],
      },
    ])
  })

  it('measures to page edges when no neighbor is present on a side', () => {
    const measurements = computeMeasurements(
      rect(100, 100, 40, 30),
      [],
      rect(0, 0, 400, 300),
      { includeSize: false },
    )

    expect(measurements).toContainEqual({
      axis: 'x',
      kind: 'gap',
      value: 100,
      equal: false,
      segments: [{ from: 0, to: 100, at: 132.5 }],
      reference: [],
    })
    expect(measurements).toContainEqual({
      axis: 'x',
      kind: 'gap',
      value: 260,
      equal: false,
      segments: [{ from: 140, to: 400, at: 132.5 }],
      reference: [],
    })
  })

  it('marks equal gaps as equal on both sides', () => {
    const measurements = computeMeasurements(
      rect(100, 20, 40, 30),
      [rect(50, 20, 30, 30), rect(160, 20, 30, 30)],
      undefined,
      { includeSize: false },
    )

    expect(measurements.filter((measurement) => measurement.axis === 'x').map(({ equal }) => equal)).toEqual([
      true,
      true,
    ])
  })

  it('uses a matching external gap as a reference without crossing the moving rect', () => {
    const measurements = computeMeasurements(
      rect(100, 20, 30, 30),
      [
        rect(0, 20, 20, 30),
        rect(50, 20, 20, 30),
        rect(160, 20, 20, 30),
      ],
      undefined,
      { includeSize: false },
    )

    expect(measurements.find((measurement) => measurement.axis === 'x' && measurement.segments[0].from === 130)).toEqual({
      axis: 'x',
      kind: 'gap',
      value: 30,
      equal: true,
      segments: [{ from: 130, to: 160, at: 35 }],
      reference: [{ from: 20, to: 50, at: 35 }],
    })
  })

  it('uses the default half-pixel tolerance for equality', () => {
    const equal = computeMeasurements(
      rect(100, 20, 20, 30),
      [rect(70, 20, 10, 30), rect(140.4, 20, 10, 30)],
      undefined,
      { includeSize: false },
    )
    const different = computeMeasurements(
      rect(100, 20, 20, 30),
      [rect(70, 20, 10, 30), rect(140.6, 20, 10, 30)],
      undefined,
      { includeSize: false },
    )

    expect(equal.filter((measurement) => measurement.axis === 'x').map(({ equal: isEqual }) => isEqual)).toEqual([
      true,
      true,
    ])
    expect(
      different.filter((measurement) => measurement.axis === 'x').map(({ equal: isEqual }) => isEqual),
    ).toEqual([false, false])
  })

  it('produces a size measurement with the first matching copy as its reference', () => {
    const measurements = computeMeasurements(rect(100, 20, 40, 30), [
      rect(200, 100, 40, 50),
      rect(300, 200, 60, 30),
    ])

    expect(measurements).toContainEqual({
      axis: 'x',
      kind: 'size',
      value: 40,
      equal: true,
      segments: [{ from: 100, to: 140, at: 35 }],
      reference: [{ from: 200, to: 240, at: 125 }],
    })
    expect(measurements).toContainEqual({
      axis: 'y',
      kind: 'size',
      value: 30,
      equal: true,
      segments: [{ from: 20, to: 50, at: 120 }],
      reference: [{ from: 200, to: 230, at: 330 }],
    })
  })

  it('measures gaps and equal dimensions on both axes', () => {
    const measurements = computeMeasurements(rect(100, 100, 40, 30), [
      rect(50, 100, 40, 30),
      rect(100, 60, 40, 30),
    ])

    expect(measurements.some(({ axis, kind }) => axis === 'x' && kind === 'gap')).toBe(true)
    expect(measurements.some(({ axis, kind }) => axis === 'y' && kind === 'gap')).toBe(true)
    expect(measurements.some(({ axis, kind }) => axis === 'x' && kind === 'size')).toBe(true)
    expect(measurements.some(({ axis, kind }) => axis === 'y' && kind === 'size')).toBe(true)
  })

  it('does not measure non-aligned objects', () => {
    const measurements = computeMeasurements(
      rect(100, 100, 40, 30),
      [rect(50, 0, 30, 30)],
      undefined,
      { includeSize: false },
    )

    expect(measurements).toEqual([])
  })

  it('omits size measurements when includeSize is false', () => {
    const measurements = computeMeasurements(rect(100, 100, 40, 30), [rect(200, 200, 40, 30)], undefined, {
      includeSize: false,
    })

    expect(measurements.every(({ kind }) => kind === 'gap')).toBe(true)
  })
})
