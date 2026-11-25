import { type Rect, rectBottom, rectCenterX, rectCenterY, rectRight } from './geometry'

export interface MeasurementSegment {
  from: number
  to: number
  at: number
}

export interface Measurement {
  axis: 'x' | 'y'
  kind: 'gap' | 'size'
  value: number
  equal: boolean
  segments: MeasurementSegment[]
  reference: MeasurementSegment[]
}

export interface MeasurementOptions {
  tolerance?: number
  includeSize?: boolean
}

interface AxisGeometry {
  start(rect: Rect): number
  end(rect: Rect): number
  crossStart(rect: Rect): number
  crossEnd(rect: Rect): number
  crossCenter(rect: Rect): number
}

interface Gap {
  value: number
  segment: MeasurementSegment
}

function validRect(rect: Rect): boolean {
  return (
    Number.isFinite(rect.left) &&
    Number.isFinite(rect.top) &&
    Number.isFinite(rect.width) &&
    Number.isFinite(rect.height) &&
    rect.width > 0 &&
    rect.height > 0 &&
    Number.isFinite(rectRight(rect)) &&
    Number.isFinite(rectBottom(rect))
  )
}

function geometryFor(axis: 'x' | 'y'): AxisGeometry {
  if (axis === 'x') {
    return {
      start: (rect) => rect.left,
      end: rectRight,
      crossStart: (rect) => rect.top,
      crossEnd: rectBottom,
      crossCenter: rectCenterY,
    }
  }

  return {
    start: (rect) => rect.top,
    end: rectBottom,
    crossStart: (rect) => rect.left,
    crossEnd: rectRight,
    crossCenter: rectCenterX,
  }
}

function overlapsOnCrossAxis(a: Rect, b: Rect, geometry: AxisGeometry): boolean {
  return geometry.crossStart(a) < geometry.crossEnd(b) && geometry.crossEnd(a) > geometry.crossStart(b)
}

function segment(from: number, to: number, at: number): MeasurementSegment {
  return { from: Math.min(from, to), to: Math.max(from, to), at }
}

function makeGap(
  from: number,
  to: number,
  at: number,
): Gap | null {
  const value = to - from
  if (!Number.isFinite(value) || value < 0) return null
  return { value, segment: segment(from, to, at) }
}

function uniqueRects(rects: readonly Rect[], moving: Rect): Rect[] {
  const keyFor = (rect: Rect): string => `${rect.left},${rect.top},${rect.width},${rect.height}`
  const seen = new Set<string>([keyFor(moving)])
  const result: Rect[] = []

  for (const rect of rects) {
    if (!validRect(rect)) continue
    const key = keyFor(rect)
    if (seen.has(key)) continue
    seen.add(key)
    result.push(rect)
  }

  return result
}

function externalGaps(
  moving: Rect,
  aligned: readonly Rect[],
  geometry: AxisGeometry,
): Gap[] {
  const ordered = [...aligned].sort(
    (a, b) => geometry.start(a) - geometry.start(b) || geometry.end(a) - geometry.end(b),
  )
  const movingStart = geometry.start(moving)
  const movingEnd = geometry.end(moving)
  const gaps: Gap[] = []

  for (let index = 0; index < ordered.length - 1; index += 1) {
    const before = ordered[index]
    const after = ordered[index + 1]
    const from = geometry.end(before)
    const to = geometry.start(after)
    if (to <= from || (from < movingEnd && to > movingStart)) continue

    const gap = makeGap(from, to, (geometry.crossCenter(before) + geometry.crossCenter(after)) / 2)
    if (gap) gaps.push(gap)
  }

  return gaps
}

function gapMeasurements(
  moving: Rect,
  others: readonly Rect[],
  page: Rect | undefined,
  axis: 'x' | 'y',
  tolerance: number,
): Measurement[] {
  const geometry = geometryFor(axis)
  const aligned = others.filter((other) => overlapsOnCrossAxis(moving, other, geometry))
  const movingStart = geometry.start(moving)
  const movingEnd = geometry.end(moving)
  const before = aligned
    .filter((other) => geometry.end(other) <= movingStart)
    .sort((a, b) => geometry.end(b) - geometry.end(a))[0]
  const after = aligned
    .filter((other) => geometry.start(other) >= movingEnd)
    .sort((a, b) => geometry.start(a) - geometry.start(b))[0]

  const gaps: Gap[] = []
  const beforeBoundary = before ? geometry.end(before) : page ? geometry.start(page) : null
  if (beforeBoundary !== null) {
    const at = before ? geometry.crossCenter(before) : geometry.crossCenter(page!)
    const gap = makeGap(beforeBoundary, movingStart, (at + geometry.crossCenter(moving)) / 2)
    if (gap) gaps.push(gap)
  }

  const afterBoundary = after ? geometry.start(after) : page ? geometry.end(page) : null
  if (afterBoundary !== null) {
    const at = after ? geometry.crossCenter(after) : geometry.crossCenter(page!)
    const gap = makeGap(movingEnd, afterBoundary, (geometry.crossCenter(moving) + at) / 2)
    if (gap) gaps.push(gap)
  }

  const references = externalGaps(moving, aligned, geometry)
  return gaps.map((gap, index) => {
    const matchingReference = references.find((candidate) => Math.abs(candidate.value - gap.value) <= tolerance)
    const otherSide = gaps[index === 0 ? 1 : 0]
    const equalOnBothSides = gaps.length === 2 && otherSide !== undefined && Math.abs(otherSide.value - gap.value) <= tolerance

    return {
      axis,
      kind: 'gap',
      value: gap.value,
      equal: equalOnBothSides || matchingReference !== undefined,
      segments: [gap.segment],
      reference: matchingReference ? [matchingReference.segment] : [],
    }
  })
}

function sizeMeasurement(
  moving: Rect,
  others: readonly Rect[],
  axis: 'x' | 'y',
  tolerance: number,
): Measurement | null {
  const size = axis === 'x' ? moving.width : moving.height
  const matching = others.find((other) => {
    const otherSize = axis === 'x' ? other.width : other.height
    return Math.abs(otherSize - size) <= tolerance
  })
  if (!matching) return null

  const movingStart = axis === 'x' ? moving.left : moving.top
  const movingEnd = axis === 'x' ? rectRight(moving) : rectBottom(moving)
  const matchingStart = axis === 'x' ? matching.left : matching.top
  const matchingEnd = axis === 'x' ? rectRight(matching) : rectBottom(matching)

  return {
    axis,
    kind: 'size',
    value: size,
    equal: true,
    segments: [segment(movingStart, movingEnd, axis === 'x' ? rectCenterY(moving) : rectCenterX(moving))],
    reference: [
      segment(
        matchingStart,
        matchingEnd,
        axis === 'x' ? rectCenterY(matching) : rectCenterX(matching),
      ),
    ],
  }
}

/**
 * Measures the gaps around a moving rectangle and optionally its matching dimensions.
 * Coordinates and lengths are expressed in page pixels; no snapping threshold is applied.
 */
export function computeMeasurements(
  moving: Rect,
  others: readonly Rect[],
  page?: Rect,
  options: MeasurementOptions = {},
): Measurement[] {
  if (!validRect(moving)) return []

  const tolerance =
    options.tolerance !== undefined && Number.isFinite(options.tolerance) && options.tolerance >= 0
      ? options.tolerance
      : 0.5
  const validOthers = uniqueRects(others, moving)
  const validPage = page && validRect(page) ? page : undefined
  const measurements = [
    ...gapMeasurements(moving, validOthers, validPage, 'x', tolerance),
    ...gapMeasurements(moving, validOthers, validPage, 'y', tolerance),
  ]

  if (options.includeSize !== false) {
    const horizontalSize = sizeMeasurement(moving, validOthers, 'x', tolerance)
    const verticalSize = sizeMeasurement(moving, validOthers, 'y', tolerance)
    if (horizontalSize) measurements.push(horizontalSize)
    if (verticalSize) measurements.push(verticalSize)
  }

  return measurements
}
